import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs.dart';
import '../../core/settings.dart';
import 'mindfulness_model.dart';
import 'reminder_scheduler.dart';

/// OS 级本地通知调度器(单例)。main() 已 init。
final reminderSchedulerProvider =
    Provider<ReminderScheduler>((ref) => ReminderScheduler.instance);

/// 正念提醒配置(本地持久化,不入云 —— design §6)。
///
/// 任何字段变更都经 [update] 一次性完成:写偏好 → 全量重排 OS 通知,
/// 二者原子进行,避免"存了没排"或"排了没存"。
class MindfulnessController extends Notifier<MindfulnessSchedule> {
  @override
  MindfulnessSchedule build() {
    final raw = ref.watch(sharedPrefsProvider).getString(PrefKeys.mindfulnessSchedule);
    if (raw == null) return MindfulnessSchedule.defaults();
    try {
      return MindfulnessSchedule.fromJsonString(raw);
    } catch (_) {
      return MindfulnessSchedule.defaults();
    }
  }

  /// 保存并按新配置重排系统通知。本地化文案由调用方(设置页)传入:
  /// [body] 已解析默认文案,渠道名/描述已本地化。
  Future<void> update(
    MindfulnessSchedule schedule, {
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
  }) async {
    state = schedule;
    await ref
        .read(sharedPrefsProvider)
        .setString(PrefKeys.mindfulnessSchedule, schedule.toJsonString());
    await ref.read(reminderSchedulerProvider).reschedule(
          schedule,
          title: title,
          body: body,
          channelName: channelName,
          channelDescription: channelDescription,
        );
  }
}

final mindfulnessProvider =
    NotifierProvider<MindfulnessController, MindfulnessSchedule>(MindfulnessController.new);
