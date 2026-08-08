"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { toast } from "sonner";
import { ConfirmButton } from "@/components/confirm-button";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Textarea } from "@/components/ui/textarea";
import { fmtDateTime } from "@/lib/format";
import { supabase } from "@/lib/supabase";

const TYPE_LABEL: Record<string, string> = {
  general: "通用",
  event_changed: "活動變更",
  event_reminder: "活動提醒",
  almanac: "佛曆",
  proxy_log: "代報",
};

type NotifRow = {
  id: string;
  type: string;
  title: string;
  body: string | null;
  payload: unknown;
  scheduled_at: string | null;
  sent_at: string | null;
  created_at: string;
  failed_at: string | null;
  attempts: number | null;
  last_error: string | null;
};

/**
 * 投递状态(v0.5.21 起有真实状态列,不再只靠两个时间戳推导)。
 * failed = 重试用尽的终局失败(migration 0023:attempts 达 5 次仍全失败)。
 */
function statusOf(n: NotifRow): "pending" | "backlog" | "sent" | "failed" {
  if (n.failed_at) return "failed";
  if (n.sent_at) return "sent";
  if (!n.scheduled_at) return "sent"; // 立即发、由触发器秒级投递
  return new Date(n.scheduled_at) > new Date() ? "pending" : "backlog";
}

function payloadSummary(n: NotifRow): string {
  if (n.title) return n.title;
  const p = (n.payload ?? {}) as Record<string, unknown>;
  if (n.type === "event_changed")
    return `${String(p.action ?? "")} · ${String(p.title ?? "")}`;
  if (n.type === "almanac")
    return `${String(p.kind ?? "")} · ${String(p.date ?? "")}`;
  return JSON.stringify(p).slice(0, 60);
}

function PublishCard() {
  const queryClient = useQueryClient();
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [scheduled, setScheduled] = useState(false);
  const [when, setWhen] = useState("");

  const publish = useMutation({
    mutationFn: async () => {
      const params: {
        p_title: string;
        p_body?: string;
        p_scheduled_at?: string;
      } = { p_title: title.trim() };
      if (body.trim()) params.p_body = body.trim();
      if (scheduled) {
        if (!when) throw new Error("請選擇發佈時間");
        params.p_scheduled_at = new Date(when).toISOString();
      }
      const { error } = await supabase.rpc(
        "admin_publish_notification",
        params,
      );
      if (error) throw error;
    },
    onSuccess: () => {
      toast.success(scheduled ? "已排程" : "已發佈");
      setTitle("");
      setBody("");
      setScheduled(false);
      setWhen("");
      void queryClient.invalidateQueries({ queryKey: ["notifications"] });
    },
    onError: (e) => toast.error(`發佈失敗:${e.message}`),
  });

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">發佈通知(全員)</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="space-y-2">
          <Label htmlFor="n-title">標題</Label>
          <Input
            id="n-title"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            maxLength={200}
          />
        </div>
        <div className="space-y-2">
          <Label htmlFor="n-body">內容(可空)</Label>
          <Textarea
            id="n-body"
            value={body}
            onChange={(e) => setBody(e.target.value)}
            rows={3}
          />
        </div>
        <div className="flex items-center gap-3">
          <Switch
            id="n-scheduled"
            checked={scheduled}
            onCheckedChange={setScheduled}
          />
          <Label htmlFor="n-scheduled">定時發佈</Label>
          {scheduled && (
            <Input
              type="datetime-local"
              className="w-56"
              value={when}
              onChange={(e) => setWhen(e.target.value)}
            />
          )}
          {scheduled && (
            <span className="text-xs text-muted-foreground">
              (按你的本地時間)
            </span>
          )}
        </div>
        <Button
          disabled={!title.trim() || publish.isPending}
          onClick={() => publish.mutate()}
        >
          {publish.isPending ? "發佈中…" : scheduled ? "排程發佈" : "立即發佈"}
        </Button>
      </CardContent>
    </Card>
  );
}

