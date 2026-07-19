// YouTube 开播探测(PRD v0.5.6 §6)
// 开播 → upsert live_streams + 全员通知(每场一次,按 video_id 去重);下播 → 关闭记录。
// 触发:客户端打开直播页时调用;生产环境另由 pg_cron 每 5 分钟调用。
//
// 判定通道(2026-07-18 重构,真实直播实测定稿):
// 主通道 = innertube 双步(纯 JSON,对数据中心 IP 稳定):
//   ① navigation/resolve_url 把 /live 链接解析成 videoId;② player 确认 isLive。
// 回退 = 抓 /live 页面,但只信强证据(isLiveNow + canonical videoId)。
// 教训:EC2 数据中心 IP 拿到的降级页无 isLiveNow 也无 canonical,页面里散落的
// "videoId" 是推荐内容(实测抓到无关第三方视频),绝不能直接采信弱证据。
import { createClient } from "jsr:@supabase/supabase-js@2";

const CHANNEL_LIVE_HANDLE_URL = "https://www.youtube.com/@善護念/live";
const CHANNEL_LIVE_URL =
  "https://www.youtube.com/@%E5%96%84%E8%AD%B7%E5%BF%B5/live"; // 同上,页面抓取用

// YouTube 网页端公开的 innertube key(内嵌于所有 youtube.com 页面,非私密)
const INNERTUBE_BASE = "https://www.youtube.com/youtubei/v1";
const INNERTUBE_KEY = "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8";
const WEB_CLIENT = { clientName: "WEB", clientVersion: "2.20250101.00.00" };
// player 多客户端级联:EC2 上 WEB 客户端连 player 都被降级(响应无 videoDetails,
// 真实直播实测),移动端客户端通常不受数据中心 IP 限制(yt-dlp 同款做法)
const PLAYER_CLIENTS: Record<string, unknown>[] = [
  WEB_CLIENT,
  { clientName: "ANDROID", clientVersion: "20.10.38", androidSdkVersion: 30 },
  { clientName: "IOS", clientVersion: "20.10.4", deviceModel: "iPhone16,2" },
];

async function innertube(
  path: string,
  body: Record<string, unknown>,
  client: Record<string, unknown> = WEB_CLIENT,
) {
  const res = await fetch(`${INNERTUBE_BASE}/${path}?key=${INNERTUBE_KEY}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ context: { client }, ...body }),
    signal: AbortSignal.timeout(8000), // 防黑洞挂起(EC2 实测出现过 40s+ 无响应)
  });
  if (!res.ok) throw new Error(`innertube ${path} ${res.status}`);
  return await res.json();
}

/// YouTube Data API v3(官方公开接口,不受数据中心 bot 检测影响;需 YOUTUBE_API_KEY)。
/// liveBroadcastContent:"live"=在播 / "upcoming"·"none"=未播;未配 key 或接口异常返回 null。
/// 配额:videos.list(part=snippet)每次 1 单位,免费额度 1 万/天,5 分钟一探仅 288/天。
async function dataApiIsLive(
  videoId: string,
): Promise<{ live: boolean; title: string | null } | null> {
  const key = Deno.env.get("YOUTUBE_API_KEY");
  if (!key) return null;
  try {
    const res = await fetch(
      `https://www.googleapis.com/youtube/v3/videos?part=snippet&id=${videoId}&key=${key}`,
      { signal: AbortSignal.timeout(8000) },
    );
    if (!res.ok) return null;
    const j = await res.json();
    const item = j?.items?.[0];
    if (!item) return { live: false, title: null }; // 视频不存在/已删 = 非在播
    return {
      live: item.snippet?.liveBroadcastContent === "live",
      title: (item.snippet?.title as string | undefined) ?? null,
    };
  } catch (_) {
    return null;
  }
}

/// /live 链接 → 当前直播/预告的 videoId。
/// {videoId}(null = 频道明确没有进行中/预告的直播);{error} = 接口异常(状态未知)。
async function resolveLiveVideoId(): Promise<
  { videoId: string | null } | { error: string }
> {
  try {
    const j = await innertube("navigation/resolve_url", {
      url: CHANNEL_LIVE_HANDLE_URL,
    });
    return { videoId: j?.endpoint?.watchEndpoint?.videoId ?? null };
  } catch (e) {
    return { error: String((e as Error).message) };
  }
}

/// innertube 确认某视频是否正在直播(多客户端级联):true/false;
/// 全部客户端都拿不到有效数据时返回 null(状态未知)。
/// 有效性校验:响应必须回显同一 videoId(降级/错误响应会缺 videoDetails)。
async function innertubeIsLive(
  videoId: string,
): Promise<
  | { live: boolean; title: string | null; client: string }
  | { errors: string[] }
