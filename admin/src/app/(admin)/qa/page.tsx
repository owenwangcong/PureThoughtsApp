"use client";

import { useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { useAdminProfile } from "@/components/admin-guard";
import { ConfirmButton } from "@/components/confirm-button";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
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

/** 学修问答处理台(PRD §16,设计 docs/design/study-qa.md §5)。
 * RLS:管理员可见全部线程;回复 insert sender_role='admin'(触发器自动
 * 通知提问人,文案不带正文);删除为硬删(消息级联)。 */

type ThreadRow = {
  id: string;
  user_id: string;
  last_sender_role: "user" | "admin";
  last_message_at: string;
  first_message_preview: string;
  last_message_preview: string;
  created_at: string;
  profiles: { display_name: string | null } | null;
};

type MessageRow = {
  id: string;
  sender_id: string | null;
  sender_role: "user" | "admin";
  body: string;
  created_at: string;
};

function useThreads() {
  return useQuery({
    queryKey: ["qa-threads"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("qa_threads")
        .select(
          "id, user_id, last_sender_role, last_message_at, first_message_preview, last_message_preview, created_at, profiles(display_name)",
        )
        .order("last_message_at", { ascending: false })
        .limit(200);
      if (error) throw error;
      return data as unknown as ThreadRow[];
    },
  });
}

function useMessages(threadId: string | null) {
  return useQuery({
    queryKey: ["qa-messages", threadId],
    enabled: !!threadId,
    queryFn: async () => {
      const { data, error } = await supabase
        .from("qa_messages")
        .select("id, sender_id, sender_role, body, created_at")
        .eq("thread_id", threadId!)
        .order("created_at", { ascending: true });
      if (error) throw error;
      return data as MessageRow[];
    },
  });
}

function ThreadDialog({
  thread,
  onClose,
}: {
  thread: ThreadRow;
  onClose: () => void;
}) {
  const profile = useAdminProfile();
  const queryClient = useQueryClient();
  const { data: messages, isPending } = useMessages(thread.id);
  const [reply, setReply] = useState("");
  const [busy, setBusy] = useState(false);

  function refresh() {
    void queryClient.invalidateQueries({ queryKey: ["qa-threads"] });
    void queryClient.invalidateQueries({ queryKey: ["qa-pending-count"] });
    void queryClient.invalidateQueries({ queryKey: ["qa-messages", thread.id] });
  }

  async function send() {
    const body = reply.trim();
    if (!body || busy) return;
    setBusy(true);
    // 管理员回复自己提的问题时以线程主人身份发言(RLS 口径,与 App 端一致)
    const role = thread.user_id === profile.userId ? "user" : "admin";
    const { error } = await supabase.from("qa_messages").insert({
      thread_id: thread.id,
      sender_id: profile.userId,
      sender_role: role,
      body,
    });
    setBusy(false);
    if (error) {
      toast.error(`回覆失敗:${error.message}`);
      return;
    }
    setReply("");
    toast.success("已回覆,提問人將收到通知");
    refresh();
  }

  async function remove() {
    const { error } = await supabase.from("qa_threads").delete().eq("id", thread.id);
    if (error) {
      toast.error(`刪除失敗:${error.message}`);
      return;
    }
    toast.success("提問已永久刪除");
    refresh();
    onClose();
  }

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="flex max-h-[85vh] flex-col sm:max-w-2xl">
        <DialogHeader>
          <DialogTitle>
            {thread.profiles?.display_name ?? "(已刪號)"} 的提問
          </DialogTitle>
        </DialogHeader>
        <div className="min-h-0 flex-1 space-y-3 overflow-y-auto pr-1">
          {isPending && <p className="text-muted-foreground">載入中…</p>}
          {messages?.map((m) => (
            <div
              key={m.id}
              className={
                m.sender_role === "admin"
                  ? "ml-12 rounded-lg bg-primary/10 p-3"
                  : "mr-12 rounded-lg bg-muted p-3"
              }
            >
              <div className="mb-1 flex items-center justify-between text-xs text-muted-foreground">
                <span>{m.sender_role === "admin" ? "管理員" : "提問人"}</span>
                <span>{fmtDateTime(m.created_at)}</span>
              </div>
              <p className="whitespace-pre-wrap text-sm">{m.body}</p>
            </div>
          ))}
        </div>
        <div className="space-y-2 border-t pt-3">
          <Textarea
            value={reply}
            onChange={(e) => setReply(e.target.value)}
            placeholder="輸入回覆…(提問人會收到通知,通知不含內容)"
            maxLength={2000}
            rows={3}
          />
          <div className="flex items-center justify-between">
            <ConfirmButton
              label="刪除提問"
              destructive
              title="永久刪除此提問?"
              description="整個問答(含全部往來訊息)將永久消失,無法恢復。"
              confirmLabel="永久刪除"
              onConfirm={remove}
            />
            <Button onClick={send} disabled={!reply.trim() || busy}>
              {busy ? "發送中…" : "回覆"}
            </Button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}

function ThreadTable({
  rows,
  onOpen,
}: {
  rows: ThreadRow[];
  onOpen: (t: ThreadRow) => void;
}) {
  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>提問人</TableHead>
          <TableHead>首問</TableHead>
          <TableHead>最後訊息</TableHead>
          <TableHead>最後更新</TableHead>
          <TableHead>狀態</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {rows.map((t) => (
          <TableRow
            key={t.id}
            className="cursor-pointer"
            onClick={() => onOpen(t)}
          >
            <TableCell className="whitespace-nowrap">
              {t.profiles?.display_name ?? "(已刪號)"}
            </TableCell>
            <TableCell className="max-w-72 truncate">
              {t.first_message_preview}
            </TableCell>
            <TableCell className="max-w-72 truncate">
              {t.last_message_preview}
            </TableCell>
            <TableCell className="whitespace-nowrap">
              {fmtDateTime(t.last_message_at)}
            </TableCell>
            <TableCell>
              {t.last_sender_role === "user" ? (
                <Badge>待回覆</Badge>
              ) : (
                <Badge variant="outline">已回覆</Badge>
              )}
            </TableCell>
          </TableRow>
        ))}
        {rows.length === 0 && (
          <TableRow>
            <TableCell colSpan={5} className="text-center text-muted-foreground">
              暫無提問
            </TableCell>
          </TableRow>
        )}
      </TableBody>
    </Table>
  );
}

