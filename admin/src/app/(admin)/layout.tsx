"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useQueryClient } from "@tanstack/react-query";
import { AdminGuard, useAdminProfile } from "@/components/admin-guard";
import { Button } from "@/components/ui/button";
import { supabase } from "@/lib/supabase";
import { cn } from "@/lib/utils";

const NAV = [
  { href: "/", label: "總覽" },
  { href: "/events", label: "活動管理" },
  { href: "/event-types", label: "活動類型" },
  { href: "/notifications", label: "通知發佈" },
  { href: "/reports", label: "舉報處理" },
  { href: "/almanac", label: "佛曆與設定" },
];

function Shell({ children }: { children: React.ReactNode }) {
  const profile = useAdminProfile();
  const router = useRouter();
  const queryClient = useQueryClient();
  const pathname = (usePathname() ?? "/").replace(/\/+$/, "") || "/";

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
                    "rounded-md px-3 py-2 text-sm hover:bg-muted",
                    active && "bg-muted font-medium",
                  )}
                >
                  {item.label}
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
