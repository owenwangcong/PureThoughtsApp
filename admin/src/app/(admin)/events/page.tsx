"use client";

import { useQuery, useQueryClient } from "@tanstack/react-query";
import Link from "next/link";
import { toast } from "sonner";
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
import { fmtDateTime } from "@/lib/format";
import { supabase } from "@/lib/supabase";
import { expandWeeklyUtc, fmtWallTime } from "@/lib/tz";

type EventRow = {
  id: string;
  title: string;
  start_at: string;
  timezone: string;
  recurrence_rule: string | null;
  event_types: { name_hant: string } | null;
  event_agenda_items: { count: number }[];
  event_attachments: { count: number }[];
};

function nextOccurrence(e: EventRow): string | null {
  const weekly = (e.recurrence_rule ?? "").toUpperCase().includes("FREQ=WEEKLY");
  if (weekly) return expandWeeklyUtc(e.start_at, e.timezone, 1)[0] ?? null;
  return new Date(e.start_at) > new Date() ? e.start_at : null;
}

export default function EventsPage() {
  const queryClient = useQueryClient();
  const { data, isPending, error } = useQuery({
    queryKey: ["events"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("events")
        .select(
          "id, title, start_at, timezone, recurrence_rule, event_types(name_hant), event_agenda_items(count), event_attachments(count)",
        )
        .order("start_at", { ascending: false })
        .limit(100);
      if (error) throw error;
      return data as unknown as EventRow[];
    },
  });

  async function removeEvent(id: string) {
    // 与 App 端一致:先清 Storage 附件对象,再删 events(FK 级联清子表)
    const { data: files, error: qe } = await supabase
      .from("event_attachments")
      .select("storage_path")
      .eq("event_id", id);
    if (qe) {
      toast.error(`讀取附件失敗:${qe.message}`);
      return;
    }
    if (files.length > 0) {
      const { error: se } = await supabase.storage
        .from("event-files")
        .remove(files.map((f) => f.storage_path));
      if (se) {
        toast.error(`刪除附件檔案失敗:${se.message}`);
        return;
      }
    }
    const { error } = await supabase.from("events").delete().eq("id", id);
    if (error) {
      toast.error(`刪除失敗:${error.message}`);
      return;
    }
    toast.success("活動已刪除(會生成全員變更通知)");
    void queryClient.invalidateQueries({ queryKey: ["events"] });
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h2 className="text-xl font-semibold">活動管理</h2>
        <Button render={<Link href="/events/edit" />}>新增活動</Button>
      </div>

      {isPending && <p className="text-muted-foreground">載入中…</p>}
      {error && <p className="text-destructive">載入失敗:{error.message}</p>}
      {data && (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>標題</TableHead>
              <TableHead>類型</TableHead>
              <TableHead>首場(活動當地)</TableHead>
              <TableHead>循環</TableHead>
              <TableHead>下次(你的本地)</TableHead>
              <TableHead>議程</TableHead>
              <TableHead>附件</TableHead>
              <TableHead />
            </TableRow>
          </TableHeader>
          <TableBody>
            {data.map((e) => {
              const next = nextOccurrence(e);
              return (
                <TableRow key={e.id}>
                  <TableCell className="max-w-52 truncate font-medium">
                    {e.title}
                  </TableCell>
                  <TableCell>{e.event_types?.name_hant ?? "—"}</TableCell>
                  <TableCell className="whitespace-nowrap">
                    {fmtWallTime(e.start_at, e.timezone)}
                    <span className="ml-1 text-xs text-muted-foreground">
                      {e.timezone}
                    </span>
                  </TableCell>
                  <TableCell>
                    {e.recurrence_rule ? (
                      <Badge variant="secondary">每週</Badge>
                    ) : (
                      <Badge variant="outline">單次</Badge>
                    )}
                  </TableCell>
                  <TableCell className="whitespace-nowrap">
                    {next ? fmtDateTime(next) : "已結束"}
                  </TableCell>
                  <TableCell>{e.event_agenda_items[0]?.count ?? 0}</TableCell>
                  <TableCell>{e.event_attachments[0]?.count ?? 0}</TableCell>
                  <TableCell className="space-x-2 whitespace-nowrap">
                    <Button
                      variant="outline"
                      size="sm"
                      render={<Link href={`/events/edit?id=${e.id}`} />}
                    >
                      編輯
                    </Button>
                    <ConfirmButton
                      label="刪除"
                      destructive
                      title={`刪除「${e.title}」?`}
                      description="連同議程、附件與單次覆蓋一併刪除,並向全員發出活動變更通知。"
                      onConfirm={() => removeEvent(e.id)}
                    />
                  </TableCell>
                </TableRow>
              );
            })}
            {data.length === 0 && (
              <TableRow>
                <TableCell
                  colSpan={8}
                  className="text-center text-muted-foreground"
                >
                  尚無活動
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      )}
    </div>
  );
}
