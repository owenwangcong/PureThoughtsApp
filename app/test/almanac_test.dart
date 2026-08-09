import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_thoughts/core/almanac/almanac.dart';
import 'package:pure_thoughts/features/notifications/notification_prefs.dart';

void main() {
  // 迷你年度数据:2026 年(仅首 3 天)+ 一个节日 + 一个十斋日
  final catalog = {
    'sakyamuni_birth': const AlmanacFestival(
      id: 'sakyamuni_birth',
      nameHant: '釋迦牟尼佛聖誕(浴佛節)',
      nameHans: '释迦牟尼佛圣诞(浴佛节)',
      shortHant: '佛誕',
      shortHans: '佛诞',
      major: true,
    ),
  };

  AlmanacYear year() => AlmanacYear.fromJson(
        jsonDecode(
                '{"y":2026,"days":[[11,13,0],[11,14,0],[11,15,1]],'
                '"fest":{"01-02":["sakyamuni_birth"]},"zhai":["01-03"]}')
            as Map<String, dynamic>,
        catalog,
      );

  group('AlmanacYear', () {
    test('逐日信息:农历数字/闰月标记', () {
      final info = year().infoFor(DateTime(2026, 1, 1))!;
      expect(info.lunarMonth, 11);
      expect(info.lunarDay, 13);
      expect(info.isLeapMonth, false);
      expect(info.isSpecial, false);

      expect(year().infoFor(DateTime(2026, 1, 3))!.isLeapMonth, true);
    });

    test('节日与十斋日命中', () {
      final fest = year().infoFor(DateTime(2026, 1, 2))!;
      expect(fest.festivals.single.id, 'sakyamuni_birth');
      expect(fest.isSpecial, true);

      final zhai = year().infoFor(DateTime(2026, 1, 3))!;
      expect(zhai.isZhaiTen, true);
      expect(zhai.isSpecial, true);
    });

    test('非本年 / 越界日期返回 null', () {
      expect(year().infoFor(DateTime(2025, 12, 31)), isNull);
      expect(year().infoFor(DateTime(2026, 1, 4)), isNull); // 迷你数据仅 3 天
    });
  });

  group('首页横幅文案 almanacBannerLines', () {
    test('平日不显示', () {
      final lines = almanacBannerLines(year().infoFor(DateTime(2026, 1, 1)),
          hans: false, todayWord: '今日', zhaiLabel: '十齋日');
      expect(lines, isNull);
      expect(
          almanacBannerLines(null,
              hans: false, todayWord: '今日', zhaiLabel: '十齋日'),
          isNull);
    });

    test('节日日:今日 · 農曆 + 节日全名', () {
      final lines = almanacBannerLines(year().infoFor(DateTime(2026, 1, 2)),
          hans: false, todayWord: '今日', zhaiLabel: '十齋日')!;
      expect(lines.$1, '今日 · 農曆冬月十四');
      expect(lines.$2, '釋迦牟尼佛聖誕(浴佛節)');
    });

    test('十斋日(闰月):简体文案', () {
      final lines = almanacBannerLines(year().infoFor(DateTime(2026, 1, 3)),
          hans: true, todayWord: '今日', zhaiLabel: '十斋日')!;
      expect(lines.$1, '今日 · 农历闰冬月十五');
      expect(lines.$2, '十斋日');
    });
  });

  // v0.5.21:佛历两个开关从本地 SharedPreferences 迁到云端 notification_prefs.muted_types,
  // 过滤逻辑随之从 almanacNotificationVisible 换成通用的 isNotificationMuted。
  group('通知静音过滤 isNotificationMuted', () {
    Map<String, dynamic> n(String type, [String? kind]) => {
          'type': type,
          if (kind != null) 'payload': {'kind': kind},
        };

    test('muted 为空时一律不静音', () {
      expect(isNotificationMuted(n('almanac', 'zhai'), const []), false);
      expect(isNotificationMuted(n('proxy_log'), const []), false);
    });

    test('裸 type 匹配', () {
      expect(isNotificationMuted(n('event_changed'), const ['event_changed']),
          true);
      expect(isNotificationMuted(n('event_reminder'), const ['event_changed']),
          false);
    });

    test('type:kind 只静音该 kind,同 type 其它 kind 不受影响', () {
      const muted = ['almanac:zhai'];
      expect(isNotificationMuted(n('almanac', 'zhai'), muted), true);
      expect(isNotificationMuted(n('almanac', 'festival'), muted), false);
    });

    test('节日开关同时覆盖当天节日与次日预告', () {
      final muted = legacyAlmanacMuted(showFestival: false, showZhai: true);
      expect(isNotificationMuted(n('almanac', 'festival'), muted), true);
      expect(isNotificationMuted(n('almanac', 'festival_eve'), muted), true);
      expect(isNotificationMuted(n('almanac', 'zhai'), muted), false);
    });

    test('非佛历通知不受佛历开关影响', () {
      final muted = legacyAlmanacMuted(showFestival: false, showZhai: false);
      expect(isNotificationMuted(n('proxy_log'), muted), false);
    });
  });

  group('老本地开关 → muted_types 迁移映射', () {
    test('两个都开 → 不静音任何类别', () {
      expect(legacyAlmanacMuted(showFestival: true, showZhai: true), isEmpty);
    });

    test('两个都关 → 三个 key 全静音', () {
      expect(legacyAlmanacMuted(showFestival: false, showZhai: false),
          ['almanac:festival', 'almanac:festival_eve', 'almanac:zhai']);
    });

    test('只关斋日', () {
      expect(legacyAlmanacMuted(showFestival: true, showZhai: false),
          ['almanac:zhai']);
    });
  });
}
