import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_thoughts/core/error_text.dart';
import 'package:pure_thoughts/l10n/gen/app_localizations.dart';
import 'package:pure_thoughts/l10n/gen/app_localizations_zh.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final AppLocalizations hant = AppLocalizationsZhHant();
  final AppLocalizations hans = AppLocalizationsZhHans();

  group('errText 异常 → 中文映射', () {
    test('登录凭据错误(靠 message 关键字)', () {
      final e = const AuthException('Invalid login credentials');
      expect(errText(hant, e), hant.errAuthInvalidCredentials);
      expect(errText(hant, e), '用戶名或密碼錯誤');
    });

    test('账号已注册(靠 GoTrue 结构化 code)', () {
      final e = const AuthException('...', code: 'user_already_exists');
      expect(errText(hant, e), hant.errAuthAlreadyRegistered);
    });

    test('弱密码子类', () {
      final e = AuthWeakPasswordException(
        message: 'weak', statusCode: '422', reasons: const ['length']);
      expect(errText(hant, e), hant.errAuthWeakPassword);
    });

    test('限流 code', () {
      final e = const AuthException('...', code: 'over_request_rate_limit');
      expect(errText(hant, e), hant.errAuthRateLimited);
    });

    test('可重试网络异常归为网络类', () {
      final e = AuthRetryableFetchException();
      expect(errText(hant, e), hant.errNetwork);
    });

    test('Postgrest RLS(42501)→ 无权限', () {
      final e = PostgrestException(message: 'denied', code: '42501');
      expect(errText(hant, e), hant.errNoPermission);
    });

    test('Postgrest 唯一约束(23505)→ 重复', () {
      final e = PostgrestException(message: 'dup', code: '23505');
      expect(errText(hant, e), hant.errDuplicate);
    });

    test('SocketException → 网络类', () {
      expect(errText(hant, const SocketException('failed')), hant.errNetwork);
    });

    test('TimeoutException → 网络类', () {
      expect(errText(hant, TimeoutException('t')), hant.errNetwork);
    });

    test('未知异常兜底为通用中文,不透传英文', () {
      final msg = errText(hant, Exception('some raw English error'));
      expect(msg, hant.errGeneric);
      expect(msg.contains('English'), isFalse);
    });

    test('简体输出走简体文案', () {
      final e = const AuthException('Invalid login credentials');
      expect(errText(hans, e), '用户名或密码错误');
    });
  });
}
