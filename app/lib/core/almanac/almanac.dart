import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'lunar_format.dart';

/// 佛历(PRD v0.5.15 §5.2):逐日农历 + 精选佛教节日 + 十斋日。
/// 数据为 tools/almanac 预生成的资产文件(2026–2075),**完全离线、匿名可用**;
/// 范围外年份返回 null,界面只是不显示农历,不报错。

class AlmanacFestival {
  const AlmanacFestival({
    required this.id,
    required this.nameHant,
    required this.nameHans,
    required this.shortHant,
    required this.shortHans,
    required this.major,
  });

  factory AlmanacFestival.fromJson(Map<String, dynamic> j) => AlmanacFestival(
        id: j['id'] as String,
        nameHant: j['hant'] as String,
        nameHans: j['hans'] as String,
        shortHant: j['short_hant'] as String,
        shortHans: j['short_hans'] as String,
        major: j['major'] as bool? ?? false,
      );

  final String id;
  final String nameHant;
  final String nameHans;
  final String shortHant;
  final String shortHans;
  final bool major;

  String name({required bool hans}) => hans ? nameHans : nameHant;
  String shortName({required bool hans}) => hans ? shortHans : shortHant;
}

/// 某一公历日的佛历信息
class AlmanacDayInfo {
  const AlmanacDayInfo({
    required this.lunarMonth,
    required this.lunarDay,
    required this.isLeapMonth,
    required this.festivals,
    required this.isZhaiTen,
  });

  final int lunarMonth;
  final int lunarDay;
  final bool isLeapMonth;
  final List<AlmanacFestival> festivals;
  final bool isZhaiTen;

  /// 是否值得提醒用户(首页横幅 / 佛历卡强调)
  bool get isSpecial => festivals.isNotEmpty || isZhaiTen;
}

/// 一整年的佛历数据(`almanac_<year>.json`)
class AlmanacYear {
  AlmanacYear({
    required this.year,
    required this.days,
    required this.festivalsByDate,
    required this.zhaiDates,
  });

  factory AlmanacYear.fromJson(
      Map<String, dynamic> j, Map<String, AlmanacFestival> catalog) {
    return AlmanacYear(
      year: j['y'] as int,
      days: [
        for (final d in j['days'] as List) (d as List).cast<int>(),
      ],
      festivalsByDate: {
        for (final e in (j['fest'] as Map<String, dynamic>).entries)
          e.key: [
            for (final id in e.value as List)
              if (catalog[id] != null) catalog[id]!,
          ],
      },
      zhaiDates: {...(j['zhai'] as List).cast<String>()},
    );
  }

  final int year;

  /// 按公历日序:[农历月, 农历日, 是否闰月(0/1)]
  final List<List<int>> days;

  /// 'MM-DD' → 当日节日
  final Map<String, List<AlmanacFestival>> festivalsByDate;

  /// 十斋日 'MM-DD' 集合
  final Set<String> zhaiDates;

  /// 取某天信息;非本年或越界返回 null。
  /// 用 UTC 构造做日序差,避免设备处于 DST 时区时出现 23/25 小时日导致的偏移。
  AlmanacDayInfo? infoFor(DateTime date) {
    if (date.year != year) return null;
    final index = DateTime.utc(date.year, date.month, date.day)
        .difference(DateTime.utc(year))
        .inDays;
    if (index < 0 || index >= days.length) return null;
    final d = days[index];
    final md = '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    return AlmanacDayInfo(
      lunarMonth: d[0],
      lunarDay: d[1],
      isLeapMonth: d[2] == 1,
      festivals: festivalsByDate[md] ?? const [],
      isZhaiTen: zhaiDates.contains(md),
    );
  }
}

/// 节日目录(festivals.json),App 生命周期内只加载一次
final festivalCatalogProvider =
    FutureProvider<Map<String, AlmanacFestival>>((ref) async {
  final raw = await rootBundle.loadString('assets/almanac/festivals.json');
  return {
    for (final j in jsonDecode(raw) as List)
      (j as Map<String, dynamic>)['id'] as String: AlmanacFestival.fromJson(j),
  };
});

/// 某年佛历(懒加载 + Riverpod 缓存);范围外年份 → null
final almanacYearProvider =
    FutureProvider.family<AlmanacYear?, int>((ref, year) async {
  final catalog = await ref.watch(festivalCatalogProvider.future);
  try {
    final raw =
        await rootBundle.loadString('assets/almanac/almanac_$year.json');
    return AlmanacYear.fromJson(
        jsonDecode(raw) as Map<String, dynamic>, catalog);
  } catch (_) {
    return null; // 2026–2075 之外没有资产文件
  }
});

/// 今日(设备本地日期)的佛历信息;加载中 / 范围外 → null
final todayAlmanacProvider = Provider<AlmanacDayInfo?>((ref) {
  final now = DateTime.now();
  final year = ref.watch(almanacYearProvider(now.year)).value;
  return year?.infoFor(now);
});

/// 首页横幅两行文案(纯函数,便于单测):
/// 非特殊日返回 null;line1 =「今日 · 農曆四月初八」,line2 = 节日全名/十斋日(顿号相连)。
(String, String)? almanacBannerLines(
  AlmanacDayInfo? info, {
  required bool hans,
  required String todayWord,
  required String zhaiLabel,
}) {
  if (info == null || !info.isSpecial) return null;
  final lunar = lunarFullText(info.lunarMonth, info.lunarDay, info.isLeapMonth,
      hans: hans);
  final parts = [
    for (final f in info.festivals) f.name(hans: hans),
    if (info.isZhaiTen) zhaiLabel,
  ];
  return ('$todayWord · $lunar', parts.join('、'));
}
