// 活动重复展开的纯逻辑(PRD §5:循环模板 + 单次修改),独立成文件便于单测。
// v1 支持 RRULE 子集:null(单次)/ FREQ=WEEKLY(每周,按 start_at 的星期几)。
// override patch 支持:{"cancelled": true} / {"start_at": "<ISO>"}(单次改期)。

class Occurrence {
  const Occurrence({
    required this.event,
    required this.startAt,
    required this.dateKey,
    required this.cancelled,
  });

  final Map<String, dynamic> event;

  /// 本次发生的本地开始时间(已应用改期 override)
  final DateTime startAt;

  /// override 键(原定发生日的本地日期,yyyy-MM-dd)
  final String dateKey;

  final bool cancelled;
}

String dateKeyOf(DateTime local) =>
    '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';

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

  for (final e in events) {
    final first = DateTime.parse(e['start_at'] as String).toLocal();
    final rule = e['recurrence_rule'] as String?;

    Iterable<DateTime> starts;
    if (rule == null || rule.isEmpty) {
      starts = [first];
    } else if (rule.toUpperCase().contains('FREQ=WEEKLY')) {
      // 从首次发生起,每 7 天一次,直到范围结束
      starts = () sync* {
        var t = first;
        // 快进到范围附近,避免逐周遍历多年
        if (t.isBefore(start)) {
          final weeks = start.difference(t).inDays ~/ 7;
          t = t.add(Duration(days: weeks * 7));
        }
        while (t.isBefore(endExclusive)) {
          yield t;
          t = t.add(const Duration(days: 7));
        }
      }();
    } else {
      starts = [first]; // 未支持的规则按单次处理
    }

    for (final s in starts) {
      if (s.isBefore(start) || !s.isBefore(endExclusive)) continue;
      final key = dateKeyOf(s);
      final patch = patchOf['${e['id']}|$key'];
      final cancelled = patch?['cancelled'] == true;
      final movedTo = patch?['start_at'] as String?;
      out.add(Occurrence(
        event: e,
        startAt: movedTo != null ? DateTime.parse(movedTo).toLocal() : s,
        dateKey: key,
        cancelled: cancelled,
      ));
    }
  }
  out.sort((a, b) => a.startAt.compareTo(b.startAt));
  return out;
}
