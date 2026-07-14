import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error_text.dart';
import '../../l10n/gen/app_localizations.dart';
import 'profile_sync.dart';
import 'username.dart';

enum _AuthMode { signIn, signUp, reset }

/// 用户名+密码 注册 / 登录 / 找回密码(PRD v0.5.9)。
/// 用户名映射内部邮箱(username.dart);注册免邮箱验证;
/// 选填恢复邮箱存 profiles.recovery_email。
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _recoveryEmail = TextEditingController();
  var _mode = _AuthMode.signIn;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _recoveryEmail.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final auth = Supabase.instance.client.auth;
    final email = loginEmailFor(_username.text)!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      switch (_mode) {
        case _AuthMode.signIn:
          await auth.signInWithPassword(email: email, password: _password.text);
        case _AuthMode.signUp:
          await auth.signUp(email: email, password: _password.text);
          await _saveRecoveryEmail();
        case _AuthMode.reset:
          // 纯用户名账号没有真实邮箱,自助重置走不通 → 提示联系管理员
          if (isInternalEmail(email)) {
            setState(() => _error = l10n.authResetNeedAdmin);
            return;
          }
          await auth.resetPasswordForEmail(email);
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(l10n.authResetSent)));
            setState(() => _mode = _AuthMode.signIn);
          }
          return;
      }
      await syncProfileFromPrefs(ref);
      if (mounted) context.go('/');
    } catch (e) {
      setState(() => _error = errText(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveRecoveryEmail() async {
    final recovery = _recoveryEmail.text.trim().toLowerCase();
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (recovery.isEmpty || uid == null) return;
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'recovery_email': recovery}).eq('id', uid);
    } catch (_) {
      // 恢复邮箱保存失败不阻断注册(可稍后在设置中补)
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = switch (_mode) {
      _AuthMode.signIn => l10n.authSignIn,
      _AuthMode.signUp => l10n.authSignUp,
      _AuthMode.reset => l10n.authForgot,
    };

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _username,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.username],
                    decoration: InputDecoration(
                      labelText: l10n.authUsername,
                      helperText:
                          _mode == _AuthMode.signUp ? l10n.authUsernameHint : null,
                    ),
                    validator: (v) =>
                        loginEmailFor(v ?? '') == null ? l10n.authUsernameInvalid : null,
                  ),
                  if (_mode != _AuthMode.reset) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(labelText: l10n.authPassword),
                      validator: (v) => (v == null || v.length < 6) ? l10n.authPasswordMin : null,
                    ),
                  ],
                  if (_mode == _AuthMode.signUp) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _recoveryEmail,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(
                        labelText: l10n.authRecoveryEmail,
                        helperText: l10n.authRecoveryEmailHint,
                      ),
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return null; // 选填
                        return loginEmailFor(t) != null && t.contains('@')
                            ? null
                            : l10n.authEmailInvalid;
                      },
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    child: _busy
                        ? const SizedBox(
                            width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(title),
                  ),
                  const SizedBox(height: 16),
                  if (_mode == _AuthMode.signIn) ...[
                    TextButton(
                      onPressed: () => setState(() => _mode = _AuthMode.signUp),
                      child: Text(l10n.authToSignUp),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _mode = _AuthMode.reset),
                      child: Text(l10n.authForgot),
                    ),
                  ] else
                    TextButton(
                      onPressed: () => setState(() => _mode = _AuthMode.signIn),
                      child: Text(l10n.authToSignIn),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
