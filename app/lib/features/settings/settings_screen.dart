import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/env.dart';
import '../../core/prefs.dart';
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

  bool get _debugEnvIsProd =>
      ref.read(sharedPrefsProvider).getString(PrefKeys.debugEnv) == 'prod';

  /// debug 版专属:切换本地栈 / 生产实例(写偏好,重启 App 生效)
  Future<void> _switchDebugEnv() async {
    final prefs = ref.read(sharedPrefsProvider);
    final messenger = ScaffoldMessenger.of(context);
    final cur = _debugEnvIsProd ? 'prod' : 'local';
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('切換開發環境'),
        children: [
          RadioListTile<String>(
            value: 'local',
            groupValue: cur,
            title: const Text('本地棧'),
            subtitle: Text(Env.supabaseUrl),
            onChanged: (v) => Navigator.pop(context, v),
          ),
          RadioListTile<String>(
            value: 'prod',
            groupValue: cur,
            title: const Text('生產'),
            subtitle: Text(Env.prodSupabaseAnonKey.isEmpty
                ? '不可用:需以 --dart-define-from-file=env/dev.json 構建並填入生產 ANON_KEY'
                : Env.prodSupabaseUrl),
            onChanged: Env.prodSupabaseAnonKey.isEmpty
                ? null
                : (v) => Navigator.pop(context, v),
          ),
        ],
      ),
    );
    if (picked == null || picked == cur) return;
    await prefs.setString(PrefKeys.debugEnv, picked);
    if (mounted) setState(() {});
    messenger.showSnackBar(const SnackBar(
      content: Text('已切換,請完全關閉並重新打開 App 生效'),
    ));
  }

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

          // ---- 外观(浅色/深色/跟随系统) ----
          Text(l10n.themeTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(
                  value: ThemeMode.system,
                  icon: const Icon(Icons.brightness_auto),
                  label: Text(l10n.themeSystem)),
              ButtonSegment(
                  value: ThemeMode.light,
                  icon: const Icon(Icons.light_mode_outlined),
                  label: Text(l10n.themeLight)),
              ButtonSegment(
                  value: ThemeMode.dark,
                  icon: const Icon(Icons.dark_mode_outlined),
                  label: Text(l10n.themeDark)),
            ],
            selected: {ref.watch(themeModeProvider)},
            onSelectionChanged: (s) =>
                ref.read(themeModeProvider.notifier).set(s.first),
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

          const Divider(height: 32),

          // ---- 隐私与合规 ----
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l10n.privacyPolicy),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/privacy'),
          ),
          if (profile.value?['is_app_admin'] == true)
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(l10n.adminReports),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/admin/reports'),
            ),

          // ---- 开发环境切换(仅 debug 构建;release 编译期剔除,文案不入 l10n) ----
          if (kDebugMode) ...[
            const Divider(height: 32),
            ListTile(
              leading: const Icon(Icons.developer_mode),
              title: const Text('開發環境'),
              subtitle: Text(_debugEnvIsProd
                  ? '生產:${Env.prodSupabaseUrl}'
                  : '本地:${Env.supabaseUrl}'),
              trailing: const Icon(Icons.swap_horiz),
              onTap: _switchDebugEnv,
            ),
          ],

          // ---- 登出 / 删除账号 ----
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
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => _deleteAccount(context),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: Text(l10n.deleteAccount),
            ),
          ],
        ],
      ),
    );
  }

  /// 账号删除(PRD §10.1,上架硬需求):二次确认 → Edge Function →
  /// 删号 + 报数匿名化保留群总量;活跃群群主须先转让/解散。
  Future<void> _deleteAccount(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteAccount),
        content: Text(l10n.deleteAccountWarn),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.deleteAccount),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await Supabase.instance.client.functions.invoke('delete-account');
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}
      router.go('/');
    } on FunctionException catch (e) {
      final code = (e.details is Map) ? (e.details as Map)['error'] : null;
      messenger.showSnackBar(SnackBar(
        content: Text(code == 'owner_of_active_group'
            ? l10n.deleteOwnerBlocked
            : '${l10n.authFailed}$e'),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('${l10n.authFailed}$e')));
    }
  }
}
