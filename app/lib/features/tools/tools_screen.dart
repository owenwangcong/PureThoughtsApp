import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/gen/app_localizations.dart';

/// 工具集(PRD §9):打坐計時 / 念珠計數;匿名可用、离线可用。
class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.toolsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const Icon(Icons.self_improvement, size: 40),
              title: Text(l10n.timerTitle,
                  style: Theme.of(context).textTheme.titleLarge),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/tools/timer'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const Icon(Icons.radio_button_checked, size: 40),
              title: Text(l10n.counterTitle,
                  style: Theme.of(context).textTheme.titleLarge),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/tools/counter'),
            ),
          ),
        ],
      ),
    );
  }
}
