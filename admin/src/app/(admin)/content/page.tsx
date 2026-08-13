"use client";

import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { toast } from "sonner";
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
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { fmtDateTime } from "@/lib/format";
import { supabase } from "@/lib/supabase";

// ---------------------------------------------------------------- 音訊/媒體
type MediaRow = {
  id: string;
  title_hant: string;
  title_hans: string;
  kind: "audio" | "video";
  source: "youtube" | "https";
  url: string;
  category: string | null;
  sort_order: number;
  active: boolean;
};

function MediaTab() {
  const queryClient = useQueryClient();
  const { data, isPending, error } = useQuery({
    queryKey: ["media-items"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("media_items")
        .select("id, title_hant, title_hans, kind, source, url, category, sort_order, active")
        .order("sort_order");
      if (error) throw error;
      return data as MediaRow[];
    },
  });

  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<MediaRow | null>(null);
  const [f, setF] = useState({
    title_hant: "",
    title_hans: "",
    kind: "audio" as MediaRow["kind"],
    source: "https" as MediaRow["source"],
    url: "",
    category: "",
    sort_order: 50,
    active: true,
  });
  const [busy, setBusy] = useState(false);

  function openEditor(row: MediaRow | null) {
    setEditing(row);
    setF({
      title_hant: row?.title_hant ?? "",
      title_hans: row?.title_hans ?? "",
      kind: row?.kind ?? "audio",
      source: row?.source ?? "https",
      url: row?.url ?? "",
      category: row?.category ?? "",
      sort_order: row?.sort_order ?? 50,
      active: row?.active ?? true,
    });
    setOpen(true);
  }

  function refresh() {
    void queryClient.invalidateQueries({ queryKey: ["media-items"] });
  }

  async function save() {
    if (!f.title_hant.trim() || !f.title_hans.trim() || !f.url.trim()) {
      toast.error("簡繁標題與 URL 必填");
      return;
    }
    setBusy(true);
    const payload = {
      title_hant: f.title_hant.trim(),
      title_hans: f.title_hans.trim(),
      kind: f.kind,
      source: f.source,
      url: f.url.trim(),
      category: f.category.trim() || null,
      sort_order: f.sort_order,
      active: f.active,
    };
    const { error } = editing
      ? await supabase.from("media_items").update(payload).eq("id", editing.id)
      : await supabase.from("media_items").insert(payload);
    setBusy(false);
    if (error) {
      toast.error(`儲存失敗:${error.message}`);
      return;
    }
    toast.success("已儲存");
    setOpen(false);
    refresh();
  }

  async function remove() {
    if (!editing) return;
    const { error } = await supabase.from("media_items").delete().eq("id", editing.id);
    if (error) {
      toast.error(`刪除失敗:${error.message}`);
      return;
    }
    toast.success("已刪除");
    setOpen(false);
    refresh();
  }

  return (
    <div className="space-y-3">
      <div className="flex justify-end">
        <Button onClick={() => openEditor(null)}>新增條目</Button>
      </div>
      {isPending && <p className="text-muted-foreground">載入中…</p>}
      {error && <p className="text-destructive">載入失敗:{error.message}</p>}
      {data && (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>標題(繁)</TableHead>
              <TableHead>類別</TableHead>
              <TableHead>形式</TableHead>
              <TableHead>來源</TableHead>
              <TableHead>排序</TableHead>
              <TableHead>狀態</TableHead>
              <TableHead />
            </TableRow>
          </TableHeader>
          <TableBody>
            {data.map((m) => (
              <TableRow key={m.id} className={m.active ? "" : "opacity-60"}>
                <TableCell className="max-w-52 truncate font-medium">{m.title_hant}</TableCell>
                <TableCell>{m.category ?? "—"}</TableCell>
                <TableCell>{m.kind === "audio" ? "音訊" : "影片"}</TableCell>
                <TableCell>{m.source}</TableCell>
                <TableCell>{m.sort_order}</TableCell>
                <TableCell>
                  {m.active ? <Badge variant="outline">上架</Badge> : <Badge variant="secondary">下架</Badge>}
                </TableCell>
                <TableCell>
                  <Button variant="outline" size="sm" onClick={() => openEditor(m)}>編輯</Button>
                </TableCell>
              </TableRow>
            ))}
            {data.length === 0 && (
              <TableRow>
                <TableCell colSpan={7} className="text-center text-muted-foreground">
                  尚無媒體條目(P4 念誦音訊上架入口,E11 就緒後使用)
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      )}

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className="max-w-lg">
          <DialogHeader>
            <DialogTitle>{editing ? "編輯媒體" : "新增媒體"}</DialogTitle>
          </DialogHeader>
          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1">
              <Label>標題(繁)</Label>
              <Input value={f.title_hant} onChange={(e) => setF({ ...f, title_hant: e.target.value })} />
            </div>
            <div className="space-y-1">
              <Label>標題(簡)</Label>
              <Input value={f.title_hans} onChange={(e) => setF({ ...f, title_hans: e.target.value })} />
            </div>
            <div className="space-y-1">
              <Label>形式</Label>
              <Select value={f.kind} onValueChange={(v) => setF({ ...f, kind: (v ?? "audio") as MediaRow["kind"] })}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  <SelectItem value="audio">音訊</SelectItem>
                  <SelectItem value="video">影片</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-1">
              <Label>來源</Label>
              <Select value={f.source} onValueChange={(v) => setF({ ...f, source: (v ?? "https") as MediaRow["source"] })}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  <SelectItem value="https">HTTPS 下載</SelectItem>
                  <SelectItem value="youtube">YouTube</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="col-span-2 space-y-1">
              <Label>URL</Label>
              <Input value={f.url} onChange={(e) => setF({ ...f, url: e.target.value })} />
            </div>
            <div className="space-y-1">
              <Label>類別(如 經/咒/共修)</Label>
              <Input value={f.category} onChange={(e) => setF({ ...f, category: e.target.value })} />
            </div>
            <div className="space-y-1">
              <Label>排序</Label>
              <Input type="number" value={f.sort_order} onChange={(e) => setF({ ...f, sort_order: Number(e.target.value) })} />
            </div>
            <div className="col-span-2 flex items-center gap-3">
              <Switch checked={f.active} onCheckedChange={(v) => setF({ ...f, active: v })} />
              <Label>上架(App 回看/媒體列表可見)</Label>
            </div>
          </div>
          <DialogFooter className="justify-between">
            {editing && (
              <ConfirmButton label="刪除" destructive title={`刪除「${editing.title_hant}」?`} onConfirm={remove} />
            )}
            <div className="flex gap-2">
              <Button variant="outline" onClick={() => setOpen(false)}>取消</Button>
              <Button disabled={busy} onClick={save}>{busy ? "儲存中…" : "儲存"}</Button>
            </div>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}

// ---------------------------------------------------------------- 功課主清單
const CATEGORY_LABEL: Record<string, string> = {
  sutra: "經",
  mantra: "咒",
  repentance: "懺",
  buddha_name: "佛號",
  meditation: "靜坐",
  other: "其它",
};
const UNIT_LABEL: Record<string, string> = {
  volume: "部",
  recitation: "遍",
  count: "次",
  minute: "分鐘",
};

type PTypeRow = {
  id: string;
  name_hant: string;
  name_hans: string;
  category: string;
  unit: string;
  sort_order: number;
  active: boolean;
};

function PracticeTypesTab() {
  const queryClient = useQueryClient();
  const { data, isPending, error } = useQuery({
    queryKey: ["global-practice-types"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("practice_types")
        .select("id, name_hant, name_hans, category, unit, sort_order, active")
        .is("group_id", null)
        .order("sort_order");
      if (error) throw error;
      return data as PTypeRow[];
    },
  });

  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<PTypeRow | null>(null);
  const [f, setF] = useState({
    name_hant: "",
    name_hans: "",
    category: "sutra",
    unit: "volume",
    sort_order: 50,
    active: true,
  });
  const [busy, setBusy] = useState(false);

  function openEditor(row: PTypeRow | null) {
    setEditing(row);
    setF({
      name_hant: row?.name_hant ?? "",
      name_hans: row?.name_hans ?? "",
      category: row?.category ?? "sutra",
      unit: row?.unit ?? "volume",
      sort_order: row?.sort_order ?? 50,
      active: row?.active ?? true,
    });
    setOpen(true);
  }

  async function save() {
    if (!f.name_hant.trim() || !f.name_hans.trim()) {
      toast.error("簡繁名稱必填(功課項須具體到經名,PRD v0.5.2)");
      return;
    }
    setBusy(true);
    const payload = {
      name_hant: f.name_hant.trim(),
      name_hans: f.name_hans.trim(),
      category: f.category as PTypeRow["category"] & ("sutra" | "mantra" | "repentance" | "buddha_name" | "meditation" | "other"),
      unit: f.unit as "volume" | "recitation" | "count" | "minute",
      sort_order: f.sort_order,
      active: f.active,
    };
    const { error } = editing
      ? await supabase.from("practice_types").update(payload).eq("id", editing.id)
      : await supabase.from("practice_types").insert(payload);
    setBusy(false);
    if (error) {
      toast.error(`儲存失敗:${error.message}`);
      return;
    }
    toast.success("已儲存");
    setOpen(false);
    void queryClient.invalidateQueries({ queryKey: ["global-practice-types"] });
  }

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <p className="text-sm text-muted-foreground">
          全局主清單(全體用戶可見);已被報數引用的項不可刪,只可停用。單位在有報數後不建議改動(歷史記錄快照原單位)。
        </p>
        <Button onClick={() => openEditor(null)}>新增功課項</Button>
      </div>
      {isPending && <p className="text-muted-foreground">載入中…</p>}
      {error && <p className="text-destructive">載入失敗:{error.message}</p>}
      {data && (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>名稱(繁)</TableHead>
              <TableHead>名稱(簡)</TableHead>
              <TableHead>分類</TableHead>
              <TableHead>單位</TableHead>
              <TableHead>排序</TableHead>
              <TableHead>狀態</TableHead>
              <TableHead />
            </TableRow>
          </TableHeader>
          <TableBody>
            {data.map((t) => (
              <TableRow key={t.id} className={t.active ? "" : "opacity-60"}>
                <TableCell className="font-medium">{t.name_hant}</TableCell>
                <TableCell>{t.name_hans}</TableCell>
                <TableCell>{CATEGORY_LABEL[t.category] ?? t.category}</TableCell>
                <TableCell>{UNIT_LABEL[t.unit] ?? t.unit}</TableCell>
                <TableCell>{t.sort_order}</TableCell>
                <TableCell>
                  {t.active ? <Badge variant="outline">啟用</Badge> : <Badge variant="secondary">停用</Badge>}
                </TableCell>
                <TableCell>
                  <Button variant="outline" size="sm" onClick={() => openEditor(t)}>編輯</Button>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      )}

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{editing ? "編輯功課項" : "新增功課項"}</DialogTitle>
          </DialogHeader>
          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1">
              <Label>名稱(繁,具體到經名)</Label>
              <Input value={f.name_hant} onChange={(e) => setF({ ...f, name_hant: e.target.value })} />
            </div>
            <div className="space-y-1">
              <Label>名稱(簡)</Label>
              <Input value={f.name_hans} onChange={(e) => setF({ ...f, name_hans: e.target.value })} />
            </div>
            <div className="space-y-1">
              <Label>分類</Label>
              <Select value={f.category} onValueChange={(v) => setF({ ...f, category: v ?? "sutra" })}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {Object.entries(CATEGORY_LABEL).map(([k, l]) => (
                    <SelectItem key={k} value={k}>{l}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-1">
              <Label>單位</Label>
              <Select value={f.unit} onValueChange={(v) => setF({ ...f, unit: v ?? "volume" })}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {Object.entries(UNIT_LABEL).map(([k, l]) => (
                    <SelectItem key={k} value={k}>{l}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-1">
              <Label>排序</Label>
              <Input type="number" value={f.sort_order} onChange={(e) => setF({ ...f, sort_order: Number(e.target.value) })} />
            </div>
            <div className="flex items-center gap-3 pt-5">
              <Switch checked={f.active} onCheckedChange={(v) => setF({ ...f, active: v })} />
              <Label>啟用</Label>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setOpen(false)}>取消</Button>
            <Button disabled={busy} onClick={save}>{busy ? "儲存中…" : "儲存"}</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}

// ---------------------------------------------------------------- 經本
type ScriptureRow = { id: string; title: string; web_url: string; sort_order: number };

function ScripturesTab() {
  const queryClient = useQueryClient();
  const { data, isPending, error } = useQuery({
    queryKey: ["scriptures"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("scriptures")
        .select("id, title, web_url, sort_order")
        .order("sort_order");
      if (error) throw error;
      return data as ScriptureRow[];
    },
  });
  const [title, setTitle] = useState("");
  const [url, setUrl] = useState("");

  function refresh() {
    void queryClient.invalidateQueries({ queryKey: ["scriptures"] });
  }

  async function add() {
    const { error } = await supabase
      .from("scriptures")
      .insert({ title: title.trim(), web_url: url.trim(), sort_order: (data?.length ?? 0) * 10 });
    if (error) {
      toast.error(`新增失敗:${error.message}`);
      return;
    }
    toast.success("已新增");
    setTitle("");
    setUrl("");
    refresh();
  }

  async function remove(id: string) {
    const { error } = await supabase.from("scriptures").delete().eq("id", id);
    if (error) {
      toast.error(`刪除失敗:${error.message}`);
      return;
    }
    toast.success("已刪除");
    refresh();
  }

  return (
    <div className="space-y-3">
      <p className="text-sm text-muted-foreground">
        App 目前「在線經本」直達乾隆大藏經(P3.2 用戶定案,無列表層);此表為將來多條目時的儲備,新增條目暫不影響 App。
      </p>
      {isPending && <p className="text-muted-foreground">載入中…</p>}
      {error && <p className="text-destructive">載入失敗:{error.message}</p>}
      {data && (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>標題</TableHead>
              <TableHead>網址</TableHead>
              <TableHead>排序</TableHead>
              <TableHead />
            </TableRow>
          </TableHeader>
          <TableBody>
            {data.map((s) => (
              <TableRow key={s.id}>
                <TableCell className="font-medium">{s.title}</TableCell>
                <TableCell className="max-w-72 truncate text-muted-foreground">{s.web_url}</TableCell>
                <TableCell>{s.sort_order}</TableCell>
                <TableCell>
                  <ConfirmButton label="刪除" destructive title={`刪除「${s.title}」?`} onConfirm={() => remove(s.id)} />
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      )}
      <div className="flex gap-2 border-t pt-3">
        <Input className="w-56" placeholder="標題" value={title} onChange={(e) => setTitle(e.target.value)} />
        <Input className="flex-1" placeholder="https://…" value={url} onChange={(e) => setUrl(e.target.value)} />
        <Button disabled={!title.trim() || !url.trim()} onClick={add}>新增</Button>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------- 直播場次(只讀)
function LiveStreamsTab() {
  const { data, isPending, error } = useQuery({
    queryKey: ["live-streams"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("live_streams")
        .select("id, platform, title, video_id, url, started_at, ended_at")
        .order("started_at", { ascending: false })
        .limit(20);
      if (error) throw error;
      return data;
    },
  });

  return (
    <div className="space-y-3">
      <p className="text-sm text-muted-foreground">
        live-probe 探測到的直播場次記錄(只讀;固定頻道常量在 `app/lib/core/channels.dart` 與 Edge Function 內,改頻道須改代碼)。
      </p>
      {isPending && <p className="text-muted-foreground">載入中…</p>}
      {error && <p className="text-destructive">載入失敗:{error.message}</p>}
      {data && (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>平台</TableHead>
              <TableHead>標題</TableHead>
              <TableHead>video_id</TableHead>
              <TableHead>開播</TableHead>
              <TableHead>結束</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {data.map((s) => (
              <TableRow key={s.id}>
                <TableCell>{s.platform}</TableCell>
                <TableCell className="max-w-52 truncate">{s.title ?? "—"}</TableCell>
                <TableCell className="text-muted-foreground">{s.video_id ?? "—"}</TableCell>
                <TableCell>{fmtDateTime(s.started_at)}</TableCell>
                <TableCell>
                  {s.ended_at ? fmtDateTime(s.ended_at) : <Badge>進行中</Badge>}
                </TableCell>
              </TableRow>
            ))}
            {data.length === 0 && (
              <TableRow>
                <TableCell colSpan={5} className="text-center text-muted-foreground">
                  尚無直播記錄
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      )}
    </div>
  );
}


/**
 * 自訂功課治理(PRD v0.6.0 §4.1 / 設計 Q8)。
 *
 * 自訂項只有創建者自己能選用,但名稱對所有人可讀(否則他用它報的記錄在共修流水
 * 裡會是無名條目)。管理員在這裡看得到全部,可停用、改名、或「提升為主清單」
 * (清掉 group_id / is_custom / created_by 三列即轉正,全體可選)。
 */
function CustomTypesTab() {
  const queryClient = useQueryClient();
  const { data, isPending, error } = useQuery({
    queryKey: ["custom-practice-types"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("practice_types")
        .select(
          "id, name_hant, name_hans, category, unit, active, created_at, creator:profiles!practice_types_created_by_fkey(display_name)",
        )
        .eq("is_custom", true)
        .order("created_at", { ascending: false })
        .limit(500);
      if (error) throw error;
      return data as unknown as (PTypeRow & {
        created_at: string;
        creator: { display_name: string } | null;
      })[];
    },
  });

  function refresh() {
    void queryClient.invalidateQueries({ queryKey: ["custom-practice-types"] });
    void queryClient.invalidateQueries({ queryKey: ["global-practice-types"] });
  }

  async function toggle(id: string, active: boolean) {
    const { error } = await supabase
      .from("practice_types")
      .update({ active })
      .eq("id", id);
    if (error) {
      toast.error(`操作失敗:${error.message}`);
      return;
    }
    toast.success(active ? "已啟用" : "已停用");
    refresh();
  }

  async function promote(id: string) {
    // 三列同時清空:表上有 check (is_custom = (group_id is not null))
    const { error } = await supabase
      .from("practice_types")
      .update({ group_id: null, is_custom: false, created_by: null })
      .eq("id", id);
    if (error) {
      toast.error(`轉正失敗:${error.message}`);
      return;
    }
    toast.success("已提升為主清單項(全體可選)");
    refresh();
  }

  return (
    <div className="space-y-3">
      <p className="text-sm text-muted-foreground">
        用戶自己加的功課項(v0.6.0 起<strong>僅創建者可選用</strong>,不進公共清單)。
        名稱仍對所有人可讀,以便渲染共修報數記錄。同一功課若被多人各建一份,
        總量會按項分行;需要歸口時,把其中一項「提升為主清單」再停用其餘。
      </p>
      {isPending && <p className="text-muted-foreground">載入中…</p>}
      {error && <p className="text-destructive">載入失敗:{error.message}</p>}
      {data && (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>名稱(繁)</TableHead>
              <TableHead>名稱(簡)</TableHead>
              <TableHead>分類</TableHead>
              <TableHead>單位</TableHead>
              <TableHead>創建者</TableHead>
              <TableHead>狀態</TableHead>
              <TableHead />
            </TableRow>
          </TableHeader>
          <TableBody>
            {data.map((t) => (
              <TableRow key={t.id} className={t.active ? "" : "opacity-60"}>
                <TableCell className="font-medium">{t.name_hant}</TableCell>
                <TableCell>{t.name_hans}</TableCell>
                <TableCell>{CATEGORY_LABEL[t.category] ?? t.category}</TableCell>
                <TableCell>{UNIT_LABEL[t.unit] ?? t.unit}</TableCell>
                <TableCell>{t.creator?.display_name ?? "(已刪號)"}</TableCell>
                <TableCell>
                  {t.active ? (
                    <Badge variant="outline">啟用</Badge>
                  ) : (
                    <Badge variant="secondary">停用</Badge>
                  )}
                </TableCell>
                <TableCell className="space-x-2 whitespace-nowrap">
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => toggle(t.id, !t.active)}
                  >
                    {t.active ? "停用" : "啟用"}
                  </Button>
                  <ConfirmButton
                    label="提升為主清單"
                    title={`把「${t.name_hant}」提升為主清單項?`}
                    description="轉正後全體同修都能選用,且不再屬於任何人;已產生的報數不受影響。"
                    confirmLabel="確認提升"
                    onConfirm={() => promote(t.id)}
                  />
                </TableCell>
              </TableRow>
            ))}
            {data.length === 0 && (
              <TableRow>
                <TableCell colSpan={7} className="text-center text-muted-foreground">
                  尚無自訂功課
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      )}
    </div>
  );
}

export default function ContentPage() {
  return (
    <div className="space-y-4">
      <h2 className="text-xl font-semibold">內容上架</h2>
      <Tabs defaultValue="media">
        <TabsList>
          <TabsTrigger value="media">音訊 / 媒體</TabsTrigger>
          <TabsTrigger value="ptypes">功課主清單</TabsTrigger>
          <TabsTrigger value="custom">自訂功課</TabsTrigger>
          <TabsTrigger value="scriptures">經本</TabsTrigger>
          <TabsTrigger value="live">直播場次</TabsTrigger>
        </TabsList>
        <TabsContent value="media"><MediaTab /></TabsContent>
        <TabsContent value="ptypes"><PracticeTypesTab /></TabsContent>
        <TabsContent value="custom"><CustomTypesTab /></TabsContent>
        <TabsContent value="scriptures"><ScripturesTab /></TabsContent>
        <TabsContent value="live"><LiveStreamsTab /></TabsContent>
      </Tabs>
    </div>
  );
}
