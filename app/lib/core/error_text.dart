import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/gen/app_localizations.dart';

/// 把后端 / 网络异常映射为本地化中文文案。
///
/// 统一入口:凡是要把异常显示给用户的地方,一律用 `errText(l10n, e)`,
/// 不再把 `e.toString()` / `e.message`(多为英文)直接抛给用户。
/// 无法归类的异常兜底为通用中文提示(`errGeneric`)。
String errText(AppLocalizations l10n, Object e) {
  // 网络类:超时 / 断网 / SocketException(PostgrestException 也可能包裹网络错误)
  if (e is SocketException || e is TimeoutException) return l10n.errNetwork;
  if (e is AuthException) return _authText(l10n, e);
  if (e is PostgrestException) return _postgrestText(l10n, e);
  // 兜底:仍可能是网络层字样
  if (_looksLikeNetwork(e.toString())) return l10n.errNetwork;
  return l10n.errGeneric;
}

String _authText(AppLocalizations l10n, AuthException e) {
  // GoTrue 网络类可重试异常
  if (e is AuthRetryableFetchException) return l10n.errNetwork;
  if (e is AuthWeakPasswordException) return l10n.errAuthWeakPassword;

  // 优先用 GoTrue 结构化错误码(比 message 文本更稳)
  switch (e.code) {
    case 'user_already_exists':
    case 'email_exists':
      return l10n.errAuthAlreadyRegistered;
    case 'weak_password':
      return l10n.errAuthWeakPassword;
    case 'email_not_confirmed':
      return l10n.errAuthNotActivated;
    case 'over_request_rate_limit':
    case 'over_email_send_rate_limit':
      return l10n.errAuthRateLimited;
    case 'signup_disabled':
      return l10n.errAuthSignupDisabled;
    case 'user_banned':
      return l10n.errAuthBanned;
    case 'session_expired':
    case 'bad_jwt':
      return l10n.errSessionExpired;
    case 'no_authorization':
      return l10n.errNoPermission;
  }

  // 无结构化码时回退到 message 关键字(如 invalid_credentials 在旧版无 code)
  final m = e.message.toLowerCase();
  if (m.contains('invalid login') ||
      m.contains('invalid credentials') ||
      m.contains('invalid email or password')) {
    return l10n.errAuthInvalidCredentials;
  }
  if (m.contains('already registered') ||
      m.contains('already been registered') ||
      m.contains('already exists') ||
      m.contains('user already')) {
    return l10n.errAuthAlreadyRegistered;
  }
  if (m.contains('password') && (m.contains('at least') || m.contains('6 char') || m.contains('should be'))) {
    return l10n.errAuthWeakPassword;
  }
  if (m.contains('email not confirmed') || m.contains('not confirmed')) {
    return l10n.errAuthNotActivated;
  }
  if (m.contains('for security purposes') ||
      m.contains('rate limit') ||
      m.contains('too many requests') ||
      e.statusCode == '429') {
    return l10n.errAuthRateLimited;
  }
  if (m.contains('signups not allowed') ||
      m.contains('signup is disabled') ||
      m.contains('signups are disabled')) {
    return l10n.errAuthSignupDisabled;
  }
  if (_looksLikeNetwork(m)) return l10n.errNetwork;
  return l10n.errGeneric;
}

String _postgrestText(AppLocalizations l10n, PostgrestException e) {
  switch (e.code) {
    case '23505': // unique_violation
      return l10n.errDuplicate;
    case '42501': // insufficient_privilege(RLS 拦截)
      return l10n.errNoPermission;
    case 'PGRST301': // JWT 过期
      return l10n.errSessionExpired;
  }
  final m = e.message.toLowerCase();
  if (m.contains('row-level security') ||
      m.contains('permission denied') ||
      m.contains('not authorized')) {
    return l10n.errNoPermission;
  }
  if (m.contains('jwt expired') || m.contains('token is expired')) {
    return l10n.errSessionExpired;
  }
  if (_looksLikeNetwork(m)) return l10n.errNetwork;
  return l10n.errGeneric;
}

bool _looksLikeNetwork(String s) {
  final m = s.toLowerCase();
  return m.contains('socketexception') ||
      m.contains('failed host lookup') ||
      m.contains('connection refused') ||
      m.contains('connection closed') ||
      m.contains('connection reset') ||
      m.contains('network is unreachable') ||
      m.contains('timed out') ||
      m.contains('timeout') ||
      m.contains('clientexception');
}
