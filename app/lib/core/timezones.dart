import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../l10n/gen/app_localizations.dart';

/// 时区工具(PRD v0.5.15 §5 跨时区):IANA 时区数据库初始化、
/// 常用时区清单(简繁标签)、时区选择器(常用 + 全量搜索)。

var _tzInited = false;

/// 幂等初始化 tz 数据库;所有用到 tz.getLocation 的入口先调它
/// (main 里 ReminderScheduler 也会初始化,这里兜住纯单测等不走 main 的路径)。
void ensureTimeZonesInitialized() {
  if (_tzInited) return;
  tzdata.initializeTimeZones();
  _tzInited = true;
}

tz.Location locationOf(String iana) {
  ensureTimeZonesInitialized();
  try {
    return tz.getLocation(iana);
  } catch (_) {
    return tz.getLocation('Asia/Shanghai'); // 库损坏数据兜底,不让日历崩掉
  }
}

class TzOption {
  const TzOption(this.iana, this.hant, this.hans);
  final String iana;
  final String hant;
  final String hans;

  String label({required bool hans}) => hans ? this.hans : hant;
}

/// 共修团体常用时区(设计 §6.2);其余走「其他時區…」全量搜索
const commonTimezones = [
  TzOption('Asia/Shanghai', '中國(北京時間)', '中国(北京时间)'),
  TzOption('Asia/Taipei', '台北', '台北'),
  TzOption('Asia/Hong_Kong', '香港', '香港'),
  TzOption('Asia/Singapore', '新加坡', '新加坡'),
  TzOption('Asia/Kuala_Lumpur', '吉隆坡', '吉隆坡'),
  TzOption('Asia/Tokyo', '東京', '东京'),
  TzOption('Australia/Sydney', '悉尼', '悉尼'),
  TzOption('Pacific/Auckland', '奧克蘭', '奥克兰'),
  TzOption('America/Los_Angeles', '洛杉磯', '洛杉矶'),
  TzOption('America/Vancouver', '溫哥華', '温哥华'),
  TzOption('America/New_York', '紐約', '纽约'),
  TzOption('America/Toronto', '多倫多', '多伦多'),
  TzOption('Europe/London', '倫敦', '伦敦'),
  TzOption('Europe/Paris', '巴黎', '巴黎'),
];

/// 时区显示标签:常用清单给中文城市名,其余原样显示 IANA 名
String tzLabel(String iana, {required bool hans}) {
  for (final o in commonTimezones) {
    if (o.iana == iana) return o.label(hans: hans);
  }
  return iana;
}

/// 时区选择器:常用清单 + 「其他時區…」进全量搜索;返回选中的 IANA 名或 null。
Future<String?> showTimezonePicker(BuildContext context,
    {required bool hans, String? current}) async {
  ensureTimeZonesInitialized();
  final l10n = AppLocalizations.of(context);
  final picked = await showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(l10n.tzPickerTitle),
      children: [
        for (final o in commonTimezones)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, o.iana),
            child: Row(
              children: [
                if (o.iana == current)
                  const Icon(Icons.check, size: 18)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(o.label(hans: hans))),
              ],
            ),
          ),
        const Divider(),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, '_more_'),
          child: Text(l10n.tzMore),
        ),
      ],
    ),
  );
  if (picked != '_more_') return picked;
  if (!context.mounted) return null;
  return _showTimezoneSearch(context, l10n);
}

Future<String?> _showTimezoneSearch(
    BuildContext context, AppLocalizations l10n) {
  final all = tz.timeZoneDatabase.locations.keys.toList()..sort();
  return showDialog<String>(
    context: context,
    builder: (context) {
      var query = '';
      return StatefulBuilder(
        builder: (context, setState) {
          final filtered = query.isEmpty
              ? all
              : all
                  .where((n) => n.toLowerCase().contains(query.toLowerCase()))
                  .toList();
          return AlertDialog(
            title: Text(l10n.tzPickerTitle),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: Column(
                children: [
                  TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: l10n.tzSearchHint,
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => query = v.trim()),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, i) => ListTile(
                        dense: true,
                        title: Text(filtered[i]),
                        onTap: () => Navigator.pop(context, filtered[i]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
            ],
          );
        },
      );
    },
  );
}
