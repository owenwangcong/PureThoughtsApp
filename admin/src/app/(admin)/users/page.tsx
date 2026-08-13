"use client";

import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { toast } from "sonner";
import { useAdminProfile } from "@/components/admin-guard";
import { ConfirmButton } from "@/components/confirm-button";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { fmtDate } from "@/lib/format";
import { supabase } from "@/lib/supabase";
import { displayLoginName } from "@/lib/username";

type ProfileRow = {
  id: string;
  display_name: string;
  created_at: string;
  banned_at: string | null;
  is_app_admin: boolean;
  region: string;
  recovery_email: string | null;
};

async function callAdminOps(body: Record<string, unknown>) {
  const { data, error } = await supabase.functions.invoke("admin-ops", {
    body,
  });
  if (error) {
    // FunctionsHttpError 时尽量取出函数返回的错误码
    let detail = error.message;
    if ("context" in error) {
      try {
        const ctx = (error as { context: Response }).context;
        const j = await ctx.json();
        if (j?.error) detail = j.error;
      } catch {
        // 保留原 message
      }
    }
    throw new Error(detail);
  }
  return data;
}

const OPS_ERROR_TEXT: Record<string, string> = {
  cannot_demote_self: "不能撤銷自己的管理員身份",
  use_delete_account: "刪除自己請在 App 內操作",
  owner_of_active_group: "資料異常:該用戶仍掛著某個群的群主(v0.6.0 去群化後不應出現)",
  password_too_short: "密碼至少 8 位",
};

function opsErrText(e: Error): string {
  return OPS_ERROR_TEXT[e.message] ?? e.message;
}

