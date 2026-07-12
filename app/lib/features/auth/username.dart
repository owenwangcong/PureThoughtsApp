/// 用户名 ↔ Supabase Auth 内部邮箱映射(PRD v0.5.9 §12.5)。
///
/// 面向年长/无邮箱用户:注册只需用户名+密码。Auth 底层要求邮箱格式,
/// 纯用户名在客户端映射为 `<用户名>@u.pure-thoughts.com`(用户无感);
/// 含 `@` 的输入视为真实邮箱账号(可自助重置密码)。
library;

const kUsernameEmailDomain = 'u.pure-thoughts.com';

final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final _usernameRe = RegExp(r'^[a-z0-9._-]{3,30}$');

/// 用户名/邮箱 → Auth 邮箱;格式非法返回 null。
/// 统一小写与去空白,保证同一用户名不因大小写产生两个账号。
String? loginEmailFor(String input) {
  final t = input.trim().toLowerCase();
  if (t.isEmpty) return null;
  if (t.contains('@')) return _emailRe.hasMatch(t) ? t : null;
  return _usernameRe.hasMatch(t) ? '$t@$kUsernameEmailDomain' : null;
}

/// 是否内部映射邮箱(纯用户名账号)
bool isInternalEmail(String email) =>
    email.toLowerCase().endsWith('@$kUsernameEmailDomain');

/// 展示用登录名:内部邮箱剥掉域名,真实邮箱原样
String displayLoginName(String email) => isInternalEmail(email)
    ? email.substring(0, email.length - kUsernameEmailDomain.length - 1)
    : email;
