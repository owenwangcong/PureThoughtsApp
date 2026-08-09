// 推送投递(PRD v0.5.21 §5.1/§5.4/§12.4,设计 docs/design/notification-overhaul.md,PLAN P2.12–P2.16)
// 职责:把 notifications 表中待发的行投递到 APNs(全部 iOS,含大陆)与 FCM(海外 Android)。
// 触发:notifications insert 语句级触发器(仅当本批含已到点行)+ pg_cron 每分钟兜底,
//       经 pg_net 外呼(migration 0023);也可手动 curl(须带 x-dispatch-key)。
//
// v0.5.21 改造(逐条对应 PLAN §7 登记的缺陷):
//   · 抢占改租约式 RPC claim_notifications:原实现在发送**之前**就写 sent_at,失败不回滚
//     不重试不留痕 → 一次网络抖动即静默丢失(缺陷 B)。现在结果经 complete_notification
//     回写,全失败则释放租约由每分钟 cron 自动重投,5 次用尽记 failed_at。
//   · 受众解析下沉为 push_audience RPC:一次取齐 token/平台/语言/免打扰顺延时刻,
//     内含 channels、分类订阅、封禁、scope 四道过滤(缺陷 D)。
//   · 免打扰顺延:命中时段的用户不即时推,克隆一条 scope=user + channels={push} 的
//     通知排到其本地时段结束(缺陷 C)。克隆只推不进通知中心,原通知已在列表里。
//   · 报文携带 data.route 深链(缺陷 G)+ apns-collapse-id / collapse_key 折叠 + 过期时间。
//   · 鉴权:DISPATCH_SECRET 必须配置(原实现未配置时静默放行);仅接受 POST。
//   · 逐 token 串行改并发 20,全流程 try/catch(原实现 fetch 未包异常,handler 500 时
//     该批已被标记已发送)。
//
// 环境变量:APNS_KEY_P8 / APNS_KEY_ID / APPLE_TEAM_ID / APNS_TOPIC(缺省 bundle id)
//           FCM_SERVICE_ACCOUNT(服务账号 JSON 全文) / DISPATCH_SECRET(必填共享密钥)
import { createClient } from "jsr:@supabase/supabase-js@2";

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const APNS_TOPIC = Deno.env.get("APNS_TOPIC") ?? "com.aeonlectron.purethoughts";
const BATCH = 50;
const CONCURRENCY = 20;

/// 一条待投递的推送:文案 + 深链 + 折叠/过期控制
type PushMsg = {
  title: string;
  body: string;
  route: string;
  collapseId: string | null;
  expiration: number | null; // unix 秒;APNs 过期后不再尝试送达
};

/// 有并发上限的 map(逐 token 串行在 scope=all 时会超时)
async function mapLimit<T, R>(
  items: T[],
  limit: number,
  fn: (item: T) => Promise<R>,
): Promise<R[]> {
  const out = new Array<R>(items.length);
  let cursor = 0;
  const workers = Array.from(
    { length: Math.min(limit, items.length) },
    async () => {
      while (true) {
        const i = cursor++;
        if (i >= items.length) return;
        out[i] = await fn(items[i]);
      }
    },
  );
  await Promise.all(workers);
  return out;
}

// ---------------------------------------------------------------- 工具:PEM → CryptoKey
function pemToDer(pem: string): Uint8Array {
  const b64 = pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
}

/// 读取可能以 base64 存放的多行密钥(PEM / JSON)。
/// .env 与 docker compose 对引号/转义的解释各不相同,多行值极易被解析器破坏;
/// 统一建议存单行 base64,原样值(以 { 或 ----- 开头)也兼容。
function envSecret(name: string): string | null {
  const v = Deno.env.get(name)?.trim();
  if (!v) return null;
  if (v.startsWith("{") || v.startsWith("-----")) return v;
  try {
    return atob(v);
  } catch {
    return v;
  }
}

const b64url = (data: Uint8Array | string) => {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : data;
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
};

