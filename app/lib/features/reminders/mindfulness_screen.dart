import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../l10n/gen/app_localizations.dart';
import '../tools/bell.dart';
import 'mindfulness_controller.dart';
import 'mindfulness_model.dart';

/// 正念提醒设置页(PRD §9.3 / design §7)。
/// 周几 × 时间窗 × 间隔 → OS 级本地通知;关 App/息屏也能响(iOS ≤64)。
class MindfulnessScreen extends ConsumerStatefulWidget {
  const MindfulnessScreen({super.key});

  @override
  ConsumerState<MindfulnessScreen> createState() => _MindfulnessScreenState();
}

class _MindfulnessScreenState extends ConsumerState<MindfulnessScreen> {
  bool? _permGranted; // null=未知/未开启功能

  @override
  void initState() {
    super.initState();
    _refreshPermission();
  }

  Future<void> _refreshPermission() async {
    final ok = await ref.read(reminderSchedulerProvider).hasPermission();
    if (mounted) setState(() => _permGranted = ok);
  }

  String _effectiveBody(AppLocalizations l10n, MindfulnessSchedule s) {
    final m = s.message?.trim();
    return (m == null || m.isEmpty) ? l10n.mrMessageDefault : m;
  }

  /// 持久化 + 重排(本地化文案在此解析后传入 controller)。
  Future<void> _apply(MindfulnessSchedule s) async {
    final l10n = AppLocalizations.of(context);
    await ref.read(mindfulnessProvider.notifier).update(
          s,
          title: l10n.mrTitle,
          body: _effectiveBody(l10n, s),
          channelName: l10n.mrTitle,
          channelDescription: l10n.mrEnableHint,
        );
  }

  Future<void> _toggleEnabled(bool v, MindfulnessSchedule s) async {
    if (v) {
      final granted = await ref.read(reminderSchedulerProvider).requestPermissions();
      if (mounted) setState(() => _permGranted = granted);
      await _apply(s.copyWith(enabled: true));
      if (!granted && mounted) _snack(AppLocalizations.of(context).mrPermDenied, action: true);
    } else {
      await _apply(s.copyWith(enabled: false));
    }
  }

