import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_thoughts/core/almanac/almanac.dart';
import 'package:pure_thoughts/features/notifications/notifications_providers.dart';

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

  group('通知开关过滤 almanacNotificationVisible', () {
    Map<String, dynamic> n(String type, [String? kind]) => {
          'type': type,
          if (kind != null) 'payload': {'kind': kind},
        };

    test('非佛历通知不受开关影响', () {
      expect(almanacNotificationVisible(n('proxy_log'), false, false), true);
    });

    test('节日类(festival/festival_eve)跟节日开关', () {
      expect(almanacNotificationVisible(n('almanac', 'festival'), true, false),
          true);
      expect(almanacNotificationVisible(n('almanac', 'festival'), false, true),
          false);
      expect(
          almanacNotificationVisible(n('almanac', 'festival_eve'), false, true),
          false);
    });

    test('十斋日类跟斋日开关', () {
      expect(almanacNotificationVisible(n('almanac', 'zhai'), false, true), true);
      expect(almanacNotificationVisible(n('almanac', 'zhai'), true, false), false);
    });
  });
}
