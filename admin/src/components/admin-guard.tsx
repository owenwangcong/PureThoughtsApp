"use client";

import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { createContext, useContext, useEffect } from "react";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";
import { supabase } from "@/lib/supabase";
import { displayLoginName } from "@/lib/username";

export interface AdminProfile {
  userId: string;
  displayName: string;
  loginName: string;
}

type GuardState =
  | { status: "anon" }
  | { status: "forbidden" }
  | { status: "admin"; profile: AdminProfile };

const AdminProfileContext = createContext<AdminProfile | null>(null);

/** 仅在 AdminGuard 内部使用;返回当前管理员资料。 */
export function useAdminProfile(): AdminProfile {
  const profile = useContext(AdminProfileContext);
  if (!profile) throw new Error("useAdminProfile 必须在 AdminGuard 内使用");
  return profile;
}

async function loadGuardState(): Promise<GuardState> {
  const { data: sessionData } = await supabase.auth.getSession();
  const session = sessionData.session;
  if (!session) return { status: "anon" };

  const { data, error } = await supabase
    .from("profiles")
    .select("is_app_admin, display_name")
    .eq("id", session.user.id)
    .single();
  if (error) throw error;
  if (!data.is_app_admin) return { status: "forbidden" };
  return {
    status: "admin",
    profile: {
      userId: session.user.id,
      displayName: data.display_name ?? "",
      loginName: displayLoginName(session.user.email ?? ""),
    },
  };
}

/** 登入 + 管理员双重校验:未登入跳 /login,非管理员登出并提示。 */
export function AdminGuard({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const queryClient = useQueryClient();
  const { data, isPending, isError, refetch } = useQuery({
    queryKey: ["admin-guard"],
    queryFn: loadGuardState,
  });

  useEffect(() => {
    if (data?.status === "anon") router.replace("/login");
    // 非管理员:立即登出,防止会话残留
    if (data?.status === "forbidden") void supabase.auth.signOut();
  }, [data, router]);

  if (isError) {
    return (
      <main className="flex min-h-screen items-center justify-center p-6">
        <Alert variant="destructive" className="max-w-md">
          <AlertTitle>載入失敗</AlertTitle>
          <AlertDescription>
            無法確認登入狀態,請檢查網路後重試。
            <Button
              variant="outline"
              size="sm"
              className="mt-3"
              onClick={() => refetch()}
            >
              重試
            </Button>
          </AlertDescription>
        </Alert>
      </main>
    );
  }

  if (data?.status === "forbidden") {
    return (
      <main className="flex min-h-screen items-center justify-center p-6">
        <Alert variant="destructive" className="max-w-md">
          <AlertTitle>沒有管理員權限</AlertTitle>
          <AlertDescription>
            此帳號不是管理員,已為你登出。
            <Button
              variant="outline"
              size="sm"
              className="mt-3"
              onClick={() => {
                queryClient.removeQueries({ queryKey: ["admin-guard"] });
                router.replace("/login");
              }}
            >
              返回登入
            </Button>
          </AlertDescription>
        </Alert>
      </main>
    );
  }

  if (isPending || data.status !== "admin") {
    return (
      <main className="flex min-h-screen items-center justify-center">
        <p className="text-muted-foreground">載入中…</p>
      </main>
    );
  }

  return (
    <AdminProfileContext.Provider value={data.profile}>
      {children}
    </AdminProfileContext.Provider>
  );
}
