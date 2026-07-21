# 善护念 · 管理后台(admin/)

面向 App 管理员的桌面 Web 管理台(PRD §15,任务 PLAN P7)。

- **技术栈**:Next.js(App Router,静态导出)+ React + shadcn/ui + Tailwind + supabase-js + TanStack Query
- **权限模型**:管理员账号登录(复用 Supabase Auth,无 MFA);读写全部走 anon key + session,由数据库 RLS / `is_app_admin()` 把关,与 App 同一套权限。特权操作(重置密码等)走 Edge Function `admin-ops`(P7.3)。
- **部署**:`admin.pure-thoughts.com`,`npm run build` 产出 `out/` 纯静态目录放 Apache(P7.5)。

## 常用命令

```sh
npm run dev        # 开发(默认连本地 Supabase 栈,先 npx supabase start)
npm run build      # 静态导出到 out/
npm run lint       # ESLint
npm run gen:types  # 重新生成 src/lib/database.types.ts(需本地栈运行;改 schema 后必跑)
```

本地测试账号(根目录 seed):`admin@test.local` / `test1234`(管理员),`member@test.local` / `test1234`(非管理员,应被拒)。

## 环境切换

`NEXT_PUBLIC_SUPABASE_URL` / `NEXT_PUBLIC_SUPABASE_ANON_KEY` 在**构建时**内联:

- 不设置 → 默认本地栈 `http://127.0.0.1:54321`(开发零配置);
- 生产构建 → 复制 `.env.example` 为 `.env.production.local`(gitignored)填生产值,再 `npm run build`。

## 登录规则

与 App 端一致(`src/lib/username.ts` = `app/lib/features/auth/username.dart` 的移植):纯用户名映射为 `<用户名>@u.pure-thoughts.com`,含 `@` 视为真实邮箱;非管理员登录后立即登出并提示。
