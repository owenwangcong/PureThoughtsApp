// 账号删除 Edge Function(PRD §10.1)
// 流程:验证调用者 JWT → 若仍是活跃群群主则拒绝(须先转让/解散)→
// admin.deleteUser:profiles 级联删,practice_logs reporter/subject 置空
// (匿名化,群总量不变),已解散群 owner_id 置空。
import { createClient } from "jsr:@supabase/supabase-js@2";

Deno.serve(async (req) => {
  const cors = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, content-type, apikey",
  };
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const authHeader = req.headers.get("Authorization") ?? "";
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // 验证调用者身份
  const jwt = authHeader.replace("Bearer ", "");
  const { data: userData, error: userErr } = await admin.auth.getUser(jwt);
  if (userErr || !userData?.user) {
    return new Response(JSON.stringify({ error: "unauthorized" }), {
      status: 401,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }
  const uid = userData.user.id;

  // 活跃群群主须先转让或解散(PRD §3.2)
  const { data: owned, error: ownedErr } = await admin
    .from("groups")
    .select("id")
    .eq("owner_id", uid)
    .is("deleted_at", null)
    .limit(1);
  if (ownedErr) {
    return new Response(JSON.stringify({ error: ownedErr.message }), {
      status: 500,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }
  if (owned && owned.length > 0) {
    return new Response(JSON.stringify({ error: "owner_of_active_group" }), {
      status: 409,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }

  const { error: delErr } = await admin.auth.admin.deleteUser(uid);
  if (delErr) {
    return new Response(JSON.stringify({ error: delErr.message }), {
      status: 500,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ ok: true }), {
    headers: { ...cors, "Content-Type": "application/json" },
  });
});
