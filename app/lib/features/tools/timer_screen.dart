import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../l10n/gen/app_localizations.dart';
import 'bell.dart';
import 'report_bridge.dart';

/// 打坐計時(PRD §9.1):预备铃 / 中途铃(即"定点发声正念提醒",PRD §9.3)/
/// 结束铃(三声);计时中保持屏幕常亮;结束可一键转打坐报数。
/// 注:计时在前台运行,请保持 App 打开。
class TimerScreen extends ConsumerStatefulWidget {
  const TimerScreen({super.key});

  @override
  ConsumerState<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends ConsumerState<TimerScreen> {
  var _minutes = 20;
  var _intervalMinutes = 0; // 0 = 关
  var _prepBell = true;
  Timer? _timer;
  Duration _remaining = Duration.zero;
  var _running = false;
  var _finished = false;

  @override
  void dispose() {
    _timer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _running = true;
      _finished = false;
      _remaining = Duration(minutes: _minutes);
    });
    await WakelockPlus.enable();
    if (_prepBell) BellService.instance.strike();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining.inSeconds <= 1) {
        t.cancel();
        WakelockPlus.disable();
        BellService.instance.strike(3);
        setState(() {
          _remaining = Duration.zero;
          _running = false;
          _finished = true;
        });
        return;
      }
      final next = _remaining - const Duration(seconds: 1);
      // 中途铃:每 X 分钟一声(不与结束重合)
      if (_intervalMinutes > 0 &&
          next.inSeconds > 0 &&
          next.inSeconds % (_intervalMinutes * 60) == 0) {
        BellService.instance.strike();
      }
      setState(() => _remaining = next);
    });
  }

  void _stop() {
    _timer?.cancel();
    WakelockPlus.disable();
    setState(() {
      _running = false;
      _finished = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.timerTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _running || _finished
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Text(
                      _finished ? l10n.timeUp : formatMmSs(_remaining),
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  if (_running)
                    OutlinedButton(
                      onPressed: _stop,
                      style:
                          OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                      child: Text(l10n.stopTimer),
                    ),
                  if (_finished) ...[
                    FilledButton(
                      onPressed: () => toolResultToLog(context, ref,
                          quantity: _minutes.toDouble(),
                          preferredCategory: 'meditation'),
                      style:
                          FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                      child: Text('${l10n.toReport}($_minutes ${l10n.unitMinute})'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => setState(() => _finished = false),
                      style:
                          OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                      child: Text(l10n.done),
                    ),
                  ],
                ],
              )
            : ListView(
                children: [
                  Text(l10n.vowPeriod, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in const [5, 10, 15, 20, 30, 45, 60])
                        ChoiceChip(
                          label: Text('$m ${l10n.unitMinute}'),
                          selected: _minutes == m,
                          onSelected: (_) => setState(() => _minutes = m),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(l10n.intervalBell, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final m in const [0, 5, 10, 15])
                        ChoiceChip(
                          label: Text(m == 0 ? l10n.offLabel : '$m ${l10n.unitMinute}'),
                          selected: _intervalMinutes == m,
                          onSelected: (_) => setState(() => _intervalMinutes = m),
                        ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.prepBell),
                    value: _prepBell,
                    onChanged: (v) => setState(() => _prepBell = v),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _start,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(64)),
                    child: Text(l10n.startTimer,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(color: theme.colorScheme.onPrimary)),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(l10n.keepForeground,
                        style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
      ),
    );
  }
}
