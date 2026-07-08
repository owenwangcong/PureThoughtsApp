import 'package:flutter_test/flutter_test.dart';
import 'package:pure_thoughts/features/logs/batch_utils.dart';

void main() {
  const g1 = 'group-1';
  const g2 = 'group-2';

  Map<String, dynamic> log(String group, String type, num qty, String date) =>
      {'group_id': group, 'practice_type_id': type, 'quantity': qty, 'local_date': date};

  group('重複上次 latestBatch', () {
    test('取该群最近一天的组合,忽略其他群', () {
      final logs = [
        log(g1, 'jing', 1, '2026-07-07'), // 最新在前(created_at desc)
        log(g1, 'zhou', 108, '2026-07-07'),
        log(g2, 'chan', 9, '2026-07-07'),
        log(g1, 'zuo', 30, '2026-07-06'),
      ];
      expect(latestBatch(logs, g1), {'jing': 1, 'zhou': 108});
    });

    test('同日同功课多条取最新一条', () {
      final logs = [
        log(g1, 'jing', 3, '2026-07-07'),
        log(g1, 'jing', 1, '2026-07-07'),
      ];
      expect(latestBatch(logs, g1), {'jing': 3});
    });

    test('无记录返回空', () {
      expect(latestBatch([], g1), isEmpty);
      expect(latestBatch([log(g2, 'x', 1, '2026-07-07')], g1), isEmpty);
    });
  });

  group('常用功课 frequentTypeIds', () {
    test('去重保持最近优先,限制数量', () {
      final logs = [
        log(g1, 'a', 1, '2026-07-07'),
        log(g1, 'b', 1, '2026-07-07'),
        log(g1, 'a', 1, '2026-07-06'),
        log(g2, 'x', 1, '2026-07-06'),
        log(g1, 'c', 1, '2026-07-05'),
      ];
      expect(frequentTypeIds(logs, g1), ['a', 'b', 'c']);
      expect(frequentTypeIds(logs, g1, limit: 2), ['a', 'b']);
    });
  });
}
