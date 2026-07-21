"use client";

import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { toast } from "sonner";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Input } from "@/components/ui/input";
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
import { COMMON_TIMEZONES } from "@/lib/tz";

type SettingRow = { key: string; value: string; updated_at: string };
type AlmanacRow = {
  solar_date: string;
  lunar_month: number;
  lunar_day: number;
  is_leap_month: boolean;
  names_hant: string[];
  is_zhai_ten: boolean;
  has_major: boolean;
};

function SettingsCard() {
  const queryClient = useQueryClient();
  const { data, isPending, error } = useQuery({
    queryKey: ["app-settings"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("app_settings")
        .select("key, value, updated_at")
        .order("key");
      if (error) throw error;
      return data as SettingRow[];
    },
  });
  const [drafts, setDrafts] = useState<Record<string, string>>({});
  const [newKey, setNewKey] = useState("");
  const [newValue, setNewValue] = useState("");

  async function save(key: string, value: string) {
    if (!value.trim()) {
      toast.error("值不能為空");
      return;
    }
    const { error } = await supabase.from("app_settings").upsert({
      key,
      value: value.trim(),
      updated_at: new Date().toISOString(),
    });
    if (error) {
      toast.error(`儲存失敗:${error.message}`);
      return;
    }
    toast.success(`已儲存 ${key}`);
    setDrafts((d) => {
      const rest = { ...d };
      delete rest[key];
      return rest;
    });
    setNewKey("");
    setNewValue("");
    void queryClient.invalidateQueries({ queryKey: ["app-settings"] });
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">全局設定(app_settings)</CardTitle>
      </CardHeader>
      <CardContent className="space-y-3">
        {isPending && <p className="text-muted-foreground">載入中…</p>}
        {error && (
          <p className="text-destructive">載入失敗:{error.message}</p>
        )}
        <datalist id="tz-options">
          {COMMON_TIMEZONES.map((tz) => (
            <option key={tz} value={tz} />
          ))}
        </datalist>
        {data?.map((row) => (
          <div key={row.key} className="flex items-center gap-3">
            <code className="w-56 shrink-0 text-sm">{row.key}</code>
            <Input
              className="max-w-72"
              list={row.key === "default_event_timezone" ? "tz-options" : undefined}
              value={drafts[row.key] ?? row.value}
              onChange={(e) =>
                setDrafts((d) => ({ ...d, [row.key]: e.target.value }))
              }
            />
            <Button
              size="sm"
              variant="outline"
              disabled={(drafts[row.key] ?? row.value) === row.value}
              onClick={() => save(row.key, drafts[row.key] ?? row.value)}
            >
              儲存
            </Button>
            <span className="text-xs text-muted-foreground">
              更新於 {fmtDateTime(row.updated_at)}
            </span>
          </div>
        ))}
        <div className="flex items-center gap-3 border-t pt-3">
          <Input
            className="w-56"
            placeholder="新鍵名"
            value={newKey}
            onChange={(e) => setNewKey(e.target.value)}
          />
          <Input
            className="max-w-72"
            placeholder="值"
            value={newValue}
            onChange={(e) => setNewValue(e.target.value)}
          />
          <Button
            size="sm"
            disabled={!newKey.trim() || !newValue.trim()}
            onClick={() => save(newKey.trim(), newValue)}
          >
            新增
          </Button>
        </div>
        <p className="text-xs text-muted-foreground">
          目前 App 使用的鍵:<code>default_event_timezone</code>(新建活動的預設時區,IANA 名)。
        </p>
      </CardContent>
    </Card>
  );
}

function AlmanacCard() {
  const now = new Date();
  const [month, setMonth] = useState(
    `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`,
  );

  const { data, isPending, error } = useQuery({
    queryKey: ["almanac", month],
    queryFn: async () => {
      const [y, m] = month.split("-").map(Number);
      const first = `${y}-${String(m).padStart(2, "0")}-01`;
      const last = new Date(Date.UTC(y, m, 0)).toISOString().slice(0, 10);
      const { data, error } = await supabase
        .from("almanac_days")
        .select(
          "solar_date, lunar_month, lunar_day, is_leap_month, names_hant, is_zhai_ten, has_major",
        )
        .gte("solar_date", first)
        .lte("solar_date", last)
        .order("solar_date");
      if (error) throw error;
      return data as AlmanacRow[];
    },
  });

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center justify-between text-base">
          佛曆特殊日(almanac_days,唯讀)
          <Input
            type="month"
            className="w-44"
            value={month}
            onChange={(e) => setMonth(e.target.value)}
          />
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-3">
        <Alert>
          <AlertDescription>
            佛曆數據由生成器產出、經 migration 入庫,任何帳號都不可直接改庫。要調整節日清單,改
            <code className="mx-1">tools/almanac/festivals.cjs</code>
            後重新生成(PLAN E15)。
          </AlertDescription>
        </Alert>
        {isPending && <p className="text-muted-foreground">載入中…</p>}
        {error && (
          <p className="text-destructive">載入失敗:{error.message}</p>
        )}
        {data && (
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>公曆</TableHead>
                <TableHead>農曆</TableHead>
                <TableHead>節日</TableHead>
                <TableHead>標記</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {data.map((r) => (
                <TableRow key={r.solar_date}>
                  <TableCell>{r.solar_date}</TableCell>
                  <TableCell>
                    {r.is_leap_month ? "閏" : ""}
                    {r.lunar_month}月{r.lunar_day}日
                  </TableCell>
                  <TableCell>{r.names_hant.join("、") || "—"}</TableCell>
                  <TableCell className="space-x-1">
                    {r.is_zhai_ten && <Badge variant="secondary">十齋</Badge>}
                    {r.has_major && <Badge>★ 重大</Badge>}
                  </TableCell>
                </TableRow>
              ))}
              {data.length === 0 && (
                <TableRow>
                  <TableCell
                    colSpan={4}
                    className="text-center text-muted-foreground"
                  >
                    本月無特殊日記錄
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        )}
      </CardContent>
    </Card>
  );
}

export default function AlmanacPage() {
  return (
    <div className="space-y-6">
      <h2 className="text-xl font-semibold">佛曆與設定</h2>
      <SettingsCard />
      <AlmanacCard />
    </div>
  );
}
