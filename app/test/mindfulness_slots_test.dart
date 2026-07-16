import 'package:flutter_test/flutter_test.dart';
import 'package:pure_thoughts/features/reminders/mindfulness_model.dart';

void main() {
  MindfulnessSchedule sched({
    bool enabled = true,
    Set<int>? weekdays,
    int start = 8 * 60,
    int end = 9 * 60,
    int interval = 30,
  }) =>
      MindfulnessSchedule(
        enabled: enabled,
        weekdays: weekdays ?? {1, 2, 3, 4, 5, 6, 7},
        startMinutes: start,
        endMinutes: end,
        intervalMinutes: interval,
        sound: 'bell',
        vibrate: true,
      );

  group('dailyTimes 单日展开', () {
    test('整除:8:00–9:00 每 30 分 → 8:00 8:30 9:00', () {
      expect(dailyTimes(480, 540, 30), [480, 510, 540]);
    });

    test('不整除:最后一次 ≤end 即止(8:00–9:00 每 40 分 → 8:00 8:40)', () {
      expect(dailyTimes(480, 540, 40), [480, 520]);
    });

    test('窗口非法(end ≤ start)返回空', () {
      expect(dailyTimes(540, 540, 30), isEmpty);
      expect(dailyTimes(540, 480, 30), isEmpty);
    });

    test('间隔 ≤0 返回空', () {
      expect(dailyTimes(480, 540, 0), isEmpty);
    });
  });

  group('expandSlots 槽位展开', () {
    test('周几 × 每日次数;槽位含正确 weekday 与时刻', () {
      final s = sched(weekdays: {1, 3}, start: 480, end: 540, interval: 30); // 3 次/天
      final slots = expandSlots(s);
      expect(slots.length, 6); // 2 天 × 3 次
      // 按周几升序、日内时刻升序
      expect(slots.first, const ReminderSlot(1, 480));
      expect(slots[2], const ReminderSlot(1, 540));
      expect(slots[3], const ReminderSlot(3, 480));
      expect(slots.last, const ReminderSlot(3, 540));
    });

    test('槽位 hour/minute 拆分正确', () {
      const slot = ReminderSlot(2, 8 * 60 + 30);
      expect(slot.hour, 8);
      expect(slot.minute, 30);
    });

    test('关闭时返回空', () {
      expect(expandSlots(sched(enabled: false)), isEmpty);
    });

    test('窗口非法时返回空(结束不晚于开始)', () {
      expect(expandSlots(sched(start: 540, end: 540)), isEmpty);
      expect(expandSlots(sched(start: 600, end: 540)), isEmpty);
    });
  });

  group('iOS 64 上限判定', () {
    test('默认配置(9:00–17:00 每 60 分 × 7 天 = 63)不超限', () {
      final s = MindfulnessSchedule.defaults().copyWith(enabled: true);
      expect(weeklySlotCount(s), 63);
      expect(exceedsIosCap(s), isFalse);
    });

    test('每 30 分 9:00–18:00 × 7 天 = 133 超限', () {
      final s = sched(start: 9 * 60, end: 18 * 60, interval: 30); // 19 次/天
      expect(dailyCount(s), 19);
      expect(weeklySlotCount(s), 133);
      expect(exceedsIosCap(s), isTrue);
    });

    test('恰好 64 不算超限;65 超限', () {
      // 8 天不可能,构造 64:每日 8 次 × 8 天不行 → 用 1 天 64 次
      // 1 天:间隔 10 分,窗口 0:00 起 63×10=630 分 → 9:00:00..? 用 start=0,end=630,interval=10 → 64 次
      final s64 = sched(weekdays: {1}, start: 0, end: 630, interval: 10);
      expect(dailyCount(s64), 64);
      expect(exceedsIosCap(s64), isFalse);
      final s65 = sched(weekdays: {1}, start: 0, end: 640, interval: 10);
      expect(dailyCount(s65), 65);
      expect(exceedsIosCap(s65), isTrue);
    });
  });

  group('JSON 往返', () {
    test('toJson/fromJson 保持字段一致', () {
      final s = sched(weekdays: {2, 4, 6}, start: 420, end: 1200, interval: 45)
          .copyWith(sound: 'silent', vibrate: false, message: '回到呼吸');
      final round = MindfulnessSchedule.fromJsonString(s.toJsonString());
      expect(round.enabled, s.enabled);
      expect(round.weekdays, s.weekdays);
      expect(round.startMinutes, 420);
      expect(round.endMinutes, 1200);
      expect(round.intervalMinutes, 45);
      expect(round.sound, 'silent');
      expect(round.vibrate, false);
      expect(round.message, '回到呼吸');
    });

    test('缺字段时回落默认值', () {
      final s = MindfulnessSchedule.fromJson({'enabled': true});
      final d = MindfulnessSchedule.defaults();
      expect(s.enabled, true);
      expect(s.weekdays, d.weekdays);
      expect(s.intervalMinutes, d.intervalMinutes);
      expect(s.message, isNull);
    });
  });

  group('copyWith', () {
    test('clearMessage 置空文案', () {
      final s = sched().copyWith(message: 'x');
      expect(s.copyWith(clearMessage: true).message, isNull);
    });

    test('isWindowValid 校验', () {
      expect(sched(start: 480, end: 540).isWindowValid, isTrue);
      expect(sched(start: 540, end: 540).isWindowValid, isFalse);
      expect(sched(start: 600, end: 540).isWindowValid, isFalse);
    });
  });
}