export default function QaPage() {
  const { data: threads, isPending, error } = useThreads();
  const [openThread, setOpenThread] = useState<ThreadRow | null>(null);
  // 弹窗内容跟随列表刷新(删除/回复后线程行可能已变)
  const current = openThread
    ? (threads?.find((t) => t.id === openThread.id) ?? openThread)
    : null;

  if (isPending) return <p className="text-muted-foreground">載入中…</p>;
  if (error) return <p className="text-destructive">載入失敗:{error.message}</p>;

  const pending = threads.filter((t) => t.last_sender_role === "user");

  return (
    <div className="space-y-4">
      <h2 className="text-xl font-semibold">學修問答</h2>
      <Tabs defaultValue="pending">
        <TabsList>
          <TabsTrigger value="pending">待回覆({pending.length})</TabsTrigger>
          <TabsTrigger value="all">全部({threads.length})</TabsTrigger>
        </TabsList>
        <TabsContent value="pending">
          <ThreadTable rows={pending} onOpen={setOpenThread} />
        </TabsContent>
        <TabsContent value="all">
          <ThreadTable rows={threads} onOpen={setOpenThread} />
        </TabsContent>
      </Tabs>
      {current && (
        <ThreadDialog thread={current} onClose={() => setOpenThread(null)} />
      )}
    </div>
  );
}
