import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/prefs.dart';
import '../../l10n/gen/app_localizations.dart';
import 'bell.dart';
import 'report_bridge.dart';

/// 打坐計時(PRD §9.1):时长预设 + **自訂任意时长**(1 分钟 ~ 12 小时);
/// 预备铃 / 中途铃(即"定点发声正念提醒",PRD §9.3)/ 结束铃(三声);
/// 计时中保持屏幕常亮;结束可一键转打坐报数。
/// 注:计时在前台运行,请保持 App 打开。
class TimerScreen extends ConsumerStatefulWidget {
  const TimerScreen({super.key});

  @override
  ConsumerState<TimerScreen> createState() => _TimerScreenState();
}

/// 时长预设(分钟);不在此列的一律视为自訂
const _presetMinutes = [5, 10, 15, 20, 30, 45, 60];

/// 自訂时长上限:12 小时(打坐/闭关够用,滚轮小时列 0–12)
const _maxHours = 12;

class _TimerScreenState extends ConsumerState<TimerScreen> {
  static const _minutesKey = 'timer_minutes';

  var _minutes = 20;
  var _intervalMinutes = 0; // 0 = 关
  var _prepBell = true;
  Timer? _timer;
  Duration _remaining = Duration.zero;
  var _running = false;
  var _finished = false;

  @override
  void initState() {
    super.initState();
    // 记住上次时长(自訂值尤其需要,免得每次重设)
    final saved = ref.read(sharedPrefsProvider).getInt(_minutesKey);
    if (saved != null && saved > 0 && saved <= _maxHours * 60) {
      _minutes = saved;
    }
  }

  void _setMinutes(int m) {
    setState(() => _minutes = m);
    ref.read(sharedPrefsProvider).setInt(_minutesKey, m);
  }

  /// 自訂时长:时 / 分双滚轮(不用键盘,避免长者误输)
  Future<void> _pickCustom() async {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    var hours = _minutes ~/ 60;
    var mins = _minutes % 60;
    final hourCtrl = FixedExtentScrollController(initialItem: hours);
    final minCtrl = FixedExtentScrollController(initialItem: mins);
    // 大字号下加高行距,避免滚轮项文字被裁切
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    final extent = 44.0 * scale;

    final picked = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInner) {
          final total = hours * 60 + mins;
          return AlertDialog(
            title: Text(l10n.customDurationTitle),
            content: SizedBox(
              width: 280,
              height: extent * 4 + 40,
              child: Column(
                children: [
                  Text(
                    total > 0
                        ? formatMinutesLabel(total,
                            hourUnit: l10n.unitHour, minuteUnit: l10n.unitMinute)
                        : '—',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _wheel(
                            controller: hourCtrl,
                            count: _maxHours + 1,
                            unit: l10n.unitHour,
                            extent: extent,
                            onChanged: (v) => setInner(() => hours = v),
                          ),
                        ),
                        Expanded(
                          child: _wheel(
                            controller: minCtrl,
                            count: 60,
                            unit: l10n.unitMinute,
                            extent: extent,
                            onChanged: (v) => setInner(() => mins = v),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: total > 0 ? () => Navigator.pop(context, total) : null,
                child: Text(l10n.done),
              ),
            ],
          );
        },
      ),
    );
    hourCtrl.dispose();
    minCtrl.dispose();
    if (picked != null) _setMinutes(picked);
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int count,
    required String unit,
    required double extent,
    required ValueChanged<int> onChanged,
  }) {
    return CupertinoPicker(
      scrollController: controller,
      itemExtent: extent,
      backgroundColor: Colors.transparent,
      squeeze: 1.1,
      onSelectedItemChanged: onChanged,
      children: [
        for (var i = 0; i < count; i++)
          Center(
            child: Text('$i $unit',
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
      ],
    );
  }

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
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _finished ? l10n.timeUp : formatHms(_remaining),
                        style: theme.textTheme.displayLarge?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
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
                      child: Text('${l10n.toReport}'
                          '(${formatMinutesLabel(_minutes, hourUnit: l10n.unitHour, minuteUnit: l10n.unitMinute)})'),
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
                  Text(l10n.timerDuration, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in _presetMinutes)
                        ChoiceChip(
                          label: Text('$m ${l10n.unitMinute}'),
                          selected: _minutes == m,
                          onSelected: (_) => _setMinutes(m),
                        ),
                      // 自訂:任意时长(1 分钟 ~ 12 小时);选中时直接显示当前值
                      ChoiceChip(
                        label: Text(_presetMinutes.contains(_minutes)
                            ? l10n.customDuration
                            : formatMinutesLabel(_minutes,
                                hourUnit: l10n.unitHour,
                                minuteUnit: l10n.unitMinute)),
                        avatar: const Icon(Icons.edit_outlined, size: 18),
                        selected: !_presetMinutes.contains(_minutes),
                        onSelected: (_) => _pickCustom(),
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