  Future<void> _pickTime(bool isStart, MindfulnessSchedule s) async {
    final cur = isStart ? s.startMinutes : s.endMinutes;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: cur ~/ 60, minute: cur % 60),
    );
    if (picked == null || !mounted) return;
    final mins = picked.hour * 60 + picked.minute;
    final next = isStart
        ? s.copyWith(startMinutes: mins)
        : s.copyWith(endMinutes: mins);
    if (!next.isWindowValid) {
      _snack(AppLocalizations.of(context).mrWindowInvalid);
      return;
    }
    await _apply(next);
  }

  Future<void> _editMessage(MindfulnessSchedule s) async {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController(text: s.message ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.mrMessage),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 40,
          decoration: InputDecoration(hintText: l10n.mrMessageDefault, helperText: l10n.mrMessageHint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.save)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final text = ctrl.text.trim();
    await _apply(text.isEmpty ? s.copyWith(clearMessage: true) : s.copyWith(message: text));
  }

  void _snack(String msg, {bool action = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      action: action
          ? SnackBarAction(
              label: AppLocalizations.of(context).mrGrant, onPressed: openAppSettings)
          : null,
    ));
  }

  String _fmt(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final s = ref.watch(mindfulnessProvider);
    final dayLabels = [
      l10n.mrDay1, l10n.mrDay2, l10n.mrDay3, l10n.mrDay4, l10n.mrDay5, l10n.mrDay6, l10n.mrDay7,
    ];
    final daily = dailyCount(s);
    final total = weeklySlotCount(s);
    final overCap = exceedsIosCap(s);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mrTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 权限失效提示(功能已开但系统未授通知)
          if (s.enabled && _permGranted == false)
            Card(
              color: theme.colorScheme.errorContainer,
              child: ListTile(
                leading: Icon(Icons.notifications_off, color: theme.colorScheme.onErrorContainer),
                title: Text(l10n.mrPermDenied,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer)),
                trailing: TextButton(onPressed: openAppSettings, child: Text(l10n.mrGrant)),
              ),
            ),
          // 总开关
          Card(
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              title: Text(l10n.mrEnable, style: theme.textTheme.titleMedium),
              subtitle: Text(l10n.mrEnableHint),
              value: s.enabled,
              onChanged: (v) => _toggleEnabled(v, s),
            ),
          ),
          if (s.enabled) ...[
            const SizedBox(height: 16),
            // 周几
            Text(l10n.mrWeekdays, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (var d = 1; d <= 7; d++)
                  FilterChip(
                    label: Text(dayLabels[d - 1]),
                    selected: s.weekdays.contains(d),
                    onSelected: (sel) {
                      final next = {...s.weekdays};
                      sel ? next.add(d) : next.remove(d);
                      _apply(s.copyWith(weekdays: next));
                    },
                  ),
              ],
            ),
            const SizedBox(height: 20),
            // 时间窗
            Row(
              children: [
                Expanded(
                  child: _TimeTile(
                    label: l10n.mrStart,
                    value: _fmt(s.startMinutes),
                    onTap: () => _pickTime(true, s),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeTile(
                    label: l10n.mrEnd,
                    value: _fmt(s.endMinutes),
                    onTap: () => _pickTime(false, s),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // 间隔
            Text(l10n.mrInterval, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in MindfulnessSchedule.intervalPresets)
                  ChoiceChip(
                    label: Text('$m ${l10n.unitMinute}'),
                    selected: s.intervalMinutes == m,
                    onSelected: (_) => _apply(s.copyWith(intervalMinutes: m)),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            // 提示音 + 震动 + 试听
            Text(l10n.mrSound, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                ChoiceChip(
                  label: Text(l10n.mrSoundBell),
                  selected: s.sound == 'bell',
                  onSelected: (_) => _apply(s.copyWith(sound: 'bell')),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(l10n.mrSoundSilent),
                  selected: s.sound == 'silent',
                  onSelected: (_) => _apply(s.copyWith(sound: 'silent')),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => BellService.instance.strike(),
                  icon: const Icon(Icons.volume_up),
                  label: Text(l10n.mrPreviewSound),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.mrVibrate),
              value: s.vibrate,
              onChanged: (v) => _apply(s.copyWith(vibrate: v)),
            ),
            const SizedBox(height: 8),
            // 提醒文案
            Card(
              child: ListTile(
                title: Text(l10n.mrMessage),
                subtitle: Text(_effectiveBody(l10n, s)),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _editMessage(s),
              ),
            ),
            const SizedBox(height: 12),
            // 实时槽位反馈
            Text(l10n.mrCountSummary(daily, total),
                style: theme.textTheme.bodyMedium),
            if (overCap) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber, size: 18, color: theme.colorScheme.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.mrIosCapWarning(MindfulnessSchedule.iosSlotCap, total),
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(l10n.mrRespectSilent, style: theme.textTheme.bodySmall),
            const SizedBox(height: 20),
            // 立即测试
            OutlinedButton.icon(
              onPressed: () async {
                await ref.read(reminderSchedulerProvider).showTest(
                      s,
                      title: l10n.mrTitle,
                      body: _effectiveBody(l10n, s),
                      channelName: l10n.mrTitle,
                      channelDescription: l10n.mrEnableHint,
                    );
                _snack(l10n.mrTestSent);
              },
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              icon: const Icon(Icons.notifications_active_outlined),
              label: Text(l10n.mrTest),
            ),
          ],
          const SizedBox(height: 12),
          // 设置帮助(双端引导)
          Card(
            child: ListTile(
              leading: const Icon(Icons.help_outline),
              title: Text(l10n.mrHelp),
              subtitle: Text(l10n.mrHelpSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/tools/mindfulness/help'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(64),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          Text(value, style: theme.textTheme.titleLarge),
        ],
      ),
    );
  }
}
