"use client";

import { useQuery, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { useAdminProfile } from "@/components/admin-guard";
import { ConfirmButton } from "@/components/confirm-button";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { fmtDateTime } from "@/lib/format";
import { supabase } from "@/lib/supabase";

type ReportRow = {
  id: string;
  target_type: "user" | "group" | "log";
  target_id: string;
  reason: string;
  status: "open" | "resolved";
  handled_by: string | null;
  created_at: string;
  reporter: { display_name: string | null } | null;
};

type TargetContext = {
  users: Record<string, { display_name: string | null; banned_at: string | null }>;
  groups: Record<string, { name: string; deleted_at: string | null }>;
  logs: Record<
    string,
    {
      quantity: number;
      unit: string;
      note: string | null;
      local_date: string;
      deleted_at: string | null;
      subject_name: string | null;
      practice_types: { name_hant: string } | null;
    }
  >;
};

const UNIT_LABEL: Record<string, string> = {
  volume: "部",
  recitation: "遍",
  count: "次",
  minute: "分鐘",
};

const TARGET_LABEL: Record<string, string> = {
  user: "用戶",
  group: "群組",
  log: "報數記錄",
};

function useReports(status: "open" | "resolved") {
  return useQuery({
    queryKey: ["reports", status],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("reports")
        .select(
          "id, target_type, target_id, reason, status, handled_by, created_at, reporter:profiles!reports_reporter_id_fkey(display_name)",
        )
        .eq("status", status)
        .order("created_at", { ascending: status === "open" })
        .limit(100);
      if (error) throw error;
      return data as unknown as ReportRow[];
    },
  });
}

function useTargetContext(reports: ReportRow[] | undefined) {
  const ids = {
    user: reports?.filter((r) => r.target_type === "user").map((r) => r.target_id) ?? [],
    group: reports?.filter((r) => r.target_type === "group").map((r) => r.target_id) ?? [],
    log: reports?.filter((r) => r.target_type === "log").map((r) => r.target_id) ?? [],
  };
  return useQuery({
    queryKey: ["report-targets", ids],
    enabled: !!reports && reports.length > 0,
    queryFn: async (): Promise<TargetContext> => {
      const ctx: TargetContext = { users: {}, groups: {}, logs: {} };
      const [users, groups, logs] = await Promise.all([
        ids.user.length
          ? supabase.from("profiles").select("id, display_name, banned_at").in("id", ids.user)
          : Promise.resolve({ data: [], error: null }),
        ids.group.length
          ? supabase.from("groups").select("id, name, deleted_at").in("id", ids.group)
          : Promise.resolve({ data: [], error: null }),
        ids.log.length
          ? supabase
              .from("practice_logs")
              .select(
                "id, quantity, unit, note, local_date, deleted_at, subject_name, practice_types(name_hant)",
              )
              .in("id", ids.log)
          : Promise.resolve({ data: [], error: null }),
      ]);
      if (users.error) throw users.error;
      if (groups.error) throw groups.error;
      if (logs.error) throw logs.error;
      for (const u of users.data ?? []) ctx.users[u.id] = u;
      for (const g of groups.data ?? []) ctx.groups[g.id] = g;
      for (const l of logs.data ?? [])
        ctx.logs[l.id] = l as unknown as TargetContext["logs"][string];
      return ctx;
    },
  });
}

function targetText(r: ReportRow, ctx: TargetContext | undefined): string {
  if (!ctx) return "…";
  if (r.target_type === "user") {
    const u = ctx.users[r.target_id];
    if (!u) return "(用戶不存在/已刪號)";
    return `${u.display_name ?? "(未設名)"}${u.banned_at ? " · 已封禁" : ""}`;
  }
  if (r.target_type === "group") {
    const g = ctx.groups[r.target_id];
    if (!g) return "(群不存在)";
    return `${g.name}${g.deleted_at ? " · 已解散" : ""}`;
  }
  const l = ctx.logs[r.target_id];
  if (!l) return "(記錄不存在)";
  const unit = UNIT_LABEL[l.unit] ?? l.unit;
  return `${l.practice_types?.name_hant ?? "?"} ${l.quantity}${unit} · ${l.local_date}${
    l.subject_name ? ` · 代 ${l.subject_name}` : ""
  }${l.note ? ` · 「${l.note}」` : ""}${l.deleted_at ? " · 已刪除" : ""}`;
}