> {
  const errors: string[] = [];
  for (const client of PLAYER_CLIENTS) {
    try {
      const j = await innertube("player", { videoId }, client);
      const vd = j?.videoDetails ?? {};
      if (vd.videoId !== videoId) {
        // 降级/错误响应(缺 videoDetails),换下一个客户端
        errors.push(
          `${client.clientName}:no_data:${j?.playabilityStatus?.status ?? "?"}`,
        );
        continue;
      }
      return {
        live: vd.isLive === true && vd.isUpcoming !== true,
        title: (vd.title as string | undefined) ?? null,
        client: String(client.clientName),
      };
    } catch (e) {
      errors.push(`${client.clientName}:${(e as Error).message}`);
    }
  }
  return { errors };
}

Deno.serve(async (req) => {
  const cors = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, content-type, apikey",
    "Content-Type": "application/json",
  };
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  let isLive = false;
  let videoId: string | null = null;
  let title: string | null = null;
  let diag: Record<string, unknown> = {};
  // verdict:true=在播 / false=确定未播 / null=无法确定(不动数据库记录,防误关)
  let verdict: boolean | null = null;

  // ---- 主通道:innertube 双步(resolve /live → player 确认) ----
  const resolved = await resolveLiveVideoId();
  if ("error" in resolved) {
    diag = { resolve_error: resolved.error };
  } else if (resolved.videoId === null) {
    verdict = false; // 频道明确没有进行中/预告的直播
    diag = { via: "innertube", resolved: null };
  } else {
    // 判定优先级:Data API(官方,EC2 免疫 bot 检测)→ innertube player 级联
    const da = await dataApiIsLive(resolved.videoId);
    if (da !== null) {
      verdict = da.live; // "upcoming"/"none" 判 false,预告不误报
      videoId = resolved.videoId;
      title = da.title;
      diag = { via: "data_api", resolved: resolved.videoId, live: da.live };
    } else {
      const it = await innertubeIsLive(resolved.videoId);
      if ("client" in it) {
        verdict = it.live; // 预告(isUpcoming)判 false,不误报
        videoId = resolved.videoId;
        title = it.title;
        diag = {
          via: "innertube",
          resolved: resolved.videoId,
          player_live: it.live,
          player_client: it.client,
        };
      } else {
        diag = { resolved: resolved.videoId, player_errors: it.errors };
      }
    }
  }

  // ---- 回退:innertube 未给出结论时抓页面,只信强证据(isLiveNow + canonical) ----
  // 教训(2026-07-18 真实直播实测):降级页里散落的 "videoId" 是推荐内容,弱证据必误判
  if (verdict === null) {
    try {
      const res = await fetch(CHANNEL_LIVE_URL, {
        redirect: "follow",
        signal: AbortSignal.timeout(10000),
        headers: {
          "User-Agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36",
          "Accept-Language": "zh-TW,zh;q=0.9,en;q=0.8",
          Cookie: "CONSENT=YES+cb; SOCS=CAI",
        },
      });
      const html = await res.text();
      const canonicalId =
        html.match(/<link rel="canonical" href="https:\/\/www\.youtube\.com\/watch\?v=([\w-]{11})"/)?.[1] ??
        res.url.match(/[?&]v=([\w-]{11})/)?.[1] ?? null;
      const hasLiveNow = html.includes('"isLiveNow":true');
      if (hasLiveNow && canonicalId !== null) {
        verdict = true;
        videoId = canonicalId;
        title = html.match(/<title>(.*?)<\/title>/)?.[1]
          ?.replace(" - YouTube", "").trim() ?? null;
      }
      diag = {
        ...diag,
        page: {
          status: res.status,
          final_url: res.url,
          html_len: html.length,
          hasLiveNow,
          canonical: canonicalId,
        },
      };
    } catch (_) {
      // 页面也失败:保持 verdict null
    }
  }

  // 两条通道都无结论:状态未知,不改动现有记录(防止 innertube 抖动时误关在播记录)
  if (verdict === null) {
    return new Response(
      JSON.stringify({ live: null, error: "inconclusive", diag }),
      { headers: cors },
    );
  }
  isLive = verdict;

  const { data: open } = await admin
    .from("live_streams")
    .select("id, video_id")
    .eq("platform", "youtube")
    .is("ended_at", null)
    .maybeSingle();

  if (isLive && videoId) {
    if (!open || open.video_id !== videoId) {
      if (open) {
        await admin.from("live_streams").update({ ended_at: new Date().toISOString() })
          .eq("id", open.id);
      }
      const url = `https://www.youtube.com/watch?v=${videoId}`;
      await admin.from("live_streams").insert({
        platform: "youtube",
        video_id: videoId,
        url,
        title,
      });
      // 全员通知(每场一次;P2.1 推送接通后由 push-dispatch 升级为系统推送)
      await admin.from("notifications").insert({
        scope: "all",
        type: "live_started",
        payload: { platform: "youtube", video_id: videoId, title, url },
        channels: ["inapp"],
      });
    }
    return new Response(
      JSON.stringify({ live: true, video_id: videoId, title, diag }),
      { headers: cors },
    );
  }

  if (open) {
    await admin.from("live_streams").update({ ended_at: new Date().toISOString() })
      .eq("id", open.id);
  }
  return new Response(JSON.stringify({ live: false, diag }), { headers: cors });
});
