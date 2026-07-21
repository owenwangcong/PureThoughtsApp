"use client";

import { useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { AdminGuard, useAdminProfile } from "@/components/admin-guard";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { supabase } from "@/lib/supabase";

// PLAN P7.2 / P7.4 功能模块占位;开发到哪个就把卡片换成真路由入口。
const MODULES: { title: string; description: string; phase: string }[] = [
  { title: "活動管理", description: "活動 CRUD、循環規則、議程與附件", phase: "P7.2" },
  { title: "通知發佈", description: "立即/定時發佈、排程佇列、撤回", phase: "P7.2" },
  { title: "舉報處理", description: "舉報流轉、封禁/解封", phase: "P7.2" },
  { title: "佛曆與設定", description: "almanac_days 與 app_settings 維護", phase: "P7.2" },
  { title: "用戶管理", description: "搜尋、重置密碼、設/撤管理員", phase: "P7.4" },
  { title: "群組總覽", description: "全部群列表、轉讓/解散", phase: "P7.4" },
  { title: "數據看板", description: "報數趨勢、推送健康、通知積壓", phase: "P7.4" },
  { title: "內容上架", description: "音訊、直播頻道、功課主清單", phase: "P7.4" },
];

function Dashboard() {
  const profile = useAdminProfile();
  const router = useRouter();
  const queryClient = useQueryClient();

  async function onSignOut() {
    await supabase.auth.signOut();
    queryClient.clear();
    router.replace("/login");
  }

  return (
    <div className="flex min-h-screen flex-col">
      <header className="flex items-center justify-between border-b px-6 py-3">
        <h1 className="text-lg font-semibold">善護念 · 管理後台</h1>
        <div className="flex items-center gap-3 text-sm">
          <span className="text-muted-foreground">
            {profile.displayName || profile.loginName}(管理員)
          </span>
          <Button variant="outline" size="sm" onClick={onSignOut}>
            登出
          </Button>
        </div>
      </header>
      <main className="mx-auto w-full max-w-5xl flex-1 p-6">
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {MODULES.map((m) => (
            <Card key={m.title} className="opacity-70">
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
      </main>
    </div>
  );
}

export default function HomePage() {
  return (
    <AdminGuard>
      <Dashboard />
    </AdminGuard>
  );
}
