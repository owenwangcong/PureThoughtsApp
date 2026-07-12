-- ============================================================================
-- 账号体系改用户名+密码(PRD v0.5.9):邮箱降为选填的找回密码渠道。
-- 用户名在客户端映射为内部邮箱 <用户名>@u.pure-thoughts.com(免验证,
-- 生产 ENABLE_EMAIL_AUTOCONFIRM=true);恢复邮箱存本列,本人可读写(沿用
-- profiles 现有 RLS:本人可更新自己的行)。
-- ============================================================================

alter table public.profiles
  add column if not exists recovery_email text;

comment on column public.profiles.recovery_email is
  '选填的找回密码邮箱(PRD v0.5.9);纯用户名账号无真实邮箱,重置密码走管理员协助';