async function signJwt(
  header: Record<string, unknown>,
  claims: Record<string, unknown>,
  key: CryptoKey,
  alg: "ES256" | "RS256",
): Promise<string> {
  const input = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(claims))}`;
  const params = alg === "ES256"
    ? { name: "ECDSA", hash: "SHA-256" }
    : { name: "RSASSA-PKCS1-v1_5" };
  const sig = new Uint8Array(
    await crypto.subtle.sign(params, key, new TextEncoder().encode(input)),
  );
  return `${input}.${b64url(sig)}`;
}

// ---------------------------------------------------------------- APNs
let apnsJwt: { token: string; iat: number } | null = null;

async function getApnsJwt(): Promise<string | null> {
  const p8 = envSecret("APNS_KEY_P8");
  const kid = Deno.env.get("APNS_KEY_ID");
  const team = Deno.env.get("APPLE_TEAM_ID");
  if (!p8 || !kid || !team) return null;
  const now = Math.floor(Date.now() / 1000);
  if (apnsJwt && now - apnsJwt.iat < 45 * 60) return apnsJwt.token; // APNs 要求 20–60 分钟内复用
  const key = await crypto.subtle.importKey(
    "pkcs8", pemToDer(p8), { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"],
  );
  const token = await signJwt({ alg: "ES256", kid }, { iss: team, iat: now }, key, "ES256");
  apnsJwt = { token, iat: now };
  return token;
}

/// 返回 'ok' | 'invalid'(应删 token)| 'error'
async function sendApns(token: string, msg: PushMsg): Promise<string> {
  const jwt = await getApnsJwt();
  if (!jwt) return "error";
  // route 与 aps 同级,客户端点击通知时据此深链(iOS 走 AppDelegate.didReceive)
  const payload = JSON.stringify({
    aps: {
      alert: { title: msg.title, body: msg.body },
      sound: "default",
      ...(msg.collapseId ? { "thread-id": msg.collapseId } : {}),
    },
    route: msg.route,
  });
  const headers: Record<string, string> = {
    authorization: `bearer ${jwt}`,
    "apns-topic": APNS_TOPIC,
    "apns-push-type": "alert",
    "apns-priority": "10",
  };
  // 同一活动的连续变更在通知栏折叠成一条(也兜住整条重试可能的重复推送)
  if (msg.collapseId) headers["apns-collapse-id"] = msg.collapseId;
  if (msg.expiration) headers["apns-expiration"] = String(msg.expiration);

  // TestFlight/App Store 走生产 APNs;本机调试构建的 token 属沙盒 → 生产报
  // BadDeviceToken 时再试沙盒,两边都无效才判失效
  for (const host of ["api.push.apple.com", "api.sandbox.push.apple.com"]) {
    const res = await fetch(`https://${host}/3/device/${token}`, {
      method: "POST",
      headers,
      body: payload,
    });
    if (res.ok) return "ok";
    const reason = (await res.json().catch(() => ({})))?.reason;
    if (res.status === 410 || reason === "Unregistered") return "invalid";
    if (reason !== "BadDeviceToken") return "error"; // 其他错误不再试沙盒
  }
  return "invalid"; // 两个环境都 BadDeviceToken
}

// ---------------------------------------------------------------- FCM(HTTP v1)
let fcmAuth: { token: string; exp: number } | null = null;

async function getFcmAccessToken(): Promise<{ token: string; project: string } | null> {
  const raw = envSecret("FCM_SERVICE_ACCOUNT");
  if (!raw) return null;
  const sa = JSON.parse(raw);
  const now = Math.floor(Date.now() / 1000);
  if (fcmAuth && now < fcmAuth.exp - 120) return { token: fcmAuth.token, project: sa.project_id };
  const key = await crypto.subtle.importKey(
    "pkcs8", pemToDer(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"],
  );
  const assertion = await signJwt({ alg: "RS256", typ: "JWT" }, {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: sa.token_uri,
    iat: now,
    exp: now + 3600,
  }, key, "RS256");
  const res = await fetch(sa.token_uri, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: `grant_type=${encodeURIComponent("urn:ietf:params:oauth:grant-type:jwt-bearer")}&assertion=${assertion}`,
  });
  if (!res.ok) return null;
  const j = await res.json();
  fcmAuth = { token: j.access_token, exp: now + (j.expires_in ?? 3600) };
  return { token: fcmAuth.token, project: sa.project_id };
}

