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
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
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

type GroupRow = {
  id: string;
  name: string;
  created_at: string;
  deleted_at: string | null;
  owner_id: string | null;
  owner: { display_name: string } | null;
};

export default function GroupsPage() {
  const queryClient = useQueryClient();
  const { data: groups, isPending, error } = useQuery({
    queryKey: ["admin-groups"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("groups")
        .select(
          "id, name, created_at, deleted_at, owner_id, owner:profiles!groups_owner_id_fkey(display_name)",
        )
        .order("created_at", { ascending: false })
        .limit(100);
      if (error) throw error;
      return data as unknown as GroupRow[];
    },
  });

  const { data: memberCounts } = useQuery({
    queryKey: ["admin-group-members-count"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("group_members")
        .select("group_id")
        .eq("status", "approved")
        .limit(10000);
      if (error) throw error;
      const m: Record<string, number> = {};
      for (const r of data) m[r.group_id] = (m[r.group_id] ?? 0) + 1;
      return m;
    },
  });

  const { data: totals } = useQuery({
    queryKey: ["admin-group-totals"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("group_practice_totals")
        .select("group_id, unit, total")
        .limit(10000);
      if (error) throw error;
      const m: Record<string, Record<string, number>> = {};
      for (const r of data) {
        const gid = r.group_id as string;
        const unit = r.unit as string;
        m[gid] = m[gid] ?? {};
        m[gid][unit] = (m[gid][unit] ?? 0) + Number(r.total);
      }
      return m;
    },
  });

  const [transferGroup, setTransferGroup] = useState<GroupRow | null>(null);
  const [newOwner, setNewOwner] = useState("");
  const [transferBusy, setTransferBusy] = useState(false);

  const { data: candidates } = useQuery({
    queryKey: ["admin-group-candidates", transferGroup?.id],
    enabled: !!transferGroup,
    queryFn: async () => {
      const { data, error } = await supabase
        .from("group_members")
        .select("user_id, role, member:profiles!group_members_user_id_fkey(display_name)")
        .eq("group_id", transferGroup!.id)
        .eq("status", "approved");
      if (error) throw error;
      return data as unknown as {
        user_id: string;
        role: string;
        member: { display_name: string } | null;
      }[];
    },
  });

  function refresh() {
    void queryClient.invalidateQueries({ queryKey: ["admin-groups"] });
    void queryClient.invalidateQueries({ queryKey: ["admin-group-members-count"] });
  }

  async function dissolve(g: GroupRow) {
    const { error } = await supabase.rpc("dissolve_group", { p_group_id: g.id });
    if (error) {
      toast.error(`解散失敗:${error.message}`);
      return;
    }
    toast.success(`「${g.name}」已解散`);
    refresh();
  }

  async function transfer() {
    if (!transferGroup || !newOwner) return;
    setTransferBusy(true);
    const { error } = await supabase.rpc("transfer_group_ownership", {
      p_group_id: transferGroup.id,
      p_new_owner: newOwner,
    });
    setTransferBusy(false);
    if (error) {
      toast.error(`轉讓失敗:${error.message}`);
      return;
    }
    toast.success("已轉讓群主");
    setTransferGroup(null);
    setNewOwner("");
    refresh();
  }

  function totalsText(gid: string): string {
    const t = totals?.[gid];
    if (!t) return "—";
    const parts = Object.entries(t).map(
      ([unit, sum]) => `${sum.toLocaleString()}${UNIT_LABEL[unit] ?? unit}`,
    );
    return parts.length ? parts.join(" · ") : "—";
  }

  return (
    <div className="space-y-4">
      <h2 className="text-xl font-semibold">群組總覽</h2>
      {isPending && <p className="text-muted-foreground">載入中…</p>}
      {error && <p className="text-destructive">載入失敗:{error.message}</p>}
      {groups && (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>群名</TableHead>
              <TableHead>群主</TableHead>
              <TableHead>成員</TableHead>
              <TableHead>群總量</TableHead>
              <TableHead>建立</TableHead>
              <TableHead>狀態</TableHead>
              <TableHead>操作</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {groups.map((g) => (
              <TableRow key={g.id} className={g.deleted_at ? "opacity-60" : ""}>
                <TableCell className="max-w-44 truncate font-medium">
                  {g.name}
                </TableCell>
                <TableCell>{g.owner?.display_name ?? "(已刪號)"}</TableCell>
                <TableCell>{memberCounts?.[g.id] ?? "…"}</TableCell>
                <TableCell className="max-w-56 truncate">
                  {totalsText(g.id)}
                </TableCell>
                <TableCell>{fmtDate(g.created_at)}</TableCell>
                <TableCell>
                  {g.deleted_at ? (
                    <Badge variant="secondary">已解散</Badge>
                  ) : (
                    <Badge variant="outline">活躍</Badge>
                  )}
                </TableCell>
                <TableCell className="space-x-2 whitespace-nowrap">
                  {!g.deleted_at && (
                    <>
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={() => {
                          setTransferGroup(g);
                          setNewOwner("");
                        }}
                      >
                        轉讓群主
                      </Button>
                      <ConfirmButton
                        label="解散"
                        destructive
                        title={`解散「${g.name}」?`}
                        description="軟刪除:群對成員不可見,歷史報數保留;不可在後台恢復。"
                        confirmLabel="確認解散"
                        onConfirm={() => dissolve(g)}
                      />
                    </>
                  )}
                </TableCell>
              </TableRow>
            ))}
            {groups.length === 0 && (
              <TableRow>
                <TableCell
                  colSpan={7}
                  className="text-center text-muted-foreground"
                >
                  尚無群組
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      )}

      <Dialog
        open={transferGroup !== null}
        onOpenChange={(o) => !o && setTransferGroup(null)}
      >
        <DialogContent>
          <DialogHeader>
            <DialogTitle>轉讓群主:{transferGroup?.name}</DialogTitle>
          </DialogHeader>
          <div className="space-y-2">
            <Label>新群主(現有成員)</Label>
            <Select value={newOwner} onValueChange={(v) => setNewOwner(v ?? "")}>
              <SelectTrigger>
                <SelectValue placeholder="選擇成員" />
              </SelectTrigger>
              <SelectContent>
                {(candidates ?? [])
                  .filter((c) => c.user_id !== transferGroup?.owner_id)
                  .map((c) => (
                    <SelectItem key={c.user_id} value={c.user_id}>
                      {c.member?.display_name ?? c.user_id}
                    </SelectItem>
                  ))}
              </SelectContent>
            </Select>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setTransferGroup(null)}>
              取消
            </Button>
            <Button disabled={!newOwner || transferBusy} onClick={transfer}>
              {transferBusy ? "轉讓中…" : "確認轉讓"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
