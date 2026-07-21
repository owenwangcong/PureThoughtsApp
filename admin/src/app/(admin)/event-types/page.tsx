"use client";

import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { toast } from "sonner";
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
import { supabase } from "@/lib/supabase";

// 与 App 端 event_icons.dart 的 12 个键一一对应
const ICON_OPTIONS: { key: string; label: string }[] = [
  { key: "self_improvement", label: "靜坐" },
  { key: "groups", label: "共修" },
  { key: "record_voice_over", label: "講法" },
  { key: "temple_buddhist", label: "禪七" },
  { key: "event", label: "通用(預設)" },
  { key: "menu_book", label: "經本" },
  { key: "spa", label: "身心" },
  { key: "music_note", label: "音聲" },
  { key: "videocam", label: "影音" },
  { key: "local_florist", label: "花" },
  { key: "wb_sunny", label: "日間" },
  { key: "nightlight", label: "夜間" },
];

type TypeRow = {
  id: string;
  name_hant: string;
  name_hans: string;
  icon: string;
  sort_order: number;
  active: boolean;
};

export default function EventTypesPage() {
  const queryClient = useQueryClient();
  const { data, isPending, error } = useQuery({
    queryKey: ["event-types"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("event_types")
        .select("id, name_hant, name_hans, icon, sort_order, active")
        .order("sort_order");
      if (error) throw error;
      return data as TypeRow[];
    },
  });

  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<TypeRow | null>(null);
  const [nameHant, setNameHant] = useState("");
  const [nameHans, setNameHans] = useState("");
  const [icon, setIcon] = useState("event");
  const [active, setActive] = useState(true);
  const [busy, setBusy] = useState(false);

  function openEditor(row: TypeRow | null) {
    setEditing(row);
    setNameHant(row?.name_hant ?? "");
    setNameHans(row?.name_hans ?? "");
    setIcon(row?.icon ?? "event");
    setActive(row?.active ?? true);
    setOpen(true);
  }

  async function save() {
    if (!nameHant.trim() || !nameHans.trim()) {
      toast.error("繁體與簡體名稱均必填");
      return;
    }
    setBusy(true);
    try {
      // 与 App 端一致:新增 sort_order 固定 50,编辑不动 sort_order
      const { error } = editing
        ? await supabase
            .from("event_types")
            .update({
              name_hant: nameHant.trim(),
              name_hans: nameHans.trim(),
              icon,
              active,
            })
            .eq("id", editing.id)
        : await supabase.from("event_types").insert({
            name_hant: nameHant.trim(),
            name_hans: nameHans.trim(),
            icon,
            active,
            sort_order: 50,
          });
      if (error) throw error;
      toast.success("已儲存");
      setOpen(false);
      void queryClient.invalidateQueries({ queryKey: ["event-types"] });
    } catch (e) {
      toast.error(`儲存失敗:${(e as Error).message}`);
    } finally {
      setBusy(false);
    }
  }

  async function remove() {
    if (!editing) return;
    setBusy(true);
    const { error } = await supabase
      .from("event_types")
      .delete()
      .eq("id", editing.id);
    setBusy(false);
    if (error) {
      toast.error(
        error.code === "23503"
          ? "已有活動使用此類型,不能刪除;請改為停用。"
          : `刪除失敗:${error.message}`,
      );
      return;
    }
    toast.success("已刪除");
    setOpen(false);
    void queryClient.invalidateQueries({ queryKey: ["event-types"] });
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h2 className="text-xl font-semibold">活動類型</h2>
        <Button onClick={() => openEditor(null)}>新增類型</Button>
      </div>

      {isPending && <p className="text-muted-foreground">載入中…</p>}
      {error && <p className="text-destructive">載入失敗:{error.message}</p>}
      {data && (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>繁體名</TableHead>
              <TableHead>簡體名</TableHead>
              <TableHead>圖示</TableHead>
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
                <TableCell className="text-muted-foreground">
                  {ICON_OPTIONS.find((o) => o.key === t.icon)?.label ?? t.icon}
                </TableCell>
                <TableCell>{t.sort_order}</TableCell>
                <TableCell>
                  {t.active ? (
                    <Badge variant="outline">啟用</Badge>
                  ) : (
                    <Badge variant="secondary">停用</Badge>
                  )}
                </TableCell>
                <TableCell>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => openEditor(t)}
                  >
                    編輯
                  </Button>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      )}

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{editing ? "編輯類型" : "新增類型"}</DialogTitle>
          </DialogHeader>
          <div className="space-y-4">
            <div className="space-y-2">
              <Label>繁體名稱</Label>
              <Input
                value={nameHant}
                onChange={(e) => setNameHant(e.target.value)}
              />
            </div>
            <div className="space-y-2">
              <Label>簡體名稱</Label>
              <Input
                value={nameHans}
                onChange={(e) => setNameHans(e.target.value)}
              />
            </div>
            <div className="space-y-2">
              <Label>圖示</Label>
              <Select value={icon} onValueChange={(v) => setIcon(v ?? "event")}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {ICON_OPTIONS.map((o) => (
                    <SelectItem key={o.key} value={o.key}>
                      {o.label}({o.key})
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="flex items-center gap-3">
              <Switch checked={active} onCheckedChange={setActive} />
              <Label>啟用(停用後對成員隱藏,已有活動不受影響)</Label>
            </div>
          </div>
          <DialogFooter className="justify-between">
            {editing && (
              <Button variant="destructive" disabled={busy} onClick={remove}>
                刪除
              </Button>
            )}
            <div className="flex gap-2">
              <Button variant="outline" onClick={() => setOpen(false)}>
                取消
              </Button>
              <Button disabled={busy} onClick={save}>
                {busy ? "儲存中…" : "儲存"}
              </Button>
            </div>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
