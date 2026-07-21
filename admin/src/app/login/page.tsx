"use client";

import { useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { supabase } from "@/lib/supabase";
import { loginEmailFor } from "@/lib/username";

export default function LoginPage() {
  const router = useRouter();
  const queryClient = useQueryClient();
  const [account, setAccount] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);

    const email = loginEmailFor(account);
    if (!email) {
      setError("帳號格式不正確(用戶名為 3–30 位小寫字母、數字或 . _ -)");
      return;
    }
    setBusy(true);
    try {
      const { data, error: signInError } =
        await supabase.auth.signInWithPassword({ email, password });
      if (signInError) {
        setError(
          signInError.code === "invalid_credentials"
            ? "帳號或密碼錯誤"
            : `登入失敗:${signInError.message}`,
        );
        return;
      }

      const { data: profile, error: profileError } = await supabase
        .from("profiles")
        .select("is_app_admin")
        .eq("id", data.user.id)
        .single();
      if (profileError || !profile.is_app_admin) {
        await supabase.auth.signOut();
        setError(
          profileError
            ? `無法讀取帳號資料:${profileError.message}`
            : "此帳號沒有管理員權限",
        );
        return;
      }

      // 丢弃登录前缓存的守卫状态(anon),否则 AdminGuard 会用旧值把人弹回登录页
      queryClient.removeQueries({ queryKey: ["admin-guard"] });
      router.replace("/");
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-muted/40 p-6">
      <Card className="w-full max-w-sm">
        <CardHeader>
          <CardTitle className="text-xl">善護念 · 管理後台</CardTitle>
          <CardDescription>僅限管理員登入</CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={onSubmit} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="account">用戶名或信箱</Label>
              <Input
                id="account"
                autoComplete="username"
                value={account}
                onChange={(e) => setAccount(e.target.value)}
                autoFocus
                required
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="password">密碼</Label>
              <Input
                id="password"
                type="password"
                autoComplete="current-password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
              />
            </div>
            {error && (
              <Alert variant="destructive">
                <AlertDescription>{error}</AlertDescription>
              </Alert>
            )}
            <Button type="submit" className="w-full" disabled={busy}>
              {busy ? "登入中…" : "登入"}
            </Button>
          </form>
        </CardContent>
      </Card>
    </main>
  );
}
