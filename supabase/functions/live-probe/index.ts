// YouTube 开播探测(PRD v0.5.6 §6)
// 探测频道 /live 端点(无需 API key):开播 → upsert live_streams + 全员通知
// (仅每场直播通知一次,按 video_id 去重);下播 → 关闭记录。
// 触发:客户端打开直播页时调用;生产环境另由 pg_cron 每 5 分钟调用。
// 2026-07-18 增补:数据中心 IP(EC2)常拿到无 isLiveNow 标记的降级页 → 实播被判未开播
// (真实直播实测)。补第二判定通道:拿到 videoId 后调 YouTube innertube player API
// (纯 JSON,对数据中心 IP 稳定)以 videoDetails.isLive 确认。
import { createClient } from "jsr:@supabase/supabase-js@2";

const CHANNEL_LIVE_URL =
  "https://www.youtube.com/@%E5%96%84%E8%AD%B7%E5%BF%B5/live"; // @善護念

// YouTube 网页端公开的 innertube key(内嵌于所有 youtube.com 页面,非私密)
const INNERTUBE_URL =
  "https://www.youtube.com/youtubei/v1/player?key=AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8";

/// innertube 确认某视频是否正在直播:true/false;接口异常返回 null(状态未知)
async function innertubeIsLive(
  videoId: string,
): Promise<{ live: boolean; title: string | null } | null> {
  try {
    const res = await fetch(INNERTUBE_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        context: {
          client: { clientName: "WEB", clientVersion: "2.20250101.00.00" },
        },
        videoId,
      }),
    });
    if (!res.ok) return null;
    const j = await res.json();
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
  try {
    const res = await fetch(CHANNEL_LIVE_URL, {
      redirect: "follow",
      headers: {
        // 完整 Chrome 标记:缺 Chrome/xx token 时 YouTube 对部分(尤其数据中心)IP
        // 返回降级页面,页面里没有 isLiveNow 字段 → 生产上实播被判为未开播
        "User-Agent":
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36",
        "Accept-Language": "zh-TW,zh;q=0.9,en;q=0.8",
        Cookie: "CONSENT=YES+cb; SOCS=CAI",
      },
    });
    const html = await res.text();
    // videoId 三重来源:canonical → 重定向后的最终 URL → 页面首个 videoId 字段
    // (降级页常缺 canonical,但 /live 的 302 目标仍是 watch 页)
    videoId =
      html.match(/<link rel="canonical" href="https:\/\/www\.youtube\.com\/watch\?v=([\w-]{11})"/)?.[1] ??
      res.url.match(/[?&]v=([\w-]{11})/)?.[1] ??
      html.match(/"videoId":"([\w-]{11})"/)?.[1] ?? null;
    title = html.match(/<title>(.*?)<\/title>/)?.[1]
      ?.replace(" - YouTube", "").trim() ?? null;
    // 权威信号是 liveBroadcastDetails.isLiveNow:
    // 频道有"预告中"直播时页面也会出现 "isLive":true(实测误报),isUpcoming 场景必须排除。
    const hasLiveNow = html.includes('"isLiveNow":true');
    const hasIsLive = html.includes('"isLive":true');
    const hasUpcoming = html.includes('"isUpcoming":true');
    isLive = hasLiveNow || (videoId !== null && hasIsLive && !hasUpcoming);
    let via = isLive ? "page" : "none";
    // 第二通道:页面没给出开播标记但拿到了 videoId(数据中心 IP 降级页场景)
    // → innertube 确认;标记正常但未拿到 videoId 的场景无从确认,维持原判
    if (!isLive && videoId !== null) {
      const it = await innertubeIsLive(videoId);
      if (it?.live === true) {
        isLive = true;
        via = "innertube";
        title = title ?? it.title;
      }
    }
    // 诊断信息随响应返回,便于生产排查(pg_cron 与 App 都不消费该字段)
    diag = {
      status: res.status,
      final_url: res.url,
      html_len: html.length,
      hasLiveNow,
      hasIsLive,
      hasUpcoming,
      via,
    };
  } catch (_) {
    // 探测失败按"状态未知"处理:不改动现有记录
    return new Response(JSON.stringify({ live: null, error: "probe_failed" }), {
      headers: cors,
    });
  }

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