export default function UsersPage() {
  const profile = useAdminProfile();
  const queryClient = useQueryClient();
  const [search, setSearch] = useState("");
  const [applied, setApplied] = useState("");

  const { data: users, isPending, error } = useQuery({
    queryKey: ["admin-users", applied],
    queryFn: async () => {
      let q = supabase
        .from("profiles")
        .select(
          "id, display_name, created_at, banned_at, is_app_admin, region, recovery_email",
        )
        .order("created_at", { ascending: false })
        .limit(50);
      if (applied) q = q.ilike("display_name", `%${applied}%`);
      const { data, error } = await q;
      if (error) throw error;
      return data as ProfileRow[];
    },
  });

  const { data: logins } = useQuery({
    queryKey: ["admin-logins", users?.map((u) => u.id)],
    enabled: !!users && users.length > 0,
    queryFn: async () => {
      const { data, error } = await supabase.rpc("admin_list_logins", {
        p_user_ids: users!.map((u) => u.id),
      });
      if (error) throw error;
      return Object.fromEntries(
        data.map((r) => [r.user_id, displayLoginName(r.login_email)]),
      ) as Record<string, string>;
    },
  });

  const [pwTarget, setPwTarget] = useState<ProfileRow | null>(null);
  const [newPw, setNewPw] = useState("");
  const [pwBusy, setPwBusy] = useState(false);

  function refresh() {
    void queryClient.invalidateQueries({ queryKey: ["admin-users"] });
  }

  async function setBanned(u: ProfileRow, banned: boolean) {
    const { error } = await supabase
      .from("profiles")
      .update({ banned_at: banned ? new Date().toISOString() : null })
      .eq("id", u.id);
    if (error) {
      toast.error(`操作失敗:${error.message}`);
      return;
    }
    toast.success(banned ? "已封禁" : "已解封");
    refresh();
  }

  async function setAdmin(u: ProfileRow, isAdmin: boolean) {
    try {
      await callAdminOps({ action: "set_admin", user_id: u.id, is_admin: isAdmin });
      toast.success(isAdmin ? "已設為管理員" : "已撤銷管理員");
      refresh();
    } catch (e) {
      toast.error(opsErrText(e as Error));
    }
  }

  async function deleteUser(u: ProfileRow) {
    try {
      await callAdminOps({ action: "delete_user", user_id: u.id });
      toast.success("帳號已刪除(報數記錄已匿名化保留)");
      refresh();
    } catch (e) {
      toast.error(opsErrText(e as Error));
    }
  }

  async function resetPassword() {
    if (!pwTarget) return;
    if (newPw.length < 8) {
      toast.error("密碼至少 8 位");
      return;
    }
    setPwBusy(true);
    try {
      await callAdminOps({
        action: "reset_password",
        user_id: pwTarget.id,
        new_password: newPw,
      });
      toast.success(`已重置「${pwTarget.display_name || "(未設名)"}」的密碼`);
      setPwTarget(null);
      setNewPw("");
    } catch (e) {
      toast.error(opsErrText(e as Error));
    } finally {
      setPwBusy(false);
    }
  }

  return (
    <div className="space-y-4">
      <h2 className="text-xl font-semibold">用戶管理</h2>
      <form
        className="flex gap-2"
        onSubmit={(e) => {
          e.preventDefault();
          setApplied(search.trim());
        }}
      >
        <Input
          className="max-w-72"
          placeholder="按顯示名搜尋(留空列最近註冊)"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
        <Button type="submit" variant="outline">
          搜尋
        </Button>
      </form>

      {isPending && <p className="text-muted-foreground">載入中…</p>}
      {error && <p className="text-destructive">載入失敗:{error.message}</p>}
      {users && (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>顯示名</TableHead>
              <TableHead>登入名</TableHead>
              <TableHead>地區</TableHead>
              <TableHead>註冊</TableHead>
              <TableHead>狀態</TableHead>
              <TableHead>操作</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {users.map((u) => (
              <TableRow key={u.id} className={u.banned_at ? "opacity-70" : ""}>
                <TableCell className="max-w-40 truncate font-medium">
                  {u.display_name || "(未設名)"}
                </TableCell>
                <TableCell className="max-w-44 truncate text-muted-foreground">
                  {logins?.[u.id] ?? "…"}
                  {u.recovery_email && (
                    <span className="block truncate text-xs">
                      找回信箱:{u.recovery_email}
                    </span>
                  )}
                </TableCell>
                <TableCell>{u.region || "—"}</TableCell>
                <TableCell>{fmtDate(u.created_at)}</TableCell>
                <TableCell className="space-x-1">
                  {u.is_app_admin && <Badge>管理員</Badge>}
                  {u.banned_at && <Badge variant="destructive">已封禁</Badge>}
                  {!u.is_app_admin && !u.banned_at && (
                    <Badge variant="outline">正常</Badge>
                  )}
                </TableCell>
                <TableCell className="space-x-2 whitespace-nowrap">
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => {
                      setPwTarget(u);
                      setNewPw("");
                    }}
                  >
                    重置密碼
                  </Button>
                  {u.banned_at ? (
                    <ConfirmButton
                      label="解封"
                      title={`解除「${u.display_name || "(未設名)"}」的封禁?`}
                      onConfirm={() => setBanned(u, false)}
                    />
                  ) : (
                    u.id !== profile.userId && (
                      <ConfirmButton
                        label="封禁"
                        destructive
                        title={`封禁「${u.display_name || "(未設名)"}」?`}
                        description="封禁後無法報數、提問、舉報;可隨時解封。"
                        onConfirm={() => setBanned(u, true)}
                      />
                    )
                  )}
                  {u.id !== profile.userId &&
                    (u.is_app_admin ? (
                      <ConfirmButton
                        label="撤管理員"
                        destructive
                        title={`撤銷「${u.display_name || "(未設名)"}」的管理員?`}
                        onConfirm={() => setAdmin(u, false)}
                      />
                    ) : (
                      <ConfirmButton
                        label="設管理員"
                        title={`把「${u.display_name || "(未設名)"}」設為 App 管理員?`}
                        description="管理員可管理活動、通知、舉報並登入本後台,請謹慎授予。"
                        onConfirm={() => setAdmin(u, true)}
                      />
                    ))}
                  {u.id !== profile.userId && (
                    <ConfirmButton
                      label="刪除帳號"
                      destructive
                      title={`刪除「${u.display_name || "(未設名)"}」的帳號?`}
                      description="不可恢復。報數記錄匿名化保留(共修總量不變)。"
                      confirmLabel="確認刪除"
                      onConfirm={() => deleteUser(u)}
                    />
                  )}
                </TableCell>
              </TableRow>
            ))}
            {users.length === 0 && (
              <TableRow>
                <TableCell
                  colSpan={6}
                  className="text-center text-muted-foreground"
                >
                  沒有匹配的用戶
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      )}

      <Dialog open={pwTarget !== null} onOpenChange={(o) => !o && setPwTarget(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>
              重置密碼:{pwTarget?.display_name || "(未設名)"}
              {pwTarget && logins?.[pwTarget.id] && `(${logins[pwTarget.id]})`}
            </DialogTitle>
          </DialogHeader>
          <div className="space-y-2">
            <Label>新密碼(至少 8 位)</Label>
            <Input
              type="text"
              autoComplete="off"
              value={newPw}
              onChange={(e) => setNewPw(e.target.value)}
            />
            <p className="text-xs text-muted-foreground">
              重置後請透過可信渠道告知用戶新密碼,並提醒其登入後自行修改。
            </p>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setPwTarget(null)}>
              取消
            </Button>
            <Button disabled={pwBusy || newPw.length < 8} onClick={resetPassword}>
              {pwBusy ? "重置中…" : "確認重置"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
