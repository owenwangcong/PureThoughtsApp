// 管理后台特权操作 Edge Function(PRD §15 / PLAN P7.3)
// POST JSON:
//   { action: "reset_password", user_id, new_password }  重置任意用户密码(替代 deploy 文档 §10 psql)
//   { action: "delete_user",   user_id }                 代删账号(复用 delete-account 语义:匿名化由级联/触发器完成)
//   { action: "set_admin",     user_id, is_admin }       设/撤 App 管理员
// 鉴权:调用者 JWT 有效且 profiles.is_app_admin = true;anon 401、非管理员 403。
// CORS:仅放行 admin 子域与 localhost 开发端口(PRD §15.1)。
import { createClient } from "jsr:@supabase/supabase-js@2";

const ALLOWED_ORIGINS = [
  "https://admin.pure-thoughts.com",
  "http://localhost:3000",
  "http://localhost:3001",
];

function corsFor(req: Request): Record<string, string> {
  const origin = req.headers.get("Origin") ?? "";
  return {
    "Access-Control-Allow-Origin": ALLOWED_ORIGINS.includes(origin)
      ? origin
      : ALLOWED_ORIGINS[0],
    "Access-Control-Allow-Headers": "authorization, content-type, apikey",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    Vary: "Origin",
  };
}

Deno.serve(async (req) => {
  const cors = corsFor(req);
  const json = (status: number, body: unknown) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { ...cors, "Content-Type": "application/json" },
    });

  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // 调用者必须是登录用户且为 App 管理员
  const jwt = (req.headers.get("Authorization") ?? "").replace("Bearer ", "");
  const { data: userData, error: userErr } = await admin.auth.getUser(jwt);
  if (userErr || !userData?.user) return json(401, { error: "unauthorized" });
  const callerId = userData.user.id;

  const { data: caller, error: callerErr } = await admin
    .from("profiles")
    .select("is_app_admin")
    .eq("id", callerId)
    .single();
  if (callerErr || !caller?.is_app_admin) {
    return json(403, { error: "forbidden" });
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json(400, { error: "bad_json" });
  }
  const action = body.action;
  const userId = body.user_id;
  if (typeof userId !== "string" || !userId) {
    return json(400, { error: "user_id_required" });
  }

  switch (action) {
    case "reset_password": {
      const pw = body.new_password;
      // GoTrue 本身最短 6 位;后台统一按 8 位要求,降低弱密码
      if (typeof pw !== "string" || pw.length < 8) {
        return json(400, { error: "password_too_short" });
      }
      const { error } = await admin.auth.admin.updateUserById(userId, {
        password: pw,
      });
      if (error) return json(500, { error: error.message });
      return json(200, { ok: true });
    }

    case "set_admin": {
      const isAdmin = body.is_admin;
      if (typeof isAdmin !== "boolean") {
        return json(400, { error: "is_admin_required" });
      }
      // 防自锁:不允许撤掉自己的管理员
      if (userId === callerId && !isAdmin) {
        return json(409, { error: "cannot_demote_self" });
      }
      const { error } = await admin
        .from("profiles")
        .update({ is_app_admin: isAdmin })
        .eq("id", userId);
      if (error) return json(500, { error: error.message });
      return json(200, { ok: true });
    }

    case "delete_user": {
      // 删自己请走 App 内 delete-account(带本人确认流程)
      if (userId === callerId) return json(409, { error: "use_delete_account" });
      // 与 delete-account 相同约束:活跃群群主须先转让/解散(PRD §3.2)
      const { data: owned, error: ownedErr } = await admin
        .from("groups")
        .select("id")
        .eq("owner_id", userId)
        .is("deleted_at", null)
        .limit(1);
      if (ownedErr) return json(500, { error: ownedErr.message });
      if (owned && owned.length > 0) {
        return json(409, { error: "owner_of_active_group" });
      }
      const { error } = await admin.auth.admin.deleteUser(userId);
      if (error) return json(500, { error: error.message });
      return json(200, { ok: true });
    }

    default:
      return json(400, { error: "unknown_action" });
  }
});
