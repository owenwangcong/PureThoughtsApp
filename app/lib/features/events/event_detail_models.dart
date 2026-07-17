/// 活动时间表/资料的数据模型与纯逻辑(PRD v0.5.12 §5,设计 event-agenda.md)。
/// 纯 Dart(不依赖 Flutter/Supabase),便于单测;URL 由 provider 注入。
library;

class AgendaItem {
  const AgendaItem({
    required this.dayIndex,
    required this.startTime,
    required this.activity,
    this.endTime,
    this.linkUrl,
    this.linkLabel,
    this.sortOrder = 0,
    this.id,
  });

  final String? id;
  final int dayIndex; // 第几天(单日活动恒 1)
  final String startTime; // "HH:mm"
  final String? endTime; // "HH:mm",可空
  final String activity;
  final String? linkUrl; // 自由网址(经文等)
  final String? linkLabel;
  final int sortOrder;

  /// "06:00–07:00" 或仅 "06:00"(无结束)
  String get timeRange => endTime == null ? startTime : '$startTime–$endTime';

  factory AgendaItem.fromJson(Map<String, dynamic> j) {
    final url = (j['link_url'] as String?)?.trim();
    return AgendaItem(
      id: j['id'] as String?,
      dayIndex: j['day_index'] as int? ?? 1,
      startTime: _hhmm(j['start_time'] as String?),
      endTime: j['end_time'] == null ? null : _hhmm(j['end_time'] as String),
      activity: j['activity'] as String,
      linkUrl: (url == null || url.isEmpty) ? null : url,
      linkLabel: j['link_label'] as String?,
      sortOrder: j['sort_order'] as int? ?? 0,
    );
  }
}

/// DB `time`("09:00:00")→ "HH:mm"
String _hhmm(String? t) =>
    t == null ? '' : (t.length >= 5 ? t.substring(0, 5) : t);

class EventAttachment {
  const EventAttachment({
    required this.id,
    required this.title,
    required this.storagePath,
    required this.publicUrl,
    this.sizeBytes,
    this.contentType,
    this.sortOrder = 0,
  });

  final String id;
  final String title;
  final String storagePath;
  final String publicUrl; // 由 provider 用 Storage.getPublicUrl 注入
  final int? sizeBytes;
  final String? contentType;
  final int sortOrder;

  String get sizeText => sizeBytes == null ? '' : humanSize(sizeBytes!);

  /// [publicUrl] 需外部(provider)计算后传入。
  factory EventAttachment.fromRow(Map<String, dynamic> j, String publicUrl) =>
      EventAttachment(
        id: j['id'] as String,
        title: j['title'] as String,
        storagePath: j['storage_path'] as String,
        publicUrl: publicUrl,
        sizeBytes: j['size_bytes'] as int?,
        contentType: j['content_type'] as String?,
        sortOrder: j['sort_order'] as int? ?? 0,
      );
}

/// PostgREST 聚合嵌套 `child(count)` 的计数;返回形如 `[{count: N}]`,空/异常回退 0。
int embedCount(dynamic v) {
  if (v is List && v.isNotEmpty) {
    final first = v.first;
    if (first is Map && first['count'] is int) return first['count'] as int;
  }
  return 0;
}

/// 事件在日历列表项上要展示的「内含资源」标记(PRD v0.5.12:让用户一眼看出里面有内容)。
/// - agenda:有时间表行 · attachment:有 PDF 资料 · link:有 YouTube/Webex 链接。
class EventResourceFlags {
  const EventResourceFlags(
      {required this.agenda, required this.attachment, required this.link});

  final bool agenda;
  final bool attachment;
  final bool link;

  bool get any => agenda || attachment || link;

  /// 从 events 查询行(含 `event_agenda_items(count)` / `event_attachments(count)`
  /// 嵌套计数 + `youtube_url` / `webex_url`)派生。
  factory EventResourceFlags.fromEvent(Map<String, dynamic> e) =>
      EventResourceFlags(
        agenda: embedCount(e['event_agenda_items']) > 0,
        attachment: embedCount(e['event_attachments']) > 0,
        link: (e['youtube_url'] as String?)?.isNotEmpty == true ||
            (e['webex_url'] as String?)?.isNotEmpty == true,
      );
}

String humanSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB';
}

/// 中文数字(1..99;时间表天数够用),超出回退阿拉伯数字。
String cnNumber(int n) {
  const d = ['零', '一', '二', '三', '四', '五', '六', '七', '八', '九'];
  if (n <= 0 || n >= 100) return '$n';
  if (n < 10) return d[n];
  if (n == 10) return '十';
  if (n < 20) return '十${d[n % 10]}';
  final tens = '${d[n ~/ 10]}十';
  return n % 10 == 0 ? tens : '$tens${d[n % 10]}';
}

/// 「第N天(M月D日)」标签;[firstDayDate] 非空(单次活动)时附日期。
/// UI 与分享文本共用,保证两处一致。
String dayLabel(int day, {DateTime? firstDayDate}) {
  var date = '';
  if (firstDayDate != null) {
    final d = firstDayDate.add(Duration(days: day - 1));
    date = '(${d.month}月${d.day}日)';
  }
  return '第${cnNumber(day)}天$date';
}

/// 按 day_index 分组并排序;返回按天升序,组内按 (sortOrder, startTime)。
List<({int day, List<AgendaItem> items})> groupAgendaByDay(
    List<AgendaItem> items) {
  final map = <int, List<AgendaItem>>{};
  for (final it in items) {
    map.putIfAbsent(it.dayIndex, () => []).add(it);
  }
  final days = map.keys.toList()..sort();
  return [
    for (final day in days)
      (
        day: day,
        items: map[day]!
          ..sort((a, b) {
            final c = a.sortOrder.compareTo(b.sortOrder);
            return c != 0 ? c : a.startTime.compareTo(b.startTime);
          }),
      )
  ];
}

/// 整张时间表 + 资料 → 纯文本(分享/复制)。多天分「第N天」,单天不分组头。
/// [firstDayDate] 非空(单次活动)时,多天表头附「(M月D日)」。
String renderAgendaText({
  required String title,
  String? whenText,
  required List<AgendaItem> agenda,
  required List<EventAttachment> attachments,
  String? youtubeUrl,
  required bool hans,
  DateTime? firstDayDate,
}) {
  final b = StringBuffer()..writeln(title);
  if (whenText != null && whenText.isNotEmpty) b.writeln(whenText);

  final grouped = groupAgendaByDay(agenda);
  if (grouped.isNotEmpty) {
    b
      ..writeln()
      ..writeln(hans ? '【时间表】' : '【時間表】');
    final multiDay = grouped.length > 1;
    for (final g in grouped) {
      if (multiDay) {
        b.writeln(dayLabel(g.day, firstDayDate: firstDayDate));
      }
      for (final it in g.items) {
        final line = StringBuffer('  ${it.timeRange}  ${it.activity}');
        if (it.linkUrl != null) line.write('  ${it.linkUrl}');
        b.writeln(line.toString());
      }
    }
  }

  final links = <String>[
    for (final a in attachments) '${a.title}:${a.publicUrl}',
    if (youtubeUrl != null && youtubeUrl.trim().isNotEmpty) 'YouTube:$youtubeUrl',
  ];
  if (links.isNotEmpty) {
    b
      ..writeln()
      ..writeln(hans ? '【相关资料】' : '【相關資料】');
    for (final l in links) {
      b.writeln(l);
    }
  }
  return b.toString().trimRight();
}
