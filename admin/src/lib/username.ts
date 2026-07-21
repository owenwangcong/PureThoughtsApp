/**
 * 用户名 ↔ Supabase Auth 内部邮箱映射(PRD v0.5.9 §12.5)。
 * 与 App 端 `app/lib/features/auth/username.dart` 保持一致:
 * 纯用户名映射为 `<用户名>@u.pure-thoughts.com`;含 `@` 的输入视为真实邮箱。
 */

export const USERNAME_EMAIL_DOMAIN = "u.pure-thoughts.com";

const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
const USERNAME_RE = /^[a-z0-9._-]{3,30}$/;

/** 用户名/邮箱 → Auth 邮箱;格式非法返回 null。统一小写与去空白。 */
export function loginEmailFor(input: string): string | null {
  const t = input.trim().toLowerCase();
  if (!t) return null;
  if (t.includes("@")) return EMAIL_RE.test(t) ? t : null;
  return USERNAME_RE.test(t) ? `${t}@${USERNAME_EMAIL_DOMAIN}` : null;
}

/** 展示用登录名:内部邮箱剥掉域名,真实邮箱原样。 */
export function displayLoginName(email: string): string {
  return email.toLowerCase().endsWith(`@${USERNAME_EMAIL_DOMAIN}`)
    ? email.slice(0, email.length - USERNAME_EMAIL_DOMAIN.length - 1)
    : email;
}
