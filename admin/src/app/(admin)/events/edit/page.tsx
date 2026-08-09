"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useRef, useState } from "react";
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
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Switch } from "@/components/ui/switch";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Textarea } from "@/components/ui/textarea";
import { fmtDateTime } from "@/lib/format";
import { supabase } from "@/lib/supabase";
import {
  COMMON_TIMEZONES,
  expandWeeklyUtc,
  fmtWallTime,
  isValidTimeZone,
  occurrenceDateInZone,
  utcIsoToZonedLocal,
  zonedLocalToUtcIso,
} from "@/lib/tz";

type EventRecord = {
  id: string;
  title: string;
  event_type_id: string;
  start_at: string;
  timezone: string;
  duration_minutes: number | null;
  recurrence_rule: string | null;
  youtube_url: string | null;
  webex_url: string | null;
  content: string | null;
};

// 提醒檔位(PRD v0.5.21 §5)。DEFAULT_REMINDERS 必須與 DB 觸發器
// default_event_reminders(migration 0025)及 App 端 defaultReminderOffsets 三處一致。
const REMINDER_OPTIONS = [0, 10, 15, 30, 60, 180, 1440, 2880];
const DEFAULT_REMINDERS = [1440, 30, 0];

function reminderLabel(m: number): string {
  if (m <= 0) return "活動開始時";
  if (m === 1440) return "提前一天";
  if (m === 2880) return "提前兩天";
  if (m % 60 === 0) return `提前 ${m / 60} 小時`;
  return `提前 ${m} 分鐘`;
}

/** 把選中的檔位同步到 event_reminders(增刪差集) */
async function syncReminders(eventId: string, wanted: number[]) {
  const { data, error } = await supabase
    .from("event_reminders")
    .select("offset_minutes")
    .eq("event_id", eventId);
  if (error) throw error;
  const have = new Set(data.map((r) => r.offset_minutes));
  const want = new Set(wanted);
  const toAdd = [...want].filter((m) => !have.has(m));
  const toRemove = [...have].filter((m) => !want.has(m));
  if (toAdd.length) {
    const { error: e } = await supabase
      .from("event_reminders")
      .insert(toAdd.map((m) => ({ event_id: eventId, offset_minutes: m })));
    if (e) throw e;
  }
  if (toRemove.length) {
    const { error: e } = await supabase
      .from("event_reminders")
      .delete()
      .eq("event_id", eventId)
      .in("offset_minutes", toRemove);
    if (e) throw e;
  }
}

function useEvent(id: string | null) {
  return useQuery({
    queryKey: ["event", id],
    enabled: !!id,
    queryFn: async () => {
      const { data, error } = await supabase
        .from("events")
        .select(
          "id, title, event_type_id, start_at, timezone, duration_minutes, recurrence_rule, youtube_url, webex_url, content",
        )
        .eq("id", id!)
        .single();
      if (error) throw error;
      return data as EventRecord;
    },
  });
}

// ---------------------------------------------------------------- 基本資料
function EventForm({ id }: { id: string | null }) {
  const { data: event } = useEvent(id);
  const { data: types } = useQuery({
    queryKey: ["event-types"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("event_types")
        .select("id, name_hant, active, sort_order")
        .order("sort_order");
      if (error) throw error;
      return data;
    },
  });
  const { data: defaultTz } = useQuery({
    queryKey: ["default-tz"],
    enabled: !id,
    queryFn: async () => {
      const { data } = await supabase
        .from("app_settings")
        .select("value")
        .eq("key", "default_event_timezone")
        .maybeSingle();
      return data?.value ?? "Asia/Shanghai";
    },
  });

  if (!types || (id && !event) || (!id && defaultTz === undefined)) {
    return <p className="text-muted-foreground">載入中…</p>;
  }
  return (
    <EventFormInner
      key={id ?? "new"}
      id={id}
      event={event ?? null}
      types={types}
      defaultTz={defaultTz ?? "Asia/Shanghai"}
    />
  );
}

