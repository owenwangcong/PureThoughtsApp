import 'package:flutter_test/flutter_test.dart';
import 'package:pure_thoughts/core/timezones.dart';
import 'package:pure_thoughts/features/events/occurrence_utils.dart';
import 'package:timezone/timezone.dart' as tz;

/// P2.10 时区展开:每周循环在活动时区做日历算术,跨 DST 保持当地墙钟不变
/// (原「+7×24h」实现会在夏令时切换后漂移 1 小时);存量 Asia/Shanghai 无回归。
void main() {
  setUpAll(ensureTimeZonesInitialized);

  Map<String, dynamic> event(String startAtUtc, String timezone,
          {String? rule}) =>
      {
        'id': '1',
        'title': 'e1',
        'start_at': startAtUtc,
        'timezone': timezone,
        'recurrence_rule': rule,
      };

  test('洛杉矶每周活动跨春季 DST(2026-03-08)当地始终 19:00', () {
    // 2026-02-07 19:00 洛杉矶(PST,UTC-8)= 2026-02-08T03:00Z
    final occ = expandOccurrences(
      events: [
        event('2026-02-08T03:00:00Z', 'America/Los_Angeles',
            rule: 'FREQ=WEEKLY')
      ],
      overrides: const [],
      rangeStart: DateTime(2026, 3, 1),
      rangeEnd: DateTime(2026, 3, 31),
    );
    expect(occ.length, inInclusiveRange(4, 5));
    final la = tz.getLocation('America/Los_Angeles');
    for (final o in occ) {
      final wall = tz.TZDateTime.from(o.startAt, la);
      expect(wall.hour, 19, reason: 'DST 切换后当地墙钟不得漂移($wall)');
      expect(wall.minute, 0);
      expect(wall.weekday, DateTime.saturday);
    }
    // 3/8 春季拨快后,UTC 时刻应从 03:00Z 变为 02:00Z(墙钟不变的证据)
    final utcHours = {
      for (final o in occ) o.startAt.toUtc().hour,
    };
    expect(utcHours, {3, 2});
  });

  test('秋季 DST(2026-11-01)同样墙钟不变', () {
    // 2026-10-24 19:00 洛杉矶(PDT,UTC-7)= 2026-10-25T02:00Z
    final occ = expandOccurrences(
      events: [
        event('2026-10-25T02:00:00Z', 'America/Los_Angeles',
            rule: 'FREQ=WEEKLY')
      ],
      overrides: const [],
      rangeStart: DateTime(2026, 10, 24),
      rangeEnd: DateTime(2026, 11, 30),
    );
    final la = tz.getLocation('America/Los_Angeles');
    for (final o in occ) {
      expect(tz.TZDateTime.from(o.startAt, la).hour, 19);
    }
  });

  test('Asia/Shanghai(无 DST)每周严格 +168 小时,与旧实现一致', () {
    final occ = expandOccurrences(
      events: [
        event('2026-01-03T11:30:00Z', 'Asia/Shanghai', rule: 'FREQ=WEEKLY')
      ],
      overrides: const [],
      rangeStart: DateTime(2026, 7, 1),
      rangeEnd: DateTime(2026, 7, 31),
    );
    expect(occ.length, greaterThanOrEqualTo(4));
    for (var i = 1; i < occ.length; i++) {
      expect(occ[i].startAt.difference(occ[i - 1].startAt).inHours, 168);
    }
  });

  test('事件缺 timezone 字段回退 Asia/Shanghai(存量兼容)', () {
    final occ = expandOccurrences(
      events: [
        {
          'id': '1',
          'title': 'legacy',
          'start_at': '2026-07-11T11:30:00Z',
          'recurrence_rule': null,
        }
      ],
      overrides: const [],
      rangeStart: DateTime(2026, 7, 1),
      rangeEnd: DateTime(2026, 7, 31),
    );
    expect(occ.length, 1);
    // 2026-07-11T11:30Z = 上海 19:30,dateKey 取活动时区日期
    expect(occ.single.dateKey, '2026-07-11');
  });

  test('dateKey 用活动时区日期:跨日活动全球用户键一致', () {
    // 洛杉矶 2026-07-11 19:00(= 2026-07-12T02:00Z):键应是洛杉矶的 07-11
    final occ = expandOccurrences(
      events: [event('2026-07-12T02:00:00Z', 'America/Los_Angeles')],
      overrides: const [],
      rangeStart: DateTime(2026, 7, 1),
      rangeEnd: DateTime(2026, 7, 31),
    );
    expect(occ.single.dateKey, '2026-07-11');
  });
}
