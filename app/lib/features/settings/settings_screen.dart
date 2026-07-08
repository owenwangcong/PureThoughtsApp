import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/settings.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/auth_providers.dart';
import '../auth/profile_sync.dart';

/// 设置页:显示名(登录后)、语言、字号、地区、登出。
/// 偏好改动即时生效并本地持久化;登录态下同步云端 profiles(PRD §11)。
/// 账号删除入口在 P1.9 合规任务中加入。
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _displayName = TextEditingController();
  var _savingName = false;

  @override
  void dispose() {
    _displayName.dispose();
    super.dispose();
  }

  Future<void> _saveDisplayName() async {
    final user = ref.read(currentUserProvider);
    final name = _displayName.text.trim();
    if (user == null || name.isEmpty) return;
    setState(() => _savingName = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'display_name': name}).eq('id', user.id);
      ref.invalidate(myProfileProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.saved)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.loadFailed)));
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(currentUserProvider);
    final locale = ref.watch(localeProvider);
    final fontScale = ref.watch(fontScaleProvider);
    final region = ref.watch(regionProvider);
    final profile = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- 账号 ----
          if (user == null)
            ListTile(
              leading: const Icon(Icons.login),
              title: Text(l10n.authSignIn),
              onTap: () => context.push('/auth'),
            )
          else ...[
            profile.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => Text(l10n.loadFailed),
              data: (p) {
                if (p != null && _displayName.text.isEmpty) {
                  _displayName.text = p['display_name'] as String? ?? '';
                }
                return Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _displayName,
                        decoration: InputDecoration(labelText: l10n.displayName),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _savingName ? null : _saveDisplayName,
                      child: Text(l10n.save),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Text(user.email ?? '', style: Theme.of(context).textTheme.bodySmall),
          ],
          const Divider(height: 32),

          // ---- 语言 ----
          Text(l10n.onboardingLanguage, style: Theme.of(context).textTheme.titleMedium),
          RadioListTile<String>(
            title: const Text('繁體中文'),
            value: 'Hant',
            groupValue: locale.scriptCode,
            onChanged: (_) {
              ref.read(localeProvider.notifier).set(LocaleController.zhHant);
              syncProfileFromPrefs(ref);
            },
          ),
          RadioListTile<String>(
            title: const Text('简体中文'),
            value: 'Hans',
            groupValue: locale.scriptCode,
            onChanged: (_) {
              ref.read(localeProvider.notifier).set(LocaleController.zhHans);
              syncProfileFromPrefs(ref);
            },
          ),
          const Divider(height: 32),

          // ---- 字号 ----
          Text(l10n.onboardingFont, style: Theme.of(context).textTheme.titleMedium),
          Text(l10n.onboardingFontPreview, textAlign: TextAlign.center),
          Slider(
            value: fontScale,
            min: FontScaleController.min,
            max: FontScaleController.max,
            divisions: 6,
            label: 'x${fontScale.toStringAsFixed(1)}',
            onChanged: (v) => ref.read(fontScaleProvider.notifier).set(v),
            onChangeEnd: (_) => syncProfileFromPrefs(ref),
          ),
          const Divider(height: 32),

          // ---- 地区 ----
          Text(l10n.onboardingRegion, style: Theme.of(context).textTheme.titleMedium),
          Text(l10n.onboardingRegionHint, style: Theme.of(context).textTheme.bodySmall),
          RadioListTile<String>(
            title: Text(l10n.regionCn),
            value: 'cn',
            groupValue: region,
            onChanged: (v) {
              ref.read(regionProvider.notifier).set(v!);
              syncProfileFromPrefs(ref);
            },
          ),
          RadioListTile<String>(
            title: Text(l10n.regionOther),
            value: 'other',
            groupValue: region,
            onChanged: (v) {
              ref.read(regionProvider.notifier).set(v!);
              syncProfileFromPrefs(ref);
            },
          ),

          // ---- 登出 ----
          if (user != null) ...[
            const Divider(height: 32),
            FilledButton.tonal(
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
                if (context.mounted) context.go('/');
              },
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: Text(l10n.authSignOut),
            ),
          ],
        ],
      ),
    );
  }
}