function EventFormInner({
  id,
  event,
  types,
  defaultTz,
}: {
  id: string | null;
  event: EventRecord | null;
  types: { id: string; name_hant: string; active: boolean }[];
  defaultTz: string;
}) {
  const router = useRouter();
  const queryClient = useQueryClient();
  const [title, setTitle] = useState(event?.title ?? "");
  const [typeId, setTypeId] = useState(
    event?.event_type_id ?? types.find((t) => t.active)?.id ?? "",
  );
  const [tz, setTz] = useState(event?.timezone ?? defaultTz);
  const [wall, setWall] = useState(
    event ? utcIsoToZonedLocal(event.start_at, event.timezone) : "",
  );
  const [weekly, setWeekly] = useState(
    (event?.recurrence_rule ?? "").toUpperCase().includes("FREQ=WEEKLY"),
  );
  const [duration, setDuration] = useState(event?.duration_minutes ?? 90);
  const [youtube, setYoutube] = useState(event?.youtube_url ?? "");
  const [webex, setWebex] = useState(event?.webex_url ?? "");
  const [content, setContent] = useState(event?.content ?? "");
  // 提醒檔位(PRD v0.5.21 §5;新建預設三檔,與 DB 觸發器 default_event_reminders 一致)
  const { data: savedReminders } = useQuery({
    queryKey: ["event-reminders", id],
    enabled: !!id,
    queryFn: async () => {
      const { data, error } = await supabase
        .from("event_reminders")
        .select("offset_minutes")
        .eq("event_id", id!)
        .eq("enabled", true);
      if (error) throw error;
      return data.map((r) => r.offset_minutes);
    },
  });
  // 派生而非 effect 同步:未編輯過就顯示庫裡的值,編輯過以本地為準
  // (React 19 的 react-hooks/set-state-in-effect 禁止在 effect 裡 setState)
  const [remindersEdit, setRemindersEdit] = useState<number[] | null>(null);
  const reminders = remindersEdit ?? savedReminders ?? DEFAULT_REMINDERS;
  // 本次改動是否通知全體(降噪:小修小補不必驚動全站)
  const [notifyAll, setNotifyAll] = useState(true);

  const save = useMutation({
    mutationFn: async () => {
      if (!title.trim()) throw new Error("標題必填");
      if (!typeId) throw new Error("請選擇活動類型");
      if (!isValidTimeZone(tz)) throw new Error(`時區無效:${tz}`);
      if (!wall) throw new Error("請選擇開始時間");
      if (!Number.isFinite(duration) || duration <= 0)
        throw new Error("時長須為正整數(分鐘)");
      const payload = {
        title: title.trim(),
        event_type_id: typeId,
        start_at: zonedLocalToUtcIso(wall, tz),
        timezone: tz,
        duration_minutes: Math.round(duration),
        recurrence_rule: weekly ? "FREQ=WEEKLY" : null,
        youtube_url: youtube.trim() || null,
        webex_url: webex.trim() || null,
        content: content.trim() || null,
      };
      // v0.5.21:走 admin_save_event RPC 而不是直寫 events —— 觸發器感知不到
      // 「本次是否通知全體」這個 UI 意圖,經 definer RPC 設事務級會話變量傳遞
      // (客戶端無法偽造),見 migration 0026。
      const { data, error } = await supabase.rpc("admin_save_event", {
        p_event: { ...payload, ...(id ? { id } : {}) },
        p_notify: notifyAll,
      });
      if (error) throw error;
      const savedId = data as string;
      await syncReminders(savedId, reminders);
      return savedId;
    },
    onSuccess: (savedId) => {
      toast.success(notifyAll ? "已儲存(會生成全員變更通知)" : "已儲存(本次未通知)");
      void queryClient.invalidateQueries({ queryKey: ["event-reminders", savedId] });
      void queryClient.invalidateQueries({ queryKey: ["events"] });
      void queryClient.invalidateQueries({ queryKey: ["event", savedId] });
      if (!id) router.replace(`/events/edit?id=${savedId}`);
    },
    onError: (e) => toast.error(e.message),
  });

  const tzValid = isValidTimeZone(tz);
  const localHint =
    tzValid && wall
      ? fmtDateTime(zonedLocalToUtcIso(wall, tz))
      : null;

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">基本資料</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
          <div className="space-y-2">
            <Label>標題</Label>
            <Input value={title} onChange={(e) => setTitle(e.target.value)} />
          </div>
          <div className="space-y-2">
            <Label>類型</Label>
            <Select value={typeId} onValueChange={(v) => setTypeId(v ?? "")}>
              <SelectTrigger>
                <SelectValue placeholder="選擇類型" />
              </SelectTrigger>
              <SelectContent>
                {(types ?? [])
                  .filter((t) => t.active || t.id === typeId)
                  .map((t) => (
                    <SelectItem key={t.id} value={t.id}>
                      {t.name_hant}
                      {!t.active && "(停用)"}
                    </SelectItem>
                  ))}
              </SelectContent>
            </Select>
          </div>
          <div className="space-y-2">
            <Label>活動時區(IANA)</Label>
            <Input
              list="tz-options-edit"
              value={tz}
              onChange={(e) => setTz(e.target.value)}
              className={tzValid ? "" : "border-destructive"}
            />
            <datalist id="tz-options-edit">
              {COMMON_TIMEZONES.map((z) => (
                <option key={z} value={z} />
              ))}
            </datalist>
          </div>
          <div className="space-y-2">
            <Label>開始時間(活動當地墻鐘)</Label>
            <Input
              type="datetime-local"
              value={wall}
              onChange={(e) => setWall(e.target.value)}
            />
            {localHint && (
              <p className="text-xs text-muted-foreground">
                你的本地時間:{localHint}
              </p>
            )}
          </div>
          <div className="space-y-2">
            <Label>時長(分鐘)</Label>
            <Input
              type="number"
              min={1}
              value={duration}
              onChange={(e) => setDuration(Number(e.target.value))}
            />
          </div>
          <div className="flex items-center gap-3 pt-6">
            <Switch checked={weekly} onCheckedChange={setWeekly} />
            <Label>每週重複(星期與時刻由開始時間決定)</Label>
          </div>
          <div className="space-y-2 md:col-span-2">
            <Label>提醒</Label>
            <div className="flex flex-wrap gap-2">
              {REMINDER_OPTIONS.map((m) => {
                const on = reminders.includes(m);
                return (
                  <Button
                    key={m}
                    type="button"
                    size="sm"
                    variant={on ? "default" : "outline"}
                    onClick={() =>
                      setRemindersEdit(
                        on ? reminders.filter((x) => x !== m) : [...reminders, m],
                      )
                    }
                  >
                    {reminderLabel(m)}
                  </Button>
                );
              })}
            </div>
            <p className="text-xs text-muted-foreground">
              預設三檔:提前一天(大陸 Android 唯一能看到的一檔)· 提前 30 分鐘 · 活動開始時。
            </p>
          </div>
          <div className="flex items-center gap-3 md:col-span-2">
            <Switch checked={notifyAll} onCheckedChange={setNotifyAll} />
            <Label>本次改動通知所有人</Label>
          </div>
          <div className="space-y-2">
            <Label>YouTube 連結(可空)</Label>
            <Input
              value={youtube}
              onChange={(e) => setYoutube(e.target.value)}
            />
          </div>
          <div className="space-y-2">
            <Label>Webex 連結(可空)</Label>
            <Input value={webex} onChange={(e) => setWebex(e.target.value)} />
          </div>
        </div>
        <div className="space-y-2">
          <Label>說明(可空)</Label>
          <Textarea
            rows={3}
            value={content}
            onChange={(e) => setContent(e.target.value)}
          />
        </div>
        <Button disabled={save.isPending} onClick={() => save.mutate()}>
          {save.isPending ? "儲存中…" : "儲存基本資料"}
        </Button>
      </CardContent>
    </Card>
  );
}