function ReportTable({ status }: { status: "open" | "resolved" }) {
  const profile = useAdminProfile();
  const queryClient = useQueryClient();
  const { data: reports, isPending, error } = useReports(status);
  const { data: ctx } = useTargetContext(reports);

  function refresh() {
    void queryClient.invalidateQueries({ queryKey: ["reports"] });
    void queryClient.invalidateQueries({ queryKey: ["report-targets"] });
  }

  async function setStatus(r: ReportRow, next: "open" | "resolved") {
    const { error } = await supabase
      .from("reports")
      .update(
        next === "resolved"
          ? { status: "resolved", handled_by: profile.userId }
          : { status: "open", handled_by: null },
      )
      .eq("id", r.id);
    if (error) {
      toast.error(`操作失敗:${error.message}`);
      return;
    }
    toast.success(next === "resolved" ? "已標記處理" : "已重開");
    refresh();
  }

  async function setBanned(userId: string, banned: boolean) {
    const { error } = await supabase
      .from("profiles")
      .update({ banned_at: banned ? new Date().toISOString() : null })
      .eq("id", userId);
    if (error) {
      toast.error(`操作失敗:${error.message}`);
      return;
    }
    toast.success(banned ? "已封禁" : "已解封");
    refresh();
  }

  async function deleteLog(logId: string) {
    const { error } = await supabase.rpc("delete_practice_log", {
      p_log_id: logId,
    });
    if (error) {
      toast.error(`刪除失敗:${error.message}`);
      return;
    }
    toast.success("記錄已刪除(軟刪)");
    refresh();
  }

  if (isPending) return <p className="text-muted-foreground">載入中…</p>;
  if (error) return <p className="text-destructive">載入失敗:{error.message}</p>;

  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>時間</TableHead>
          <TableHead>舉報人</TableHead>
          <TableHead>對象</TableHead>
          <TableHead>對象內容</TableHead>
          <TableHead>理由</TableHead>
          <TableHead>操作</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {reports.map((r) => {
          const user = r.target_type === "user" ? ctx?.users[r.target_id] : undefined;
          const log = r.target_type === "log" ? ctx?.logs[r.target_id] : undefined;
          return (
            <TableRow key={r.id}>
              <TableCell className="whitespace-nowrap">
                {fmtDateTime(r.created_at)}
              </TableCell>
              <TableCell>{r.reporter?.display_name ?? "—"}</TableCell>
              <TableCell>
                <Badge variant="outline">{TARGET_LABEL[r.target_type]}</Badge>
              </TableCell>
              <TableCell className="max-w-72">{targetText(r, ctx)}</TableCell>
              <TableCell className="max-w-56 truncate">{r.reason}</TableCell>
              <TableCell className="space-x-2 whitespace-nowrap">
                {r.target_type === "user" && user && !user.banned_at && (
                  <ConfirmButton
                    label="封禁"
                    destructive
                    title="封禁此用戶?"
                    description="封禁後該用戶無法報數、建群、舉報(banned_at 生效);可隨時解封。"
                    onConfirm={async () => {
                      await setBanned(r.target_id, true);
                      if (r.status === "open") await setStatus(r, "resolved");
                    }}
                  />
                )}
                {r.target_type === "user" && user?.banned_at && (
                  <ConfirmButton
                    label="解封"
                    title="解除封禁?"
                    onConfirm={() => setBanned(r.target_id, false)}
                  />
                )}
                {r.target_type === "log" && log && !log.deleted_at && (
                  <ConfirmButton
                    label="刪除記錄"
                    destructive
                    title="刪除這條報數記錄?"
                    description="軟刪除,群總量隨之扣減。"
                    onConfirm={() => deleteLog(r.target_id)}
                  />
                )}
                {r.status === "open" ? (
                  <Button size="sm" onClick={() => setStatus(r, "resolved")}>
                    標記已處理
                  </Button>
                ) : (
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={() => setStatus(r, "open")}
                  >
                    重開
                  </Button>
                )}
              </TableCell>
            </TableRow>
          );
        })}
        {reports.length === 0 && (
          <TableRow>
            <TableCell colSpan={6} className="text-center text-muted-foreground">
              {status === "open" ? "沒有待處理的舉報 🎉" : "暫無已處理記錄"}
            </TableCell>
          </TableRow>
        )}
      </TableBody>
    </Table>
  );
}

export default function ReportsPage() {
  return (
    <div className="space-y-4">
      <h2 className="text-xl font-semibold">舉報處理</h2>
      <Tabs defaultValue="open">
        <TabsList>
          <TabsTrigger value="open">待處理</TabsTrigger>
          <TabsTrigger value="resolved">已處理</TabsTrigger>
        </TabsList>
        <TabsContent value="open">
          <ReportTable status="open" />
        </TabsContent>
        <TabsContent value="resolved">
          <ReportTable status="resolved" />
        </TabsContent>
      </Tabs>
    </div>
  );
}
