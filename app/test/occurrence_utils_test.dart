import 'package:flutter_test/flutter_test.dart';
import 'package:pure_thoughts/features/events/occurrence_utils.dart';

void main() {
  Map<String, dynamic> event(String id, String startAtUtc, {String? rule}) => {
        'id': id,
        'title': 'e$id',
        'type': 'group_practice',
        'start_at': startAtUtc,
        'recurrence_rule': rule,
      };

  group('活动展开 expandOccurrences', () {
    test('单次活动只出现一次且在范围内', () {
      final occ = expandOccurrences(
        events: [event('1', '2026-07-11T11:30:00Z')],
        overrides: const [],
        rangeStart: DateTime(2026, 7, 1),
        rangeEnd: DateTime(2026, 7, 31),
      );
      expect(occ.length, 1);
      expect(occ.single.cancelled, false);
    });

    test('每周循环在一个月内出现 4-5 次,且从首次快进不漂移', () {
      final occ = expandOccurrences(
        events: [event('1', '2026-01-03T11:30:00Z', rule: 'FREQ=WEEKLY')],
        overrides: const [],
        rangeStart: DateTime(2026, 7, 1),
        rangeEnd: DateTime(2026, 7, 31),
      );
      expect(occ.length, inInclusiveRange(4, 5));
      // 所有发生与首次同星期几
      final weekday = DateTime.parse('2026-01-03T11:30:00Z').toLocal().weekday;
      for (final o in occ) {
        expect(o.startAt.weekday, weekday);
      }
    });

    test('override 取消单次', () {
      final all = expandOccurrences(
        events: [event('1', '2026-07-04T11:30:00Z', rule: 'FREQ=WEEKLY')],
        overrides: const [],
        rangeStart: DateTime(2026, 7, 1),
        rangeEnd: DateTime(2026, 7, 31),
      );
      final key = all.first.dateKey;
      final occ = expandOccurrences(
        events: [event('1', '2026-07-04T11:30:00Z', rule: 'FREQ=WEEKLY')],
        overrides: [
          {
            'event_id': '1',
            'occurrence_date': key,
            'patch': {'cancelled': true},
          }
        ],
        rangeStart: DateTime(2026, 7, 1),
        rangeEnd: DateTime(2026, 7, 31),
      );
      expect(occ.where((o) => o.cancelled).length, 1);
      expect(occ.where((o) => o.cancelled).single.dateKey, key);
    });

    test('override 单次改期', () {
      final all = expandOccurrences(
        events: [event('1', '2026-07-04T11:30:00Z', rule: 'FREQ=WEEKLY')],
        overrides: const [],
        rangeStart: DateTime(2026, 7, 1),
        rangeEnd: DateTime(2026, 7, 31),
      );
      final key = all.first.dateKey;
      final occ = expandOccurrences(
        events: [event('1', '2026-07-04T11:30:00Z', rule: 'FREQ=WEEKLY')],
        overrides: [
          {
            'event_id': '1',
            'occurrence_date': key,
            'patch': {'start_at': '2026-07-06T02:00:00Z'},
          }
        ],
        rangeStart: DateTime(2026, 7, 1),
        rangeEnd: DateTime(2026, 7, 31),
      );
      final moved = occ.firstWhere((o) => o.dateKey == key);
      expect(moved.startAt, DateTime.parse('2026-07-06T02:00:00Z').toLocal());
    });

    test('范围外的活动不出现', () {
      final occ = expandOccurrences(
        events: [event('1', '2026-08-01T11:30:00Z')],
        overrides: const [],
        rangeStart: DateTime(2026, 7, 1),
        rangeEnd: DateTime(2026, 7, 31),
      );
      expect(occ, isEmpty);
    });
  });

  group('日历格子图标 dayMarkerIconKeys', () {
    // 三种类型 → 三种图标 key
    final typeById = <String, Map<String, dynamic>>{
      'meditate': {'id': 'meditate', 'icon': 'self_improvement'},
      'talk': {'id': 'talk', 'icon': 'record_voice_over'},
      'noicon': {'id': 'noicon'}, // 缺 icon → 回退 event
    };

    Occurrence occ(String typeId, {bool cancelled = false}) => Occurrence(
          event: {'id': 'e', 'event_type_id': typeId},
          startAt: DateTime(2026, 7, 11, 9),
          dateKey: '2026-07-11',
          cancelled: cancelled,
        );

    test('单场 → 一个对应图标', () {
      expect(dayMarkerIconKeys([occ('meditate')], typeById), ['self_improvement']);
    });

    test('同类型多场 → 去重成一个', () {
      expect(
        dayMarkerIconKeys([occ('meditate'), occ('meditate')], typeById),
        ['self_improvement'],
      );
    });

    test('不同类型 → 保序多个图标', () {
      expect(
        dayMarkerIconKeys([occ('meditate'), occ('talk')], typeById),
        ['self_improvement', 'record_voice_over'],
      );
    });

    test('已取消的场次跳过', () {
      expect(
        dayMarkerIconKeys([occ('meditate', cancelled: true), occ('talk')], typeById),
        ['record_voice_over'],
      );
    });

    test('类型缺图标 → 回退 event', () {
      expect(dayMarkerIconKeys([occ('noicon')], typeById), ['event']);
    });

    test('超过上限截断', () {
      final many = [occ('meditate'), occ('talk'), occ('noicon')];
      expect(dayMarkerIconKeys(many, typeById, max: 2).length, 2);
    });

    test('无场次 → 空', () {
      expect(dayMarkerIconKeys(const [], typeById), isEmpty);
    });
  });
}
