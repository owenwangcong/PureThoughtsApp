import 'package:flutter_test/flutter_test.dart';
import 'package:pure_thoughts/features/dashboard/dashboard_providers.dart';

void main() {
  final today = DateTime(2026, 7, 7);
  String d(int daysAgo) {
    final x = today.subtract(Duration(days: daysAgo));
    return '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
  }

  group('连续用功天数 calcStreak', () {
    test('无记录 → 0', () {
      expect(calcStreak(const [], today), 0);
    });

    test('今天有报 → 从今天往回连续计数', () {
      expect(calcStreak([d(0), d(1), d(2)], today), 3);
    });

    test('今天未报不算中断,从昨天起算(温和处理)', () {
      expect(calcStreak([d(1), d(2), d(3)], today), 3);
    });

    test('断档即止', () {
      expect(calcStreak([d(0), d(1), d(3), d(4)], today), 2);
    });

    test('前天报过但昨天今天没报 → 0', () {
      expect(calcStreak([d(2), d(3)], today), 0);
    });

    test('重复日期(多群/多功课同日)只算一天', () {
      expect(calcStreak([d(0), d(0), d(1), d(1)], today), 2);
    });
  });
}
