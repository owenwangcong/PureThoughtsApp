import 'package:flutter_test/flutter_test.dart';
import 'package:pure_thoughts/features/logs/offline_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<OfflineLogQueue> makeQueue() async {
    SharedPreferences.setMockInitialValues({});
    return OfflineLogQueue(await SharedPreferences.getInstance());
  }

  group('离线报数队列(P5.1)', () {
    test('空队列返回空列表', () async {
      final q = await makeQueue();
      expect(q.pending(), isEmpty);
    });

    test('入队保序、跨实例可读(持久化)', () async {
      final q = await makeQueue();
      await q.add([
        {'group_id': 'g1', 'quantity': 3},
      ]);
      await q.add([
        {'group_id': 'g2', 'quantity': 108},
      ]);
      final prefs = await SharedPreferences.getInstance();
      final q2 = OfflineLogQueue(prefs);
      final rows = q2.pending();
      expect(rows.length, 2);
      expect(rows.first['group_id'], 'g1');
      expect(rows.last['quantity'], 108);
    });

    test('replaceAll 清空与替换', () async {
      final q = await makeQueue();
      await q.add([
        {'a': 1},
        {'b': 2},
      ]);
      await q.replaceAll([
        {'c': 3},
      ]);
      expect(q.pending().single['c'], 3);
      await q.replaceAll(const []);
      expect(q.pending(), isEmpty);
    });
  });
}