function GeneralTable() {
  const queryClient = useQueryClient();
  const { data, isPending, error } = useQuery({
    queryKey: ["notifications", "general"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("notifications")
        .select("id, type, title, body, payload, scheduled_at, sent_at, created_at, failed_at, attempts, last_error")
        .eq("type", "general")
        .eq("scope", "all")
        .order("created_at", { ascending: false })
        .limit(50);
      if (error) throw error;
      return data as NotifRow[];
    },
  });

  async function cancel(id: string) {
    const { error } = await supabase.rpc("admin_cancel_notification", {
      p_id: id,
    });
    if (error) {
      toast.error(`操作失敗:${error.message}`);
      return;
    }
    toast.success("已撤回/取消");
    void queryClient.invalidateQueries({ queryKey: ["notifications"] });
  }

  if (isPending) return <p className="text-muted-foreground">載入中…</p>;
  if (error) return <p className="text-destructive">載入失敗:{error.message}</p>;

  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>標題</TableHead>
          <TableHead>內容</TableHead>
          <TableHead>狀態</TableHead>
          <TableHead>定時</TableHead>
          <TableHead>發出</TableHead>
          <TableHead>建立</TableHead>
          <TableHead />
        </TableRow>
      </TableHeader>
      <TableBody>
        {data.map((n) => {
          const st = statusOf(n);
          return (
            <TableRow key={n.id}>
              <TableCell className="max-w-52 truncate font-medium">
                {n.title}
              </TableCell>
              <TableCell className="max-w-64 truncate text-muted-foreground">
                {n.body ?? "—"}
              </TableCell>
              <TableCell>
                {st === "pending" && <Badge variant="secondary">排程中</Badge>}
                {st === "backlog" && <Badge variant="destructive">待投遞</Badge>}
                {st === "sent" && <Badge variant="outline">已發佈</Badge>}
                {st === "failed" && (
                  <Badge variant="destructive" title={n.last_error ?? ""}>
                    投遞失敗{n.attempts ? `(${n.attempts} 次)` : ""}
                  </Badge>
                )}
              </TableCell>
              <TableCell>{fmtDateTime(n.scheduled_at)}</TableCell>
              <TableCell>{fmtDateTime(n.sent_at)}</TableCell>
              <TableCell>{fmtDateTime(n.created_at)}</TableCell>
              <TableCell>
                <ConfirmButton
                  label={st === "pending" ? "取消排程" : "撤回"}
                  destructive
                  title={st === "pending" ? "取消這條排程?" : "撤回這條通知?"}
                  description={
                    st === "pending"
                      ? "尚未發出,取消後不會投遞。"
                      : "會從所有用戶的通知中心移除;已推送到手機的橫幅無法收回。"
                  }
                  onConfirm={() => cancel(n.id)}
                />
              </TableCell>
            </TableRow>
          );
        })}
        {data.length === 0 && (
          <TableRow>
            <TableCell colSpan={7} className="text-center text-muted-foreground">
              尚無通用通知
            </TableCell>
          </TableRow>
        )}
      </TableBody>
    </Table>
  );
}

function AllTable() {
  const { data, isPending, error } = useQuery({
    queryKey: ["notifications", "all"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("notifications")
        .select("id, type, title, body, payload, scheduled_at, sent_at, created_at, failed_at, attempts, last_error")
        .eq("scope", "all")
        .order("created_at", { ascending: false })
        .limit(50);
      if (error) throw error;
      return data as NotifRow[];
    },
  });

  if (isPending) return <p className="text-muted-foreground">載入中…</p>;
  if (error) return <p className="text-destructive">載入失敗:{error.message}</p>;

  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>類型</TableHead>
          <TableHead>摘要</TableHead>
          <TableHead>定時</TableHead>
          <TableHead>發出</TableHead>
          <TableHead>建立</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {data.map((n) => (
          <TableRow key={n.id}>
            <TableCell>
              <Badge variant="outline">{TYPE_LABEL[n.type] ?? n.type}</Badge>
            </TableCell>
            <TableCell className="max-w-80 truncate">
              {payloadSummary(n)}
            </TableCell>
            <TableCell>{fmtDateTime(n.scheduled_at)}</TableCell>
            <TableCell>{fmtDateTime(n.sent_at)}</TableCell>
            <TableCell>{fmtDateTime(n.created_at)}</TableCell>
          </TableRow>
        ))}
        {data.length === 0 && (
          <TableRow>
            <TableCell colSpan={5} className="text-center text-muted-foreground">
              暫無通知
            </TableCell>
          </TableRow>
        )}
      </TableBody>
    </Table>
  );
}

export default function NotificationsPage() {
  return (
    <div className="space-y-6">
      <h2 className="text-xl font-semibold">通知發佈</h2>
      <PublishCard />
      <Tabs defaultValue="general">
        <TabsList>
          <TabsTrigger value="general">通用通知(可撤回)</TabsTrigger>
          <TabsTrigger value="all">全部系統通知</TabsTrigger>
        </TabsList>
        <TabsContent value="general">
          <GeneralTable />
        </TabsContent>
        <TabsContent value="all">
          <AllTable />
        </TabsContent>
      </Tabs>
    </div>
  );
}
