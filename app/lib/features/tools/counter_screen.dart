import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/prefs.dart';
import '../../l10n/gen/app_localizations.dart';
import 'bell.dart';
import 'report_bridge.dart';

/// 念珠計數(PRD §9.2):全屏点按 +1(仅屏幕按钮,不用音量键)、
/// 每满一串(默认 108,可选)震动+磬声提示、可常亮、可清零、一键转报数。
/// 计数本地持久化,误退不丢。
class CounterScreen extends ConsumerStatefulWidget {
  const CounterScreen({super.key});

  @override
  ConsumerState<CounterScreen> createState() => _CounterScreenState();
}

class _CounterScreenState extends ConsumerState<CounterScreen> {
  static const _countKey = 'counter_count';
  static const _targetKey = 'counter_target';
  static const _soundKey = 'counter_sound';

  var _count = 0;
  var _target = 108;
  var _sound = true;
  var _awake = true;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPrefsProvider);
    _count = prefs.getInt(_countKey) ?? 0;
    _target = prefs.getInt(_targetKey) ?? 108;
    _sound = prefs.getBool(_soundKey) ?? true;
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  void _tap() {
    setState(() => _count++);
    ref.read(sharedPrefsProvider).setInt(_countKey, _count);
    if (_target > 0 && _count % _target == 0) {
      // 整串:重震动 + 磬声(可关)
      HapticFeedback.heavyImpact();
      if (_sound) BellService.instance.strike();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _reset() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.confirmReset),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, true), child: Text(l10n.submit)),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _count = 0);
    ref.read(sharedPrefsProvider).setInt(_countKey, 0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final rounds = _target > 0 ? _count ~/ _target : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.counterTitle),
        actions: [
          IconButton(
            tooltip: l10n.resetCount,
            icon: const Icon(Icons.restart_alt),
            onPressed: _count > 0 ? _reset : null,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'sound':
                  setState(() => _sound = !_sound);
                  ref.read(sharedPrefsProvider).setBool(_soundKey, _sound);
                case 'awake':
                  setState(() => _awake = !_awake);
                  _awake ? WakelockPlus.enable() : WakelockPlus.disable();
                default:
                  final t = int.tryParse(v);
                  if (t != null) {
                    setState(() => _target = t);
                    ref.read(sharedPrefsProvider).setInt(_targetKey, t);
                  }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                  value: 'sound',
                  child: Text('${l10n.soundToggle}: ${_sound ? '✓' : '✗'}')),
              PopupMenuItem(
                  value: 'awake',
                  child: Text('${l10n.keepAwake}: ${_awake ? '✓' : '✗'}')),
              const PopupMenuDivider(),
              for (final t in const [27, 54, 108, 1080])
                PopupMenuItem(
                    value: '$t',
                    child: Text('${l10n.beadsTarget}: $t${_target == t ? ' ✓' : ''}')),
            ],
          ),
        ],
      ),
      // 全屏点按区
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _tap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(
                '$_count',
                style: theme.textTheme.displayLarge?.copyWith(
                  fontSize: 96,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '${l10n.roundsLabel} $rounds · ${l10n.beadsTarget} $_target',
                style: theme.textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(l10n.tapToCount, style: theme.textTheme.bodySmall),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: OutlinedButton(
            onPressed: _count > 0
                ? () => toolResultToLog(context, ref,
                    quantity: _count.toDouble(), preferredCategory: 'buddha_name')
                : null,
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: Text('${l10n.toReport}($_count)'),
          ),
        ),
      ),
    );
  }
}
