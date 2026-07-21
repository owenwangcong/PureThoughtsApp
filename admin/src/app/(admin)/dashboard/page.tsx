"use client";

import { useQuery } from "@tanstack/react-query";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { supabase } from "@/lib/supabase";

function isoDaysAgo(n: number): string {
  const d = new Date();
  d.setDate(d.getDate() - n);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

function StatCard({ label, value, hint }: { label: string; value: string; hint?: string }) {
  return (
    <Card>
      <CardHeader className="pb-1">
        <CardTitle className="text-sm font-normal text-muted-foreground">
          {label}
        </CardTitle>
      </CardHeader>
      <CardContent>
        <p className="text-2xl font-semibold">{value}</p>
        {hint && <p className="text-xs text-muted-foreground">{hint}</p>}
      </CardContent>
    </Card>
  );
}

function BarList({
  rows,
}: {
  rows: { label: string; a: number; b: number }[];
}) {
  const max = Math.max(1, ...rows.map((r) => r.a));
  return (
    <div className="space-y-1">
      {rows.map((r) => (
        <div key={r.label} className="flex items-center gap-2 text-xs">
          <span className="w-20 shrink-0 text-muted-foreground">{r.label}</span>
          <div className="h-4 flex-1 rounded bg-muted">
            <div
              className="h-4 rounded bg-primary/70"
              style={{ width: `${(r.a / max) * 100}%` }}
            />
          </div>
          <span className="w-24 shrink-0 text-right tabular-nums">
            {r.a} 條 / {r.b} 人
          </span>
        </div>
      ))}
      {rows.length === 0 && (
        <p className="text-sm text-muted-foreground">近 30 日無報數</p>
      )}
    </div>
  );
}

export default function DashboardPage() {
  const from = isoDaysAgo(29);

  const { data: counts } = useQuery({
    queryKey: ["dash-counts"],
    queryFn: async () => {
      const [users, groups, backlog, pending] = await Promise.all([
        supabase.from("profiles").select("*", { count: "exact", head: true }),
        supabase
          .from("groups")
          .select("*", { count: "exact", head: true })
          .is("deleted_at", null),
        supabase
          .from("notifications")
          .select("*", { count: "exact", head: true })
          .not("scheduled_at", "is", null)
          .is("sent_at", null)
          .lte("scheduled_at", new Date().toISOString()),
        supabase
          .from("notifications")
          .select("*", { count: "exact", head: true })
          .not("scheduled_at", "is", null)
          .is("sent_at", null)
          .gt("scheduled_at", new Date().toISOString()),
      ]);
      for (const r of [users, groups, backlog, pending]) {
        if (r.error) throw r.error;
      }
      return {
        users: users.count ?? 0,
        groups: groups.count ?? 0,
        backlog: backlog.count ?? 0,
        pending: pending.count ?? 0,
      };
    },
  });

  const { data: daily } = useQuery({
    queryKey: ["dash-daily", from],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("practice_logs")
        .select("local_date, reporter_id, subject_user_id")
        .is("deleted_at", null)
        .gte("local_date", from)
        .limit(20000);
      if (error) throw error;
      const byDate = new Map<string, { entries: number; users: Set<string> }>();
      for (const r of data) {
        const d = byDate.get(r.local_date) ?? { entries: 0, users: new Set() };
        d.entries += 1;
        const uid = r.subject_user_id ?? r.reporter_id;
        if (uid) d.users.add(uid);
        byDate.set(r.local_date, d);
      }
      return [...byDate.entries()]
        .sort((x, y) => y[0].localeCompare(x[0]))
        .map(([date, v]) => ({ label: date.slice(5), a: v.entries, b: v.users.size }));
    },
  });

  const { data: push } = useQuery({
    queryKey: ["dash-push"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("push_tokens")
        .select("platform, fcm_failed")
        .limit(10000);
      if (error) throw error;
      const apns = data.filter((t) => t.platform === "apns").length;
      const fcm = data.filter((t) => t.platform === "fcm").length;
      const failed = data.filter((t) => t.fcm_failed).length;
      return { apns, fcm, failed, total: data.length };
    },
  });

  const thirtyDayEntries = daily?.reduce((s, r) => s + r.a, 0) ?? null;

  return (
    <div className="space-y-6">
      <h2 className="text-xl font-semibold">數據看板</h2>

      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <StatCard label="註冊用戶" value={counts ? String(counts.users) : "…"} />
        <StatCard label="活躍群組" value={counts ? String(counts.groups) : "…"} />
        <StatCard
          label="近 30 日報數"
          value={thirtyDayEntries === null ? "…" : `${thirtyDayEntries} 條`}
        />
        <StatCard
          label="通知佇列"
          value={counts ? `${counts.backlog} 積壓` : "…"}
          hint={counts ? `另有 ${counts.pending} 條排程中(未到點)` : undefined}
        />
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">
            每日報數(近 30 日,條數 / 活躍人數)
          </CardTitle>
        </CardHeader>
        <CardContent>
          {daily ? <BarList rows={daily} /> : <p className="text-muted-foreground">載入中…</p>}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">推送投遞健康(push_tokens)</CardTitle>
        </CardHeader>
        <CardContent>
          {push ? (
            <div className="flex gap-8 text-sm">
              <span>APNs(iOS):{push.apns}</span>
              <span>FCM(海外 Android):{push.fcm}</span>
              <span className={push.failed > 0 ? "text-destructive" : ""}>
                投遞失敗標記:{push.failed}
                {push.fcm > 0 && `(${Math.round((push.failed / Math.max(1, push.total)) * 100)}%)`}
              </span>
            </div>
          ) : (
            <p className="text-muted-foreground">載入中…</p>
          )}
          <p className="mt-2 text-xs text-muted-foreground">
            大陸 Android 無 token 屬正常(走 App 內通知中心 + 郵件兜底)。
          </p>
        </CardContent>
      </Card>

      {counts && counts.backlog > 0 && (
        <p className="text-sm text-destructive">
          ⚠️ 有 {counts.backlog} 條通知已到點未投遞——檢查 pg_cron 兜底任務與 push-dispatch 函數(deploy 文檔 §11④)。
        </p>
      )}
    </div>
  );
}
