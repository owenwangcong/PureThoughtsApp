import 'package:just_audio/just_audio.dart';

/// 磬声服务(合成磬声资产;真实磬声等 Epic 5 内容方音频到位后可替换)。
/// 结束铃按惯例连击三声。
class BellService {
  BellService._();
  static final instance = BellService._();

  final _player = AudioPlayer();
  var _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    await _player.setAsset('assets/audio/bell.wav');
    _loaded = true;
  }

  /// 敲 [strikes] 声(间隔约 1.8s)
  Future<void> strike([int strikes = 1]) async {
    try {
      await _ensureLoaded();
      for (var i = 0; i < strikes; i++) {
        await _player.seek(Duration.zero);
        _player.play();
        if (i < strikes - 1) {
          await Future<void>.delayed(const Duration(milliseconds: 1800));
        }
      }
    } catch (_) {
      // 音频不可用时静默(工具仍可用)
    }
  }

  void dispose() => _player.dispose();
}

/// mm:ss 显示
String formatMmSs(Duration d) {
  final m = d.inMinutes.toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// 倒计时显示:≥1 小时用 h:mm:ss,否则 mm:ss(自订时长可长达 12 小时,PRD §9.1)
String formatHms(Duration d) {
  if (d.inHours < 1) return formatMmSs(d);
  final h = d.inHours.toString();
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$h:$m:$s';
}

/// 分钟数 → 可读时长标签:75 →「1 小時 15 分鐘」、60 →「1 小時」、45 →「45 分鐘」
String formatMinutesLabel(
  int minutes, {
  required String hourUnit,
  required String minuteUnit,
}) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m $minuteUnit';
  if (m == 0) return '$h $hourUnit';
  return '$h $hourUnit $m $minuteUnit';
}
