// 活动提醒档位(PRD v0.5.21 §5,设计 design/notification-overhaul.md §2/§6)。
// 纯逻辑独立成文件便于单测。

import '../../l10n/gen/app_localizations.dart';

/// 可选的提前量(分钟)。0 = 活动开始时。
const reminderOffsetOptions = <int>[0, 10, 15, 30, 60, 180, 1440, 2880];

/// 新建活动的默认三档,**必须与 DB 触发器 default_event_reminders 一致**
/// (migration 0025;经后台或 SQL 建的活动也要拿到同样的默认值)。
///
/// 三档各司其职,缺一不可(2026-08-08 定案):
/// - 1440 提前一天:让用户安排时间,且是大陆 Android 用户唯一能看到的一档
///   (他们收不到实时推送,只能靠"打开 App 即见");
/// - 30 提前半小时:临门一脚,补上预告到开始之间 24 小时的空档;
/// - 0 活动开始时:点击直进 Webex/YouTube。
const defaultReminderOffsets = <int>[1440, 30, 0];

String reminderOffsetLabel(AppLocalizations l10n, int minutes) {
  if (minutes <= 0) return l10n.reminderOffsetAtStart;
  if (minutes == 1440) return l10n.reminderOffsetOneDay;
  if (minutes == 2880) return l10n.reminderOffsetTwoDays;
  if (minutes % 60 == 0) return l10n.reminderOffsetHours(minutes ~/ 60);
  return l10n.reminderOffsetMinutes(minutes);
}

/// 编辑器里选中的档位 → 需要新增 / 删除的差集(保存时对 event_reminders 做 diff)
({List<int> toAdd, List<int> toRemove}) diffReminders({
  required Iterable<int> current,
  required Iterable<int> wanted,
}) {
  final have = current.toSet();
  final want = wanted.toSet();
  return (
    toAdd: (want.difference(have).toList()..sort()),
    toRemove: (have.difference(want).toList()..sort()),
  );
}
