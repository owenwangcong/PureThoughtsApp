"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { AdminGuard, useAdminProfile } from "@/components/admin-guard";
import { Button } from "@/components/ui/button";
import { supabase } from "@/lib/supabase";
import { cn } from "@/lib/utils";

const NAV = [
  { href: "/", label: "總覽" },
  { href: "/dashboard", label: "數據看板" },
  { href: "/events", label: "活動管理" },
  { href: "/event-types", label: "活動類型" },
  { href: "/notifications", label: "通知發佈" },
  { href: "/qa", label: "學修問答" },
  { href: "/reports", label: "舉報處理" },
  { href: "/users", label: "用戶管理" },
  { href: "/groups", label: "群組總覽" },
  { href: "/content", label: "內容上架" },
  { href: "/almanac", label: "佛曆與設定" },
];

/** 待回覆提问数(侧栏角标;导航加载时查询,不做实时——设计 study-qa.md §5) */
function usePendingQaCount() {
  const { data } = useQuery({
    queryKey: ["qa-pending-count"],
    queryFn: async () => {
      const { count, error } = await supabase
        .from("qa_threads")
        .select("id", { count: "exact", head: true })
        .eq("last_sender_role", "user");
      if (error) throw error;
      return count ?? 0;
    },
  });
  return data ?? 0;
}

function Shell({ children }: { children: React.ReactNode }) {
  const profile = useAdminProfile();
  const router = useRouter();
  const queryClient = useQueryClient();
  const pathname = (usePathname() ?? "/").replace(/\/+$/, "") || "/";
  const pendingQa = usePendingQaCount();

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
      <div className="flex flex-1">
        <aside className="w-44 shrink-0 border-r p-3">
          <nav className="flex flex-col gap-1">
            {NAV.map((item) => {
              const active =
                item.href === "/"
                  ? pathname === "/"
                  : pathname.startsWith(item.href);
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  className={cn(
                    "flex items-center justify-between rounded-md px-3 py-2 text-sm hover:bg-muted",
                    active && "bg-muted font-medium",
                  )}
                >
                  <span>{item.label}</span>
                  {item.href === "/qa" && pendingQa > 0 && (
                    <span className="ml-2 rounded-full bg-destructive px-1.5 text-xs text-white">
                      {pendingQa}
                    </span>
                  )}
                </Link>
              );
            })}
          </nav>
        </aside>
        <main className="min-w-0 flex-1 p-6">{children}</main>
      </div>
    </div>
  );
}

export default function AdminLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <AdminGuard>
      <Shell>{children}</Shell>
    </AdminGuard>
  );
}
