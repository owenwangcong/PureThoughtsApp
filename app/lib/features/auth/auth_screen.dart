import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/gen/app_localizations.dart';
import 'profile_sync.dart';

enum _AuthMode { signIn, signUp, reset }

/// 邮箱登录 / 注册 / 找回密码。
/// Google / Apple 登录待 OAuth 配置(PLAN E3/E4)后补充。
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _mode = _AuthMode.signIn;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final auth = Supabase.instance.client.auth;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      switch (_mode) {
        case _AuthMode.signIn:
          await auth.signInWithPassword(email: _email.text.trim(), password: _password.text);
        case _AuthMode.signUp:
          await auth.signUp(email: _email.text.trim(), password: _password.text);
        case _AuthMode.reset:
          await auth.resetPasswordForEmail(_email.text.trim());
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.authResetSent)));
            setState(() => _mode = _AuthMode.signIn);
          }
          return;
      }
      await syncProfileFromPrefs(ref);
      if (mounted) context.go('/');
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
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
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: InputDecoration(labelText: l10n.authEmail),
                    validator: (v) =>
                        (v == null || !v.contains('@')) ? l10n.authEmailInvalid : null,
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
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      '${l10n.authFailed}\n$_error',
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
