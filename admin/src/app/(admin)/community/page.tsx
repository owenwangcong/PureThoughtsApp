"use client";

import { useQuery, useQueryClient } from "@tanstack/react-query";
import Link from "next/link";
import { useState } from "react";
import { toast } from "sonner";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
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

const UNIT_LABEL: Record<string, string> = {
  volume: "部",
  recitation: "遍",
  count: "次",
  minute: "分鐘",
};

type Community = {
  id: string;
  name: string;
  announcement: string | null;
  created_at: string;
};

type LegacyGroup = {
  id: string;
  name: string;
  created_at: string;
  deleted_at: string | null;
};

/**
 * 共修報數(PRD v0.6.0 §3;取代原「群組總覽」)。
 *
 * 去群化后全站只有一个共修体,本页管的就是它:名称、公告、总量。
 * 「同修列表」不在这里重造 —— 去群化后同修 = 全部注册用户,那正是
 * /users 页在管的同一张表(搜索/封禁/重置密码/代删都已具备)。
 */
export default function CommunityPage() {
  const queryClient = useQueryClient();

  const { data: community, isPending, error } = useQuery({
    queryKey: ["admin-community"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("groups")
        .select("id, name, announcement, created_at")
        .eq("is_default", true)
        .single();
      if (error) throw error;
      return data as Community;
    },
  });

  const { data: memberCount } = useQuery({
    queryKey: ["admin-community-members", community?.id],
    enabled: !!community,
    queryFn: async () => {
      const { count, error } = await supabase
        .from("group_members")
        .select("user_id", { count: "exact", head: true })
        .eq("group_id", community!.id)
        .eq("status", "approved");
      if (error) throw error;
      return count ?? 0;
    },
  });

  const { data: totals } = useQuery({
    queryKey: ["admin-community-totals", community?.id],
    enabled: !!community,
    queryFn: async () => {
      const { data, error } = await supabase
        .from("group_practice_totals")
        .select("unit, total")
        .eq("group_id", community!.id)
        .limit(10000);
      if (error) throw error;
      const m: Record<string, number> = {};
      for (const r of data) {
        const unit = r.unit as string;
        m[unit] = (m[unit] ?? 0) + Number(r.total);
      }
      return m;
    },
  });

  // 历史群(去群化前建的,已随 migration 0028 软删):只读,供追溯
  const { data: legacy } = useQuery({
    queryKey: ["admin-legacy-groups"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("groups")
        .select("id, name, created_at, deleted_at")
        .eq("is_default", false)
        .order("created_at", { ascending: false })
        .limit(100);
      if (error) throw error;
      return data as LegacyGroup[];
    },
  });

  // 草稿:null = 尚未编辑,直接显示服务端值。
  // 用「草稿覆盖」而不是 useEffect 同步 —— 后者是 react-hooks/set-state-in-effect,
  // 且查询刷新时会把用户正在输入的内容冲掉。
  const [draft, setDraft] = useState<{
    name: string;
    announcement: string;
  } | null>(null);
  const [busy, setBusy] = useState(false);

  const name = draft?.name ?? community?.name ?? "";
  const announcement = draft?.announcement ?? community?.announcement ?? "";

  function edit(patch: Partial<{ name: string; announcement: string }>) {
    setDraft({ name, announcement, ...patch });
  }

  const dirty =
    !!community &&
    (name.trim() !== community.name ||
      announcement.trim() !== (community.announcement ?? "").trim());

  async function save() {
    if (!community || !name.trim()) return;
    setBusy(true);
    const { error } = await supabase
      .from("groups")
      .update({
        name: name.trim(),
        announcement: announcement.trim() === "" ? null : announcement.trim(),
      })
      .eq("id", community.id);
    setBusy(false);
    if (error) {
      toast.error(`儲存失敗:${error.message}`);
      return;
    }
    toast.success("已儲存");
    setDraft(null); // 回到「跟随服务端值」
    void queryClient.invalidateQueries({ queryKey: ["admin-community"] });
  }

  const totalsText = totals
    ? Object.entries(totals)
        .map(([u, sum]) => `${sum.toLocaleString()}${UNIT_LABEL[u] ?? u}`)
        .join(" · ") || "—"
    : "…";

  return (
    <div className="space-y-6">
      <h2 className="text-xl font-semibold">共修報數</h2>
      {isPending && <p className="text-muted-foreground">載入中…</p>}
      {error && <p className="text-destructive">載入失敗:{error.message}</p>}

      {community && (
        <>
          <div className="grid gap-4 sm:grid-cols-3">
            <div className="rounded-lg border p-4">
              <p className="text-sm text-muted-foreground">同修人數</p>
              <p className="text-2xl font-semibold">{memberCount ?? "…"}</p>
              <Link
                href="/users"
                className="text-sm text-primary underline underline-offset-4"
              >
                前往用戶管理
              </Link>
            </div>
            <div className="rounded-lg border p-4">
              <p className="text-sm text-muted-foreground">共修總量</p>
              <p className="text-lg font-semibold break-words">{totalsText}</p>
            </div>
            <div className="rounded-lg border p-4">
              <p className="text-sm text-muted-foreground">建立時間</p>
              <p className="text-lg font-semibold">
                {fmtDate(community.created_at)}
              </p>
            </div>
          </div>

          <div className="space-y-4 rounded-lg border p-4">
            <div className="space-y-2">
              <Label htmlFor="community-name">名稱</Label>
              <Input
                id="community-name"
                value={name}
                onChange={(e) => edit({ name: e.target.value })}
                maxLength={100}
              />
              <p className="text-sm text-muted-foreground">
                App 內以「共修報數」呈現;此名稱主要用於後台識別。
              </p>
            </div>

            <div className="space-y-2">
              <Label htmlFor="community-announcement">共修公告</Label>
              <Textarea
                id="community-announcement"
                value={announcement}
                onChange={(e) => edit({ announcement: e.target.value })}
                rows={5}
                placeholder="例:本週六共修改為線上,請提前十分鐘進入會議室。"
              />
              <p className="text-sm text-muted-foreground">
                公告是常駐置頂資訊,顯示在 App「共修報數」頁最上方;
                <strong>App 內只讀,這裡是唯一編輯入口</strong>。
                儲存後會給全體同修生成一條「共修公告更新」通知。留空即撤下公告。
              </p>
            </div>

            <Button disabled={!dirty || busy || !name.trim()} onClick={save}>
              {busy ? "儲存中…" : "儲存"}
            </Button>
          </div>
        </>
      )}

      {legacy && legacy.length > 0 && (
        <details className="rounded-lg border p-4">
          <summary className="cursor-pointer text-sm font-medium">
            歷史群組({legacy.length})—— 去群化前的舊資料,只讀
          </summary>
          <p className="mt-2 text-sm text-muted-foreground">
            v0.6.0 去群化时,这些群的报数已并入共修体、群本身软删;保留仅供追溯。
          </p>
          <Table className="mt-3">
            <TableHeader>
              <TableRow>
                <TableHead>原群名</TableHead>
                <TableHead>建立</TableHead>
                <TableHead>狀態</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {legacy.map((g) => (
                <TableRow key={g.id} className="opacity-70">
                  <TableCell className="max-w-64 truncate">{g.name}</TableCell>
                  <TableCell>{fmtDate(g.created_at)}</TableCell>
                  <TableCell>
                    <Badge variant="secondary">
                      {g.deleted_at ? "已併入共修體" : "未刪除"}
                    </Badge>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </details>
      )}
    </div>
  );
}
