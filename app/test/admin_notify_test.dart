import 'package:flutter_test/flutter_test.dart';
import 'package:pure_thoughts/features/moderation/admin_notify_screen.dart';

void main() {
  final now = DateTime.parse('2026-07-18T12:00:00Z');

  Map<String, dynamic> row(String id,
          {String? scheduledAt, String? sentAt}) =>
      {
        'id': id,
        'title': 't$id',
        'body': null,
        'scheduled_at': scheduledAt,
        'sent_at': sentAt,
        'created_at': '2026-07-18T00:00:00Z',
      };

  group('splitAdminNotifications', () {
    test('未来定时且未发送 → 已排程;其余 → 已发送', () {
      final split = splitAdminNotifications([
        row('a', scheduledAt: '2026-07-19T00:00:00Z'), // 未来,未发 → pending
        row('b', sentAt: '2026-07-18T00:00:01Z'), // 已发
        row('c'), // 立即发(等待投递) → 按已发送侧展示
        row('d',
            scheduledAt: '2026-07-18T11:00:00Z'), // 已到点未投递(分钟级窗口) → 已发送侧
      ], now);
      expect(split.pending.map((r) => r['id']), ['a']);
      expect(split.sent.map((r) => r['id']), ['b', 'c', 'd']);
    });

    test('空列表安全', () {
      final split = splitAdminNotifications([], now);
      expect(split.pending, isEmpty);
      expect(split.sent, isEmpty);
    });

    test('定时已投递(sent_at 非空)不再算排程', () {
      final split = splitAdminNotifications([
        row('x',
            scheduledAt: '2026-07-19T00:00:00Z',
            sentAt: '2026-07-19T00:00:05Z'),
      ], now);
      expect(split.pending, isEmpty);
      expect(split.sent.single['id'], 'x');
    });
  });
}