// ---------------------------------------------------------------- 單次場次
type OverrideRow = {
  occurrence_date: string;
  patch: { cancelled?: boolean; start_at?: string };
};

function OccurrencesCard({ id }: { id: string }) {
  const queryClient = useQueryClient();
  const { data: event } = useEvent(id);
  const { data: overrides } = useQuery({
    queryKey: ["event-overrides", id],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("event_overrides")
        .select("occurrence_date, patch")
        .eq("event_id", id);
      if (error) throw error;
      return data as unknown as OverrideRow[];
    },
  });
  const [rescheduling, setRescheduling] = useState<string | null>(null); // occurrence_date
  const [newWall, setNewWall] = useState("");

  if (!event || !overrides) return null;
  const weekly = (event.recurrence_rule ?? "")
    .toUpperCase()
    .includes("FREQ=WEEKLY");
  const occs = weekly
    ? expandWeeklyUtc(event.start_at, event.timezone, 6)
    : [event.start_at];
  const byDate = new Map(overrides.map((o) => [o.occurrence_date, o.patch]));

  function refresh() {
    void queryClient.invalidateQueries({ queryKey: ["event-overrides", id] });
  }

  async function upsertPatch(dateKey: string, patch: OverrideRow["patch"]) {
    const { error } = await supabase
      .from("event_overrides")
      .upsert(
        { event_id: id, occurrence_date: dateKey, patch },
        { onConflict: "event_id,occurrence_date" },
      );
    if (error) {
      toast.error(`操作失敗:${error.message}`);
      return false;
    }
    refresh();
    return true;
  }

  async function clearOverride(dateKey: string) {
    const { error } = await supabase
      .from("event_overrides")
      .delete()
      .eq("event_id", id)
      .eq("occurrence_date", dateKey);
    if (error) {
      toast.error(`操作失敗:${error.message}`);
      return;
    }
    toast.success("已恢復原場次");
    refresh();
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">
          {weekly ? "未來場次(單次取消/改期)" : "場次"}
        </CardTitle>
      </CardHeader>
      <CardContent>
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>原定(活動當地)</TableHead>
              <TableHead>狀態</TableHead>
              <TableHead>操作</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {occs.map((occIso) => {
              const dateKey = occurrenceDateInZone(occIso, event.timezone);
              const patch = byDate.get(dateKey);
              const cancelled = patch?.cancelled === true;
              const moved = patch?.start_at;
              return (
                <TableRow key={dateKey}>
                  <TableCell className="whitespace-nowrap">
                    {fmtWallTime(occIso, event.timezone)}
                  </TableCell>
                  <TableCell>
                    {cancelled && <Badge variant="destructive">已取消</Badge>}
                    {moved && (
                      <Badge variant="secondary">
                        改期至 {fmtWallTime(moved, event.timezone)}
                      </Badge>
                    )}
                    {!cancelled && !moved && <Badge variant="outline">正常</Badge>}
                  </TableCell>
                  <TableCell className="space-x-2 whitespace-nowrap">
                    {(cancelled || moved) && (
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={() => clearOverride(dateKey)}
                      >
                        恢復
                      </Button>
                    )}
                    {!cancelled && (
                      <ConfirmButton
                        label="取消此場"
                        destructive
                        title="取消這一場?"
                        description={`${dateKey} 這一場將顯示為已取消(可恢復)。`}
                        onConfirm={async () => {
                          if (await upsertPatch(dateKey, { cancelled: true }))
                            toast.success("已取消該場次");
                        }}
                      />
                    )}
                    {!cancelled && (
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={() => {
                          setRescheduling(dateKey);
                          setNewWall(
                            utcIsoToZonedLocal(moved ?? occIso, event.timezone),
                          );
                        }}
                      >
                        改期
                      </Button>
                    )}
                  </TableCell>
                </TableRow>
              );
            })}
          </TableBody>
        </Table>

        <Dialog
          open={rescheduling !== null}
          onOpenChange={(o) => !o && setRescheduling(null)}
        >
          <DialogContent>
            <DialogHeader>
              <DialogTitle>改期({rescheduling})</DialogTitle>
            </DialogHeader>
            <div className="space-y-2">
              <Label>新時間(活動當地墻鐘,{event.timezone})</Label>
              <Input
                type="datetime-local"
                value={newWall}
                onChange={(e) => setNewWall(e.target.value)}
              />
            </div>
            <DialogFooter>
              <Button variant="outline" onClick={() => setRescheduling(null)}>
                取消
              </Button>
              <Button
                onClick={async () => {
                  if (!rescheduling || !newWall) return;
                  const ok = await upsertPatch(rescheduling, {
                    start_at: zonedLocalToUtcIso(newWall, event.timezone),
                  });
                  if (ok) {
                    toast.success("已改期");
                    setRescheduling(null);
                  }
                }}
              >
                確認改期
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </CardContent>
    </Card>
  );
}

