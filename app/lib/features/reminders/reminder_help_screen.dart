import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../l10n/gen/app_localizations.dart';
import 'mindfulness_controller.dart';

/// 「让提醒准时响起」设置帮助页(design §9)。
/// 依当前平台展示 iOS / Android 指引;大陆厂商额外说明;顶部放响铃自检。
class ReminderHelpScreen extends ConsumerWidget {
  const ReminderHelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isIos = Platform.isIOS;

    Future<void> selfCheck() async {
      final s = ref.read(mindfulnessProvider);
      await ref.read(reminderSchedulerProvider).showTest(
            s,
            title: l10n.mrTitle,
            body: l10n.mrMessageDefault,
            channelName: l10n.mrTitle,
            channelDescription: l10n.mrEnableHint,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.mrTestSent)));
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mrHelp)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.mrHelpIntro, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 16),
          // 响铃自检
          Card(
            color: theme.colorScheme.secondaryContainer,
            child: ListTile(
              leading: Icon(Icons.notifications_active_outlined,
                  color: theme.colorScheme.onSecondaryContainer),
              title: Text(l10n.mrSelfCheck,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: theme.colorScheme.onSecondaryContainer)),
              subtitle: Text(l10n.mrSelfCheckHint,
                  style: TextStyle(color: theme.colorScheme.onSecondaryContainer)),
              trailing: FilledButton(onPressed: selfCheck, child: Text(l10n.mrTest)),
            ),
          ),
          const SizedBox(height: 20),
          if (isIos)
            _HelpSection(
              title: l10n.mrHelpIosTitle,
              steps: [l10n.mrHelpIosStep1, l10n.mrHelpIosStep2, l10n.mrHelpIosStep3],
            )
          else ...[
            _HelpSection(
              title: l10n.mrHelpAndroidTitle,
              steps: [l10n.mrHelpAndroidStep1, l10n.mrHelpAndroidStep2, l10n.mrHelpAndroidStep3],
            ),
            const SizedBox(height: 16),
            // 大陆厂商专项(最大风险)
            Card(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.mrHelpOemTitle, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(l10n.mrHelpOemBody, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: openAppSettings,
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            icon: const Icon(Icons.settings_outlined),
            label: Text(l10n.mrOpenSettings),
          ),
        ],
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  const _HelpSection({required this.title, required this.steps});

  final String title;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: theme.colorScheme.primary,
                      child: Text('${i + 1}',
                          style: TextStyle(
                              fontSize: 13, color: theme.colorScheme.onPrimary)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(steps[i], style: theme.textTheme.bodyMedium)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
