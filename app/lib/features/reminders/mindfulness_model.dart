import 'dart:convert';

/// 正念提醒配置(PRD §9.3 / design/mindfulness-reminders.md §6)。
///
/// 纯设备级本地偏好,不同步到云端。所有字段与槽位展开逻辑保持无 Flutter 依赖,
/// 便于纯单元测试(见 test/mindfulness_slots_test.dart)。
class MindfulnessSchedule {
  const MindfulnessSchedule({
    required this.enabled,
    required this.weekdays,
    required this.startMinutes,
    required this.endMinutes,
    required this.intervalMinutes,
    required this.sound,
    required this.vibrate,
    this.message,
  });

  /// 总开关
  final bool enabled;

  /// ISO-8601 星期:1=周一 … 7=周日
  final Set<int> weekdays;

  /// 起始时间(自 00:00 起的分钟数,如 8:00 → 480)
  final int startMinutes;

  /// 结束时间(须 > startMinutes,同日不跨午夜,§4.1)
  final int endMinutes;

  /// 间隔分钟(下限 minInterval;预设见 intervalPresets)
  final int intervalMinutes;

  /// 'bell'(磬声)| 'silent'(仅震动/无声)
  final String sound;

  /// 是否震动
  final bool vibrate;

  /// 通知文案;null 时展示端用本地化默认("该正念了 · 回到当下")
  final String? message;

  // —— 约束常量(design §4.1 / §5 / §6)——
  static const int minInterval = 10;
  static const List<int> intervalPresets = [10, 15, 20, 30, 45, 60, 90];
  /// iOS 系统最多 64 条待触发本地通知
  static const int iosSlotCap = 64;
  /// 最宽窗口:00:00–23:50
  static const int minStart = 0;
  static const int maxEnd = 23 * 60 + 50;

  /// 默认配置:关闭状态;开启后为周一至周日、9:00–17:00 每 60 分钟一次
  /// (= 63 槽,刻意 ≤64 让 iOS 首次开启即安全,design §5)。
  factory MindfulnessSchedule.defaults() => const MindfulnessSchedule(
        enabled: false,
        weekdays: {1, 2, 3, 4, 5, 6, 7},
        startMinutes: 9 * 60, // 9:00
        endMinutes: 17 * 60, // 17:00
        intervalMinutes: 60,
        sound: 'bell',
        vibrate: true,
        message: null,
      );

  /// 窗口是否合法:结束须晚于开始(§4.1)
  bool get isWindowValid => endMinutes > startMinutes;

  MindfulnessSchedule copyWith({
    bool? enabled,
    Set<int>? weekdays,
    int? startMinutes,
    int? endMinutes,
    int? intervalMinutes,
    String? sound,
    bool? vibrate,
    String? message,
    bool clearMessage = false,
  }) =>
      MindfulnessSchedule(
        enabled: enabled ?? this.enabled,
        weekdays: weekdays ?? this.weekdays,
        startMinutes: startMinutes ?? this.startMinutes,
        endMinutes: endMinutes ?? this.endMinutes,
        intervalMinutes: intervalMinutes ?? this.intervalMinutes,
        sound: sound ?? this.sound,
        vibrate: vibrate ?? this.vibrate,
        message: clearMessage ? null : (message ?? this.message),
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'weekdays': (weekdays.toList()..sort()),
        'startMinutes': startMinutes,
        'endMinutes': endMinutes,
        'intervalMinutes': intervalMinutes,
        'sound': sound,
        'vibrate': vibrate,
        'message': message,
      };

  factory MindfulnessSchedule.fromJson(Map<String, dynamic> j) {
    final d = MindfulnessSchedule.defaults();
    return MindfulnessSchedule(
      enabled: j['enabled'] as bool? ?? d.enabled,
      weekdays: (j['weekdays'] as List?)?.map((e) => e as int).toSet() ?? d.weekdays,
      startMinutes: j['startMinutes'] as int? ?? d.startMinutes,
      endMinutes: j['endMinutes'] as int? ?? d.endMinutes,
      intervalMinutes: j['intervalMinutes'] as int? ?? d.intervalMinutes,
      sound: j['sound'] as String? ?? d.sound,
      vibrate: j['vibrate'] as bool? ?? d.vibrate,
      message: j['message'] as String?,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory MindfulnessSchedule.fromJsonString(String s) =>
      MindfulnessSchedule.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

/// 展开后的单个"通知槽":某个星期几的某个时刻。
class ReminderSlot {
  const ReminderSlot(this.weekday, this.minutes);

  /// ISO 星期 1..7
  final int weekday;

  /// 自 00:00 起的分钟数
  final int minutes;

  int get hour => minutes ~/ 60;
  int get minute => minutes % 60;

  @override
  bool operator ==(Object other) =>
      other is ReminderSlot && other.weekday == weekday && other.minutes == minutes;

  @override
  int get hashCode => Object.hash(weekday, minutes);

  @override
  String toString() =>
      'ReminderSlot(w$weekday ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')})';
}

/// 单日内的触发时刻集合:[start, start+interval, …] 且 ≤ end。
/// 不整除时最后一次落在 ≤end 处即止(design §11)。
List<int> dailyTimes(int startMinutes, int endMinutes, int intervalMinutes) {
  if (intervalMinutes <= 0 || endMinutes <= startMinutes) return const [];
  final times = <int>[];
  for (var t = startMinutes; t <= endMinutes; t += intervalMinutes) {
    times.add(t);
  }
  return times;
}

/// 单日触发次数
int dailyCount(MindfulnessSchedule s) =>
    dailyTimes(s.startMinutes, s.endMinutes, s.intervalMinutes).length;

/// 把"周几 × 时间窗 × 间隔"展开为一组按周重复的通知槽(design §4)。
/// 关闭或窗口非法时返回空。
List<ReminderSlot> expandSlots(MindfulnessSchedule s) {
  if (!s.enabled || !s.isWindowValid) return const [];
  final times = dailyTimes(s.startMinutes, s.endMinutes, s.intervalMinutes);
  final days = s.weekdays.toList()..sort();
  return [
    for (final w in days)
      for (final t in times) ReminderSlot(w, t),
  ];
}

/// 一周总槽位数 = 周几数 × 每日次数
int weeklySlotCount(MindfulnessSchedule s) => expandSlots(s).length;

/// iOS 是否超 64 上限(design §5)
bool exceedsIosCap(MindfulnessSchedule s) => weeklySlotCount(s) > MindfulnessSchedule.iosSlotCap;