// ---------------------------------------------------------------- 時間表
type AgendaRow = {
  day: number;
  start: string;
  end: string;
  activity: string;
  linkUrl: string;
  linkLabel: string;
};

function AgendaCard({ id }: { id: string }) {
  const { data: event } = useEvent(id);
  const { data: items, dataUpdatedAt } = useQuery({
    queryKey: ["event-agenda", id],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("event_agenda_items")
        .select("day_index, start_time, end_time, activity, link_url, link_label")
        .eq("event_id", id)
        .order("day_index")
        .order("sort_order")
        .order("start_time");
      if (error) throw error;
      return data;
    },
  });
  if (!event || !items) return null;
  const weekly = (event.recurrence_rule ?? "")
    .toUpperCase()
    .includes("FREQ=WEEKLY");
  // key 随查询更新变化:保存/刷新后整个编辑区用最新库内容重建
  return (
    <AgendaInner key={dataUpdatedAt} id={id} weekly={weekly} items={items} />
  );
}

function AgendaInner({
  id,
  weekly,
  items,
}: {
  id: string;
  weekly: boolean;
  items: {
    day_index: number;
    start_time: string;
    end_time: string | null;
    activity: string;
    link_url: string | null;
    link_label: string | null;
  }[];
}) {
  const queryClient = useQueryClient();
  const [rows, setRows] = useState<AgendaRow[]>(() =>
    items.map((i) => ({
      day: i.day_index,
      start: i.start_time.slice(0, 5),
      end: i.end_time?.slice(0, 5) ?? "",
      activity: i.activity,
      linkUrl: i.link_url ?? "",
      linkLabel: i.link_label ?? "",
    })),
  );
  const [busy, setBusy] = useState(false);

  function update(idx: number, patch: Partial<AgendaRow>) {
    setRows((rs) => rs.map((r, i) => (i === idx ? { ...r, ...patch } : r)));
  }

  async function saveAgenda() {
    for (const r of rows) {
      if (!r.start || !r.activity.trim()) {
        toast.error("每行的開始時間與內容必填");
        return;
      }
      if (r.end && r.end < r.start) {
        toast.error(`結束時間不能早於開始(${r.activity})`);
        return;
      }
    }
    setBusy(true);
    try {
      // 与 App 端一致:先整表删后按序整批插
      const sorted = [...rows].sort(
        (a, b) =>
          a.day - b.day ||
          a.start.localeCompare(b.start) ||
          a.activity.localeCompare(b.activity),
      );
      const { error: de } = await supabase
        .from("event_agenda_items")
        .delete()
        .eq("event_id", id);
      if (de) throw de;
      if (sorted.length > 0) {
        const { error: ie } = await supabase.from("event_agenda_items").insert(
          sorted.map((r, i) => ({
            event_id: id,
            day_index: weekly ? 1 : Math.max(1, Math.round(r.day)),
            start_time: r.start,
            end_time: r.end || null,
            activity: r.activity.trim(),
            link_url: r.linkUrl.trim() || null,
            link_label: r.linkLabel.trim() || null,
            sort_order: i,
          })),
        );
        if (ie) throw ie;
      }
      toast.success("時間表已儲存");
      void queryClient.invalidateQueries({ queryKey: ["event-agenda", id] });
      void queryClient.invalidateQueries({ queryKey: ["events"] });
    } catch (e) {
      toast.error(`儲存失敗:${(e as Error).message}`);
    } finally {
      setBusy(false);
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">時間表(議程)</CardTitle>
      </CardHeader>
      <CardContent className="space-y-3">
        <Table>
          <TableHeader>
            <TableRow>
              {!weekly && <TableHead className="w-20">第幾天</TableHead>}
              <TableHead className="w-28">開始</TableHead>
              <TableHead className="w-28">結束</TableHead>
              <TableHead>內容</TableHead>
              <TableHead>連結(可空)</TableHead>
              <TableHead>連結文字</TableHead>
              <TableHead />
            </TableRow>
          </TableHeader>
          <TableBody>
            {rows.map((r, i) => (
              <TableRow key={i}>
                {!weekly && (
                  <TableCell>
                    <Input
                      type="number"
                      min={1}
                      value={r.day}
                      onChange={(e) => update(i, { day: Number(e.target.value) })}
                    />
                  </TableCell>
                )}
                <TableCell>
                  <Input
                    type="time"
                    value={r.start}
                    onChange={(e) => update(i, { start: e.target.value })}
                  />
                </TableCell>
                <TableCell>
                  <Input
                    type="time"
                    value={r.end}
                    onChange={(e) => update(i, { end: e.target.value })}
                  />
                </TableCell>
                <TableCell>
                  <Input
                    value={r.activity}
                    onChange={(e) => update(i, { activity: e.target.value })}
                  />
                </TableCell>
                <TableCell>
                  <Input
                    value={r.linkUrl}
                    onChange={(e) => update(i, { linkUrl: e.target.value })}
                  />
                </TableCell>
                <TableCell>
                  <Input
                    value={r.linkLabel}
                    onChange={(e) => update(i, { linkLabel: e.target.value })}
                  />
                </TableCell>
                <TableCell>
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => setRows((rs) => rs.filter((_, j) => j !== i))}
                  >
                    移除
                  </Button>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
        <div className="flex gap-2">
          <Button
            variant="outline"
            onClick={() =>
              setRows((rs) => [
                ...rs,
                { day: 1, start: "", end: "", activity: "", linkUrl: "", linkLabel: "" },
              ])
            }
          >
            新增一行
          </Button>
          <Button disabled={busy} onClick={saveAgenda}>
            {busy ? "儲存中…" : "儲存時間表"}
          </Button>
        </div>
        {weekly && (
          <p className="text-xs text-muted-foreground">
            循環活動的時間表按單天維護(day 恒為 1)。
          </p>
        )}
      </CardContent>
    </Card>
  );
}

// ---------------------------------------------------------------- 相關資料(PDF)
function fmtBytes(n: number | null): string {
  if (!n) return "—";
  if (n < 1024 * 1024) return `${Math.round(n / 1024)} KB`;
  return `${(n / 1024 / 1024).toFixed(1)} MB`;
}

function AttachmentsCard({ id }: { id: string }) {
  const queryClient = useQueryClient();
  const { data: items } = useQuery({
    queryKey: ["event-attachments", id],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("event_attachments")
        .select("id, title, storage_path, size_bytes, sort_order")
        .eq("event_id", id)
        .order("sort_order");
      if (error) throw error;
      return data;
    },
  });
  const [file, setFile] = useState<File | null>(null);
  const [title, setTitle] = useState("");
  const [busy, setBusy] = useState(false);
  const fileInput = useRef<HTMLInputElement>(null);

  function refresh() {
    void queryClient.invalidateQueries({ queryKey: ["event-attachments", id] });
    void queryClient.invalidateQueries({ queryKey: ["events"] });
  }

  async function upload() {
    if (!file || !items) return;
    if (!title.trim()) {
      toast.error("請填顯示名稱");
      return;
    }
    setBusy(true);
    try {
      // 与 App 端一致的路径形态:<eventId>/<时间戳>.pdf
      const path = `${id}/${Date.now()}000.pdf`;
      const { error: ue } = await supabase.storage
        .from("event-files")
        .upload(path, file, { contentType: "application/pdf" });
      if (ue) throw ue;
      const { error: ie } = await supabase.from("event_attachments").insert({
        event_id: id,
        title: title.trim(),
        storage_path: path,
        size_bytes: file.size,
        content_type: "application/pdf",
        sort_order: items.length,
      });
      if (ie) throw ie;
      toast.success("已上傳");
      setFile(null);
      setTitle("");
      if (fileInput.current) fileInput.current.value = "";
      refresh();
    } catch (e) {
      toast.error(`上傳失敗:${(e as Error).message}`);
    } finally {
      setBusy(false);
    }
  }

  async function remove(attId: string, storagePath: string) {
    // 先删对象再删行(与 App 端一致)
    const { error: se } = await supabase.storage
      .from("event-files")
      .remove([storagePath]);
    if (se) {
      toast.error(`刪除檔案失敗:${se.message}`);
      return;
    }
    const { error } = await supabase
      .from("event_attachments")
      .delete()
      .eq("id", attId);
    if (error) {
      toast.error(`刪除失敗:${error.message}`);
      return;
    }
    toast.success("已刪除");
    refresh();
  }

  if (!items) return null;

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">相關資料(PDF,上限 20 MB)</CardTitle>
      </CardHeader>
      <CardContent className="space-y-3">
        {items.map((a) => (
          <div key={a.id} className="flex items-center gap-3">
            <span className="min-w-0 flex-1 truncate">{a.title}</span>
            <span className="text-xs text-muted-foreground">
              {fmtBytes(a.size_bytes)}
            </span>
            <Button
              variant="outline"
              size="sm"
              render={
                <a
                  href={
                    supabase.storage
                      .from("event-files")
                      .getPublicUrl(a.storage_path).data.publicUrl
                  }
                  target="_blank"
                  rel="noreferrer"
                />
              }
            >
              開啟
            </Button>
            <ConfirmButton
              label="刪除"
              destructive
              title={`刪除「${a.title}」?`}
              onConfirm={() => remove(a.id, a.storage_path)}
            />
          </div>
        ))}
        {items.length === 0 && (
          <p className="text-sm text-muted-foreground">尚無附件</p>
        )}
        <div className="flex items-center gap-3 border-t pt-3">
          <Input
            ref={fileInput}
            type="file"
            accept=".pdf,application/pdf"
            className="max-w-64"
            onChange={(e) => {
              const f = e.target.files?.[0] ?? null;
              if (f && f.type !== "application/pdf") {
                toast.error("僅支援 PDF");
                e.target.value = "";
                return;
              }
              setFile(f);
              if (f && !title) setTitle(f.name.replace(/\.pdf$/i, ""));
            }}
          />
          <Input
            className="max-w-64"
            placeholder="顯示名稱"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
          />
          <Button disabled={!file || busy} onClick={upload}>
            {busy ? "上傳中…" : "上傳"}
          </Button>
        </div>
      </CardContent>
    </Card>
  );
}

// ---------------------------------------------------------------- 頁面
function EditorRoute() {
  const id = useSearchParams().get("id");
  return (
    <div className="space-y-6">
      <h2 className="text-xl font-semibold">{id ? "編輯活動" : "新增活動"}</h2>
      <EventForm id={id} />
      {id ? (
        <>
          <OccurrencesCard id={id} />
          <AgendaCard id={id} />
          <AttachmentsCard id={id} />
        </>
      ) : (
        <p className="text-sm text-muted-foreground">
          儲存基本資料後,可繼續管理單次場次、時間表與相關資料。
        </p>
      )}
    </div>
  );
}

export default function EventEditPage() {
  return (
    <Suspense fallback={<p className="text-muted-foreground">載入中…</p>}>
      <EditorRoute />
    </Suspense>
  );
}
