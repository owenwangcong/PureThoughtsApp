import 'package:flutter_test/flutter_test.dart';
import 'package:pure_thoughts/features/events/event_detail_models.dart';

void main() {
  group('AgendaItem.fromJson', () {
    test('time 截成 HH:mm;空 link_url → null', () {
      final it = AgendaItem.fromJson({
        'id': 'x',
        'day_index': 2,
        'start_time': '09:30:00',
        'end_time': '11:00:00',
        'activity': '誦經',
        'link_url': '  ',
        'sort_order': 5,
      });
      expect(it.startTime, '09:30');
      expect(it.endTime, '11:00');
      expect(it.timeRange, '09:30–11:00');
      expect(it.linkUrl, isNull);
      expect(it.dayIndex, 2);
    });

    test('无结束时间 → timeRange 只显示起始', () {
      final it = AgendaItem.fromJson(
          {'start_time': '06:00:00', 'end_time': null, 'activity': '早課'});
      expect(it.timeRange, '06:00');
    });
  });

  group('humanSize / cnNumber', () {
    test('字节 → 人类可读', () {
      expect(humanSize(512), '512 B');
      expect(humanSize(1536), '1.5 KB');
      expect(humanSize(1258291), '1.2 MB');
    });
    test('中文数字', () {
      expect(cnNumber(1), '一');
      expect(cnNumber(7), '七');
      expect(cnNumber(10), '十');
      expect(cnNumber(12), '十二');
      expect(cnNumber(20), '二十');
      expect(cnNumber(21), '二十一');
    });
  });

  group('embedCount / EventResourceFlags', () {
    test('embedCount 解析 [{count:N}];空/异常 → 0', () {
      expect(embedCount([{'count': 3}]), 3);
      expect(embedCount([{'count': 0}]), 0);
      expect(embedCount([]), 0);
      expect(embedCount(null), 0);
      expect(embedCount('x'), 0);
    });

    test('资源标记:时间表 + 链接,无 PDF', () {
      final f = EventResourceFlags.fromEvent({
        'event_agenda_items': [{'count': 3}],
        'event_attachments': [{'count': 0}],
        'youtube_url': 'https://youtube.com/x',
        'webex_url': null,
      });
      expect(f.agenda, isTrue);
      expect(f.attachment, isFalse);
      expect(f.link, isTrue);
      expect(f.any, isTrue);
    });

    test('无任何资源 → any=false', () {
      final f = EventResourceFlags.fromEvent({
        'event_agenda_items': [{'count': 0}],
        'event_attachments': [{'count': 0}],
        'youtube_url': null,
        'webex_url': '',
      });
      expect(f.any, isFalse);
    });

    test('仅 PDF(webex 非空算链接)', () {
      final f = EventResourceFlags.fromEvent({
        'event_attachments': [{'count': 2}],
        'webex_url': 'https://webex.com/room',
      });
      expect(f.agenda, isFalse);
      expect(f.attachment, isTrue);
      expect(f.link, isTrue);
    });
  });

  group('groupAgendaByDay', () {
    test('按天分组、组内按 (sortOrder, startTime) 排序', () {
      final items = [
        AgendaItem(dayIndex: 2, startTime: '08:00', activity: 'd2b', sortOrder: 20),
        AgendaItem(dayIndex: 1, startTime: '09:00', activity: 'd1b', sortOrder: 20),
        AgendaItem(dayIndex: 1, startTime: '06:00', activity: 'd1a', sortOrder: 10),
        AgendaItem(dayIndex: 2, startTime: '06:00', activity: 'd2a', sortOrder: 10),
      ];
      final g = groupAgendaByDay(items);
      expect(g.map((e) => e.day), [1, 2]);
      expect(g[0].items.map((e) => e.activity), ['d1a', 'd1b']);
      expect(g[1].items.map((e) => e.activity), ['d2a', 'd2b']);
    });
  });

  group('renderAgendaText', () {
    final att = [
      const EventAttachment(
          id: 'a', title: '地藏經 經本', storagePath: 'e/x.pdf',
          publicUrl: 'https://api.pure-thoughts.com/storage/v1/object/public/event-files/e/x.pdf'),
    ];

    test('单日:不出「第N天」头,含链接与资料', () {
      final text = renderAgendaText(
        title: '週六共修',
        whenText: '2026-08-01 09:00',
        agenda: [
          const AgendaItem(dayIndex: 1, startTime: '09:30', endTime: '11:00', activity: '誦地藏經', linkUrl: 'https://qldazangjing.com/'),
        ],
        attachments: att,
        youtubeUrl: 'https://youtube.com/watch?v=abc',
        hans: false,
      );
      expect(text, contains('【時間表】'));
      expect(text, isNot(contains('第一天'))); // 单日不分组头
      expect(text, contains('09:30–11:00  誦地藏經  https://qldazangjing.com/'));
      expect(text, contains('【相關資料】'));
      expect(text, contains('地藏經 經本:https://api.pure-thoughts.com'));
      expect(text, contains('YouTube:https://youtube.com/watch?v=abc'));
    });

    test('多日:出「第N天(M月D日)」头', () {
      final text = renderAgendaText(
        title: '禪七',
        agenda: [
          const AgendaItem(dayIndex: 1, startTime: '06:00', activity: '早課'),
          const AgendaItem(dayIndex: 2, startTime: '06:00', activity: '早課'),
        ],
        attachments: const [],
        hans: true,
        firstDayDate: DateTime(2026, 8, 1),
      );
      expect(text, contains('【时间表】'));
      expect(text, contains('第一天(8月1日)'));
      expect(text, contains('第二天(8月2日)'));
    });

    test('空时间表 + 空资料 → 仅标题', () {
      final text = renderAgendaText(
        title: '法會',
        agenda: const [],
        attachments: const [],
        hans: true,
      );
      expect(text, '法會');
    });
  });
}
