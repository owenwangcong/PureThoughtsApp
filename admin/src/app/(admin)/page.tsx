"use client";

import Link from "next/link";
import {
  Card,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";

const LIVE = [
  { href: "/dashboard", title: "數據看板", description: "報數趨勢、推送健康、通知積壓" },
  { href: "/events", title: "活動管理", description: "活動 CRUD、每週循環、單次取消/改期、議程與附件" },
  { href: "/event-types", title: "活動類型", description: "類型增改停用、圖示" },
  { href: "/notifications", title: "通知發佈", description: "立即/定時發佈、排程佇列、撤回" },
  { href: "/reports", title: "舉報處理", description: "舉報流轉、封禁/解封" },
  { href: "/users", title: "用戶管理", description: "搜尋、重置密碼、封禁、設/撤管理員、代刪帳號" },
  { href: "/groups", title: "群組總覽", description: "全部群、成員數與總量、轉讓/解散" },
  { href: "/content", title: "內容上架", description: "音訊媒體、功課主清單、經本、直播場次" },
  { href: "/almanac", title: "佛曆與設定", description: "佛曆數據瀏覽、app_settings 維護" },
];

const PENDING: { title: string; description: string; phase: string }[] = [];

export default function HomePage() {
  return (
    <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
      {LIVE.map((m) => (
        <Link key={m.href} href={m.href}>
          <Card className="h-full transition-colors hover:bg-muted/50">
            <CardHeader>
              <CardTitle className="text-base">{m.title}</CardTitle>
              <CardDescription>{m.description}</CardDescription>
            </CardHeader>
          </Card>
        </Link>
      ))}
      {PENDING.map((m) => (
        <Card key={m.title} className="opacity-60">
          <CardHeader>
            <CardTitle className="flex items-center justify-between text-base">
              {m.title}
              <span className="rounded bg-muted px-2 py-0.5 text-xs font-normal text-muted-foreground">
                待開發 · {m.phase}
              </span>
            </CardTitle>
            <CardDescription>{m.description}</CardDescription>
          </CardHeader>
        </Card>
      ))}
    </div>
  );
}
