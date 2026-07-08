import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/settings.dart';
import '../../l10n/gen/app_localizations.dart';
import '../legal/privacy_screen.dart';

/// 首启引导:选语言 → 选字号 → 选地区 → 社区规范同意(PRD §11 / §10.2)。
/// 每步选择即时生效并持久化;最后一步「同意並完成」进入首页。
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  var _step = 0;

  static const _lastStep = 3;

  void _next() {
    if (_step < _lastStep) {
      setState(() => _step++);
    } else {
      // 「同意並完成」= 同意社区规范(EULA,PRD §10.2)
      ref.read(onboardingDoneProvider.notifier).markDone();
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final page = switch (_step) {
      0 => _LanguageStep(l10n: l10n),
      1 => _FontStep(l10n: l10n),
      2 => _RegionStep(l10n: l10n),
      _ => _EulaStep(l10n: l10n),
    };

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: Center(child: SingleChildScrollView(child: page))),
              FilledButton(
                onPressed: _next,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                child: Text(_step < _lastStep ? l10n.next : l10n.eulaAgreeFinish),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageStep extends ConsumerWidget {
  const _LanguageStep({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return Column(
      children: [
        Text(l10n.onboardingLanguage, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 24),
        RadioListTile<String>(
          title: const Text('繁體中文'),
          value: 'Hant',
          groupValue: locale.scriptCode,
          onChanged: (_) => ref.read(localeProvider.notifier).set(LocaleController.zhHant),
        ),
        RadioListTile<String>(
          title: const Text('简体中文'),
          value: 'Hans',
          groupValue: locale.scriptCode,
          onChanged: (_) => ref.read(localeProvider.notifier).set(LocaleController.zhHans),
        ),
      ],
    );
  }
}

class _FontStep extends ConsumerWidget {
  const _FontStep({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(fontScaleProvider);
    return Column(
      children: [
        Text(l10n.onboardingFont, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 24),
        // 预览文字随全局缩放即时变化
        Text(l10n.onboardingFontPreview, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        Slider(
          value: scale,
          min: FontScaleController.min,
          max: FontScaleController.max,
          divisions: 6,
          label: 'x${scale.toStringAsFixed(1)}',
          onChanged: (v) => ref.read(fontScaleProvider.notifier).set(v),
        ),
      ],
    );
  }
}

class _EulaStep extends ConsumerWidget {
  const _EulaStep({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hans = ref.watch(localeProvider).scriptCode == 'Hans';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(l10n.communityGuidelines,
              style: Theme.of(context).textTheme.headlineSmall),
        ),
        const SizedBox(height: 16),
        Text(guidelinesText(hans)),
      ],
    );
  }
}

class _RegionStep extends ConsumerWidget {
  const _RegionStep({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final region = ref.watch(regionProvider);
    return Column(
      children: [
        Text(l10n.onboardingRegion, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(l10n.onboardingRegionHint, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 24),
        RadioListTile<String>(
          title: Text(l10n.regionCn),
          value: 'cn',
          groupValue: region,
          onChanged: (v) => ref.read(regionProvider.notifier).set(v!),
        ),
        RadioListTile<String>(
          title: Text(l10n.regionOther),
          value: 'other',
          groupValue: region,
          onChanged: (v) => ref.read(regionProvider.notifier).set(v!),
        ),
      ],
    );
  }
}
