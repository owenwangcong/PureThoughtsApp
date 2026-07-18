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
const INNERTUBE_CONTEXT = {
  client: { clientName: "WEB", clientVersion: "2.20250101.00.00" },
};

async function innertube(path: string, body: Record<string, unknown>) {
  const res = await fetch(`${INNERTUBE_BASE}/${path}?key=${INNERTUBE_KEY}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ context: INNERTUBE_CONTEXT, ...body }),
  });
  if (!res.ok) throw new Error(`innertube ${path} ${res.status}`);
  return await res.json();
}

/// /live 链接 → 当前直播/预告的 videoId。
/// 返回 {videoId}(可为 null = 频道明确没有进行中/预告的直播);接口异常返回 null(未知)。
async function resolveLiveVideoId(): Promise<{ videoId: string | null } | null> {
  try {
    const j = await innertube("navigation/resolve_url", {
      url: CHANNEL_LIVE_HANDLE_URL,
    });
    return { videoId: j?.endpoint?.watchEndpoint?.videoId ?? null };
  } catch (_) {
    return null;
  }
}

/// innertube 确认某视频是否正在直播:true/false;接口异常返回 null(状态未知)
async function innertubeIsLive(
  videoId: string,
): Promise<{ live: boolean; title: string | null } | null> {
  try {
    const j = await innertube("player", { videoId });
    const vd = j?.videoDetails ?? {};
    return {
      live: vd.isLive === true && vd.isUpcoming !== true,
      title: (vd.title as string | undefined) ?? null,
    };
  } catch (_) {
    return null;
  }
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
  if (resolved !== null) {
    if (resolved.videoId === null) {
      verdict = false; // 频道明确没有进行中/预告的直播
      diag = { via: "innertube", resolved: null };
    } else {
      const it = await innertubeIsLive(resolved.videoId);
      if (it !== null) {
        verdict = it.live; // 预告(isUpcoming)判 false,不误报
        videoId = resolved.videoId;
        title = it.title;
        diag = { via: "innertube", resolved: resolved.videoId, player_live: it.live };
      }
    }
  }

  // ---- 回退:innertube 未给出结论时抓页面,只信强证据(isLiveNow + canonical) ----
  // 教训(2026-07-18 真实直播实测):降级页里散落的 "videoId" 是推荐内容,弱证据必误判
  if (verdict === null) {
    try {
      const res = await fetch(CHANNEL_LIVE_URL, {
        redirect: "follow",
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
