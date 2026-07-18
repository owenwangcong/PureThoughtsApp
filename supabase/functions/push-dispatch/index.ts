// 推送投递(PRD §5.1 / §12.4,PLAN P2.1-3)
// 职责:把 notifications 表中待发的行投递到 APNs(全部 iOS,含大陆)与 FCM(海外 Android)。
// 触发:notifications insert 触发器 + pg_cron 每分钟兜底(经 pg_net,见 migration 0014);
//       也可手动 curl 调用。幂等:以 sent_at 抢占,重复调用不重发。
// 免打扰时段/分类订阅在阶段 C 补(先保证可达性)。
// 环境变量:APNS_KEY_P8 / APNS_KEY_ID / APPLE_TEAM_ID / APNS_TOPIC(缺省 bundle id)
//           FCM_SERVICE_ACCOUNT(服务账号 JSON 全文) / DISPATCH_SECRET(可选共享密钥)
import { createClient } from "jsr:@supabase/supabase-js@2";

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const APNS_TOPIC = Deno.env.get("APNS_TOPIC") ?? "com.aeonlectron.purethoughts";
const BATCH = 50;

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
async function sendApns(token: string, title: string, body: string): Promise<string> {
  const jwt = await getApnsJwt();
  if (!jwt) return "error";
  const payload = JSON.stringify({ aps: { alert: { title, body }, sound: "default" } });
  // TestFlight/App Store 走生产 APNs;本机调试构建的 token 属沙盒 → 生产报
  // BadDeviceToken 时再试沙盒,两边都无效才判失效
  for (const host of ["api.push.apple.com", "api.sandbox.push.apple.com"]) {
    const res = await fetch(`https://${host}/3/device/${token}`, {
      method: "POST",
      headers: {
        authorization: `bearer ${jwt}`,
        "apns-topic": APNS_TOPIC,
        "apns-push-type": "alert",
        "apns-priority": "10",
      },
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

async function sendFcm(token: string, title: string, body: string): Promise<string> {
  const auth = await getFcmAccessToken();
  if (!auth) return "error";
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${auth.project}/messages:send`,
    {
      method: "POST",
      headers: { authorization: `Bearer ${auth.token}`, "content-type": "application/json" },
      body: JSON.stringify({ message: { token, notification: { title, body } } }),
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

// deno-lint-ignore no-explicit-any
function renderText(n: any, hans: boolean): { title: string; body: string } {
  const p = n.payload ?? {};
  switch (n.type) {
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
      };
      const w = word[p.action as string] ?? ["变动", "異動"];
      return { title: hans ? "活动变动" : "活動異動", body: `${hans ? w[0] : w[1]} · ${p.title ?? ""}` };
    }
    case "live_started":
      return { title: hans ? "直播开始了" : "直播開始了", body: String(p.title ?? "YouTube") };
    case "proxy_log":
      return { title: hans ? "有同修为您代报" : "有同修為您代報", body: "" };
    default:
      return { title: n.title || n.type, body: n.body ?? "" };
  }
}

// ---------------------------------------------------------------- 主流程
Deno.serve(async (req) => {
  const headers = { "Content-Type": "application/json" };
  // 可选共享密钥(与 app_settings.push_dispatch_key 对应,防匿名滥调;未配置则跳过)
  const secret = Deno.env.get("DISPATCH_SECRET");
  if (secret && req.headers.get("x-dispatch-key") !== secret) {
    return new Response(JSON.stringify({ error: "forbidden" }), { status: 403, headers });
  }

  // 1. 抢占待发通知(近一天内、到点的;sent_at 置位后重复调用不重发)
  const { data: pending } = await admin
    .from("notifications")
    .select("id")
    .is("sent_at", null)
    .gt("created_at", new Date(Date.now() - 24 * 3600e3).toISOString())
    .or(`scheduled_at.is.null,scheduled_at.lte.${new Date().toISOString()}`)
    .limit(BATCH);
  if (!pending?.length) return new Response(JSON.stringify({ sent: 0 }), { headers });

  const { data: claimed } = await admin
    .from("notifications")
    .update({ sent_at: new Date().toISOString() })
    .in("id", pending.map((r) => r.id))
    .is("sent_at", null)
    .select("id, scope, target_id, type, title, body, payload");
  if (!claimed?.length) return new Response(JSON.stringify({ sent: 0 }), { headers });

  let ok = 0, invalid = 0, failed = 0;
  for (const n of claimed) {
    // 2. 解析受众 → tokens(带用户语言)
    let q = admin.from("push_tokens").select("token, platform, user_id, profiles(locale)");
    if (n.scope === "user") q = q.eq("user_id", n.target_id);
    else if (n.scope === "group") {
      const { data: members } = await admin
        .from("group_members").select("user_id")
        .eq("group_id", n.target_id).eq("status", "approved");
      const ids = (members ?? []).map((m) => m.user_id);
      if (!ids.length) continue;
      q = q.in("user_id", ids);
    }
    const { data: tokens } = await q;

    // 3. 逐 token 投递(按用户语言渲染;失效 token 即删)
    for (const t of tokens ?? []) {
      // deno-lint-ignore no-explicit-any
      const hans = ((t as any).profiles?.locale ?? "zh_Hant") === "zh_Hans";
      const { title, body } = renderText(n, hans);
      const result = t.platform === "apns"
        ? await sendApns(t.token, title, body)
        : await sendFcm(t.token, title, body);
      if (result === "ok") ok++;
      else if (result === "invalid") {
        invalid++;
        await admin.from("push_tokens").delete().eq("token", t.token);
      } else failed++;
    }
  }
  return new Response(
    JSON.stringify({ notifications: claimed.length, ok, invalid, failed }),
    { headers },
  );
});
