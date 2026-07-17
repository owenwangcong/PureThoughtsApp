// 活动重复展开的纯逻辑(PRD §5:循环模板 + 单次修改),独立成文件便于单测。
// v1 支持 RRULE 子集:null(单次)/ FREQ=WEEKLY(每周,按 start_at 的星期几)。
// override patch 支持:{"cancelled": true} / {"start_at": "<ISO>"}(单次改期)。
//
// v0.5.15 时区改造:每周循环在**活动时区**(events.timezone)做日历算术展开,
// 跨夏令时保持活动当地墙钟时间不变(修复原「+7×24h」在 DST 切换后漂移 1 小时);
// 存量活动默认 Asia/Shanghai(无 DST),行为与旧实现完全一致。
// override 键(dateKey)= 发生日在**活动时区**的日期,全球用户一致。

import 'package:timezone/timezone.dart' as tz;

import '../../core/timezones.dart';

class Occurrence {
  const Occurrence({
    required this.event,
    required this.startAt,
    required this.dateKey,
    required this.cancelled,
  });

  final Map<String, dynamic> event;

  /// 本次发生的开始时间,已换算到**设备本地时区**显示(已应用改期 override)
  final DateTime startAt;

  /// override 键(原定发生日在**活动时区**的日期,yyyy-MM-dd,全球一致)
  final String dateKey;

  final bool cancelled;
}

String dateKeyOf(DateTime local) =>
    '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';

/// 换算到设备本地时区(经 epoch,走 Dart 原生本地时钟)。
/// ⚠️ 不能用 TZDateTime.toLocal():它返回的是 timezone 包全局 `tz.local`,
/// 默认 UTC、依赖启动时 setLocalLocation 成功——初始化失败的设备整个日历会按 UTC 显示。
DateTime _deviceLocal(DateTime d) =>
    DateTime.fromMillisecondsSinceEpoch(d.millisecondsSinceEpoch);

/// 某天多场活动 → 去重后的类型「图标 key」列表,保序、最多 [max] 个。
/// 用于月视图格子上以类型图标代替圆点(PRD §5「不同类型在日历中显示不同图标」)。
/// - 跳过已取消的场次(不在格子上宣告);
/// - 同类型只取一个图标;类型缺图标时回退 `'event'`。
List<String> dayMarkerIconKeys(
  Iterable<Occurrence> occurrences,
  Map<String, Map<String, dynamic>> typeById, {
  int max = 3,
}) {
  final out = <String>[];
  final seen = <String>{};
  for (final o in occurrences) {
    if (o.cancelled) continue;
    final key =
        (typeById[o.event['event_type_id']]?['icon'] as String?) ?? 'event';
    if (seen.add(key)) out.add(key);
    if (out.length >= max) break;
  }
  return out;
}

/// 展开 [rangeStart, rangeEnd](本地日期,含端点)内的全部活动发生
List<Occurrence> expandOccurrences({
  required List<Map<String, dynamic>> events,
  required List<Map<String, dynamic>> overrides,
  required DateTime rangeStart,
  required DateTime rangeEnd,
}) {
  final patchOf = <String, Map<String, dynamic>>{
    for (final o in overrides)
      '${o['event_id']}|${o['occurrence_date']}': (o['patch'] as Map).cast<String, dynamic>(),
  };

  final out = <Occurrence>[];
  final endExclusive = DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day)
      .add(const Duration(days: 1));
  final start = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);

  ensureTimeZonesInitialized();
  for (final e in events) {
    final loc = locationOf(e['timezone'] as String? ?? 'Asia/Shanghai');
    final first =
        tz.TZDateTime.from(DateTime.parse(e['start_at'] as String), loc);
    final rule = e['recurrence_rule'] as String?;

    Iterable<tz.TZDateTime> starts;
    if (rule == null || rule.isEmpty) {
      starts = [first];
    } else if (rule.toUpperCase().contains('FREQ=WEEKLY')) {
      // 在活动时区按「+7 个日历日」逐周生成(墙钟不变);按序号生成避免累计漂移
      starts = () sync* {
        var i = 0;
        final firstLocal = _deviceLocal(first);
        if (firstLocal.isBefore(start)) {
          // 快进到范围附近(留 2 周余量),避免逐周遍历多年
          i = start.difference(firstLocal).inDays ~/ 7 - 2;
          if (i < 0) i = 0;
        }
        while (true) {
          final t = tz.TZDateTime(loc, first.year, first.month,
              first.day + 7 * i, first.hour, first.minute);
          if (!_deviceLocal(t).isBefore(endExclusive)) break;
          yield t;
          i++;
        }
      }();
    } else {
      starts = [first]; // 未支持的规则按单次处理
    }

    for (final s in starts) {
      final local = _deviceLocal(s); // 设备本地时间(显示与范围过滤口径)
      if (local.isBefore(start) || !local.isBefore(endExclusive)) continue;
      final key = dateKeyOf(s); // TZDateTime 的日期分量 = 活动时区日期
      final patch = patchOf['${e['id']}|$key'];
      final cancelled = patch?['cancelled'] == true;
      final movedTo = patch?['start_at'] as String?;
      out.add(Occurrence(
        event: e,
        startAt: movedTo != null ? DateTime.parse(movedTo).toLocal() : local,
        dateKey: key,
        cancelled: cancelled,
      ));
    }
  }
  out.sort((a, b) => a.startAt.compareTo(b.startAt));
  return out;
}
