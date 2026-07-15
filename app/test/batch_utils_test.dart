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

  group('分组显示 groupByBatch', () {
    Map<String, dynamic> row(String reporter, String type, String createdAt,
            {String? subjectUser, String? subjectName}) =>
        {
          'reporter_id': reporter,
          'subject_user_id': subjectUser,
          'subject_name': subjectName,
          'created_at': createdAt,
          'practice_type_id': type,
        };

    test('同 created_at + 同报数人对象 → 合为一批', () {
      final logs = [
        row('u1', 'jing', '2026-07-07T10:00:00.111Z'),
        row('u1', 'zhou', '2026-07-07T10:00:00.111Z'),
        row('u1', 'zuo', '2026-07-06T09:00:00.222Z'),
      ];
      final batches = groupByBatch(logs);
      expect(batches.length, 2);
      expect(batches[0].length, 2); // 同一次提交两条
      expect(batches[1].length, 1);
    });

    test('created_at 不同不合并(两次独立提交)', () {
      final logs = [
        row('u1', 'jing', '2026-07-07T10:00:00.111Z'),
        row('u1', 'jing', '2026-07-07T10:00:00.222Z'),
      ];
      expect(groupByBatch(logs).length, 2);
    });

    test('同 created_at 但对象不同不合并(自己 vs 代报)', () {
      final logs = [
        row('u1', 'jing', '2026-07-07T10:00:00.111Z'),
        row('u1', 'jing', '2026-07-07T10:00:00.111Z', subjectName: '张三'),
      ];
      expect(groupByBatch(logs).length, 2);
    });

    test('空列表返回空', () {
      expect(groupByBatch([]), isEmpty);
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