async function sendFcm(token: string, msg: PushMsg): Promise<string> {
  const auth = await getFcmAccessToken();
  if (!auth) return "error";
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${auth.project}/messages:send`,
    {
      method: "POST",
      headers: { authorization: `Bearer ${auth.token}`, "content-type": "application/json" },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: msg.title, body: msg.body },
          data: { route: msg.route }, // 客户端 onMessageOpenedApp / getInitialMessage 读取
          android: {
            priority: "high",
            ...(msg.collapseId ? { collapse_key: msg.collapseId } : {}),
          },
        },
      }),
    },
  );
  if (res.ok) return "ok";
  const err = await res.json().catch(() => ({}));
  const status = err?.error?.details?.find((d: { errorCode?: string }) => d.errorCode)?.errorCode ??
    err?.error?.status;
  if (res.status === 404 || status === "UNREGISTERED" || status === "INVALID_ARGUMENT") {
    return "invalid";
  }
  return "error";
}

// ---------------------------------------------------------------- 文案渲染(与客户端口径一致,简/繁按用户 locale)
const LUNAR_DAYS = [
  "初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
  "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
  "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十",
];
const LUNAR_MONTHS = ["正月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "冬月", "臘月"];

function lunarText(m: number, d: number, leap: boolean, hans: boolean): string {
  let month = LUNAR_MONTHS[m - 1] ?? "";
  if (hans && m === 12) month = "腊月";
  if (leap) month = (hans ? "闰" : "閏") + month;
  return (hans ? "农历" : "農曆") + month + (LUNAR_DAYS[d - 1] ?? "");
}

/// 在**活动时区**渲染日期时间:提前一天的预告必须说清是哪天几点,
/// 且要用活动当地时间(与客户端详情页「活動當地時間」口径一致)。
function localTime(iso: string, tz: string, hans: boolean): string {
  try {
    return new Intl.DateTimeFormat(hans ? "zh-CN" : "zh-TW", {
      timeZone: tz || "Asia/Shanghai",
      month: "numeric",
      day: "numeric",
      weekday: "short",
      hour: "2-digit",
      minute: "2-digit",
      hour12: false,
    }).format(new Date(iso));
  } catch {
    return "";
  }
}

// deno-lint-ignore no-explicit-any
function renderText(n: any, hans: boolean): { title: string; body: string } {
  const p = n.payload ?? {};
  switch (n.type) {
    // 活动提醒(PRD v0.5.21 §5,默认三档 1440/30/0)
    case "event_reminder": {
      const ofs = Number(p.offset_minutes ?? 0);
      const name = String(p.title ?? "");
      if (ofs >= 1440) {
        const when = localTime(String(p.start_at ?? ""), String(p.timezone ?? ""), hans);
        return {
          title: hans ? "活动预告" : "活動預告",
          body: when ? `${name} · ${when}` : name,
        };
      }
      if (ofs >= 60) {
        const h = Math.round(ofs / 60);
        return {
          title: hans ? "活动即将开始" : "活動即將開始",
          body: hans ? `${name} · ${h} 小时后开始` : `${name} · ${h} 小時後開始`,
        };
      }
      if (ofs >= 1) {
        return {
          title: hans ? "活动即将开始" : "活動即將開始",
          body: hans ? `${name} · ${ofs} 分钟后开始` : `${name} · ${ofs} 分鐘後開始`,
        };
      }
      const hasLink = p.has_webex === true || p.has_youtube === true;
      return {
        title: hans ? "活动开始了" : "活動開始了",
        body: hasLink ? (hans ? `${name} · 点击进入` : `${name} · 點擊進入`) : name,
      };
    }
    case "almanac": {
      const names: string[] = (hans ? p.names_hans : p.names_hant) ?? [];
      const lunar = lunarText(p.lunar_month ?? 1, p.lunar_day ?? 1, p.is_leap_month === true, hans);
      if (p.kind === "zhai") return { title: hans ? "今日十斋日" : "今日十齋日", body: lunar };
      if (p.kind === "festival_eve") {
        return { title: hans ? "明日佛教节日" : "明日佛教節日", body: `${names.join("、")} · ${lunar}` };
      }
      return { title: hans ? "今日佛教节日" : "今日佛教節日", body: `${names.join("、")} · ${lunar}` };
    }
    case "announcement":
      return { title: hans ? "群公告更新" : "群公告更新", body: String(p.text ?? "") };
    case "event_changed": {
      const word: Record<string, [string, string]> = {
        created: ["新增", "新增"], updated: ["更新", "更新"], deleted: ["已取消", "已取消"],
        occurrence_cancelled: ["单次取消", "單次取消"], occurrence_changed: ["单次改期", "單次改期"],
        occurrence_restored: ["单次恢复", "單次恢復"],
      };
      const w = word[p.action as string] ?? ["变动", "異動"];
      return { title: hans ? "活动变动" : "活動異動", body: `${hans ? w[0] : w[1]} · ${p.title ?? ""}` };
    }
    case "live_started":
      return { title: hans ? "直播开始了" : "直播開始了", body: String(p.title ?? "YouTube") };
    case "proxy_log":
      return { title: hans ? "有同修为您代报" : "有同修為您代報", body: "" };
    // 学修问答(PRD §16):隐私定案,推送不带问题正文
    case "qa_reply":
      return { title: hans ? "您的提问有新回复" : "您的提問有新回覆", body: "" };
    case "qa_question":
      return { title: hans ? "有新的学修提问" : "有新的學修提問", body: "" };
    default:
      return { title: n.title || n.type, body: n.body ?? "" };
  }
}

// ---------------------------------------------------------------- 深链 / 折叠 / 过期
/// 点击通知的落地路由。⚠️ 必须与客户端 notifications_screen.dart 的 routeOfNotification
/// 保持一致(跨语言无法共享常量,两端改动必须成对;对照表见设计文档 §8.2)。
// deno-lint-ignore no-explicit-any
function routeOf(n: any, p: any): string {
  const eid = p.event_id ?? n.event_id;
  switch (n.type) {
    case "event_reminder":
    case "event_changed": {
      // 活动已删(action=deleted)时不带 event_id → 深链过去只会看到空态,退化到日历
      if (!eid) return "/calendar";
      const d = p.occurrence_date ?? p.date;
      return d ? `/calendar/event/${eid}?date=${d}` : `/calendar/event/${eid}`;
    }
    case "almanac":
      return "/calendar";
    case "live_started":
      return "/live";
    case "qa_reply":
      return p.thread_id ? `/study-qa/${p.thread_id}` : "/study-qa";
    case "qa_question":
      return p.thread_id ? `/study-qa/${p.thread_id}?as=admin` : "/study-qa";
    case "announcement":
      return n.target_id ? `/groups/${n.target_id}` : "/groups";
    case "proxy_log":
      return "/dashboard";
    default:
      return "/notifications";
  }
}

// deno-lint-ignore no-explicit-any
function collapseOf(n: any, p: any): string | null {
  const eid = p.event_id ?? n.event_id;
  if (!eid) return null;
  // 同一活动的连续变更折叠成一条
  if (n.type === "event_changed") return `evt:${eid}`;
  // 提醒按档位分别折叠:预告与开场是两条独立信息,不该互相覆盖;
  // 但同一档位的重投(整条重试)要折叠掉。
  if (n.type === "event_reminder") return `evtr:${eid}:${p.offset_minutes ?? 0}`;
  return null;
}

// deno-lint-ignore no-explicit-any
function expirationOf(n: any, p: any): number {
  // 活动提醒过了开场就没意义了(设备关机数小时后再收到「即将开始」只会造成困惑),
  // 给到开场后 1 小时;其余通知 24 小时。
  if (n.type === "event_reminder" && p.start_at) {
    const t = Date.parse(String(p.start_at));
    if (!Number.isNaN(t)) return Math.floor(t / 1000) + 3600;
  }
  return Math.floor(Date.now() / 1000) + 24 * 3600;
}

// deno-lint-ignore no-explicit-any
function renderPush(n: any, hans: boolean): PushMsg {
  const p = n.payload ?? {};
  const { title, body } = renderText(n, hans);
  return {
    title,
    body,
    route: routeOf(n, p),
    collapseId: collapseOf(n, p),
    expiration: expirationOf(n, p),
  };
}

// ---------------------------------------------------------------- 主流程
type Audience = {
  token: string;
  platform: string;
  locale: string | null;
  quiet_until: string | null;
  user_id: string;
};

/// 免打扰顺延:为命中时段的用户克隆一条「只推不进通知中心」的通知,排到其本地时段结束。
/// 原通知已经在通知中心里,克隆用 channels={push} 避免列表出现重复条目(设计 §5.4)。
/// 先删旧克隆再插:整条重试时不会堆出多份。
// deno-lint-ignore no-explicit-any
async function cloneDeferred(n: any, deferred: Audience[]): Promise<void> {
  const byUser = new Map<string, string>();
  for (const d of deferred) {
    if (d.quiet_until && !byUser.has(d.user_id)) byUser.set(d.user_id, d.quiet_until);
  }
  if (!byUser.size) return;

  await admin.from("notifications").delete()
    .eq("scope", "user")
    .is("sent_at", null)
    .filter("payload->>deferred_from", "eq", n.id);

  await admin.from("notifications").insert(
    [...byUser].map(([uid, until]) => ({
      scope: "user",
      target_id: uid,
      type: n.type,
      title: n.title,
      body: n.body,
      event_id: n.event_id ?? null,
      payload: { ...(n.payload ?? {}), deferred_from: n.id },
      channels: ["push"],
      scheduled_at: until,
    })),
  );
}

Deno.serve(async (req) => {
  const headers = { "Content-Type": "application/json" };

  // 鉴权:原实现「未配置密钥则跳过校验」等于对公网敞开,改为必须配置
  const secret = Deno.env.get("DISPATCH_SECRET");
  if (!secret) {
    console.error("DISPATCH_SECRET 未配置,拒绝服务(部署见 infra/deploy-aws-ec2.md §11)");
    return new Response(JSON.stringify({ error: "not_configured" }), { status: 500, headers });
  }
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "method_not_allowed" }), { status: 405, headers });
  }
  if (req.headers.get("x-dispatch-key") !== secret) {
    return new Response(JSON.stringify({ error: "forbidden" }), { status: 403, headers });
  }

  // 1. 租约式抢占(FOR UPDATE SKIP LOCKED + attempts++,见 migration 0023)
  const { data: claimed, error: claimErr } = await admin
    .rpc("claim_notifications", { p_limit: BATCH });
  if (claimErr) {
    console.error("claim_notifications 失败", claimErr.message);
    return new Response(JSON.stringify({ error: "claim_failed" }), { status: 500, headers });
  }
  if (!claimed?.length) return new Response(JSON.stringify({ sent: 0 }), { headers });

  let ok = 0, invalid = 0, failed = 0, deferredTotal = 0;

  for (const n of claimed) {
    let nOk = 0, nInvalid = 0, nFailed = 0;
    let nErr: string | null = null;

    try {
      // 2. 受众解析:channels / 分类订阅 / 封禁 / scope 四道过滤 + 免打扰顺延时刻
      const { data: audience, error: audErr } = await admin
        .rpc("push_audience", { p_notification_id: n.id });
      if (audErr) throw new Error(`push_audience: ${audErr.message}`);

      const list = (audience ?? []) as Audience[];
      const deferred = list.filter((a) => a.quiet_until);
      const sendNow = list.filter((a) => !a.quiet_until);

      // 3. 免打扰顺延(克隆失败不应让原通知整条重试 → 单独捕获)
      if (deferred.length) {
        try {
          await cloneDeferred(n, deferred);
          deferredTotal += deferred.length;
        } catch (e) {
          console.error("免打扰克隆失败", n.id, String(e));
          nErr = `defer: ${String(e)}`;
        }
      }

      // 4. 并发投递(按用户 locale 简繁渲染;失效 token 即删)
      const results = await mapLimit(sendNow, CONCURRENCY, async (t) => {
        const msg = renderPush(n, (t.locale ?? "zh_Hant") === "zh_Hans");
        try {
          const r = t.platform === "apns"
            ? await sendApns(t.token, msg)
            : await sendFcm(t.token, msg);
          if (r === "invalid") {
            await admin.from("push_tokens").delete().eq("token", t.token);
          }
          return r;
        } catch (e) {
          // 原实现 fetch 未包异常:一次网络错误会让整个 handler 500,
          // 而此时该批通知已被标记「已发送」→ 永久丢失
          console.error("投递异常", t.platform, String(e));
          return "error";
        }
      });

      for (const r of results) {
        if (r === "ok") nOk++;
        else if (r === "invalid") nInvalid++;
        else nFailed++;
      }
    } catch (e) {
      nErr = String(e);
      nFailed++;
      console.error("通知处理失败", n.id, nErr);
    }

    // 5. 结果回写:成功置 sent_at;全失败释放租约等 cron 重投,5 次用尽记 failed_at
    const { error: doneErr } = await admin.rpc("complete_notification", {
      p_id: n.id, p_ok: nOk, p_invalid: nInvalid, p_failed: nFailed, p_error: nErr,
    });
    if (doneErr) console.error("complete_notification 失败", n.id, doneErr.message);

    ok += nOk;
    invalid += nInvalid;
    failed += nFailed;
  }

  return new Response(
    JSON.stringify({
      notifications: claimed.length,
      ok,
      invalid,
      failed,
      deferred: deferredTotal,
    }),
    { headers },
  );
});
