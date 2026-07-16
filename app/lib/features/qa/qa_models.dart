/// 往期问答检索的数据模型(PRD §6 / design/qa-search.md §6.1)。
/// 一条记录 = 一个问答片段:独立标题 + AI 摘要正文 + 带时间戳的 YouTube 链接。
/// 可空性照上游对接文档表格:start_time / durationSeconds / publishedDate 可空;
/// summary 可能是空串但不为 null;tags 无标签时为 []。
library;

class QaSegment {
  const QaSegment({
    required this.id,
    required this.qaTitle,
    required this.videoTitle,
    required this.summary,
    required this.timestampUrl,
    this.startTime,
    this.durationSeconds,
    this.publishedDate,
    this.tags = const [],
  });

  final int id;
  final String qaTitle;
  final String videoTitle;
  final String summary;
  final String timestampUrl;
  final String? startTime; // "00:03:59",可空
  final int? durationSeconds;
  final DateTime? publishedDate;
  final List<String> tags;

  factory QaSegment.fromJson(Map<String, dynamic> json) {
    final rawDate = json['published_date'] as String?;
    return QaSegment(
      id: json['id'] as int,
      qaTitle: json['qa_title'] as String,
      videoTitle: json['video_title'] as String,
      summary: json['summary'] as String? ?? '',
      timestampUrl: json['timestamp_url'] as String,
      startTime: json['start_time'] as String?,
      durationSeconds: json['duration_seconds'] as int?,
      // 上游给的是 "2026-01-11",DateTime.tryParse 能直接吃;坏值不抛
      publishedDate: rawDate == null ? null : DateTime.tryParse(rawDate),
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }

  /// 从 timestamp_url 解析出的 YouTube 视频 ID(解析失败为 null)。
  String? get videoId => parseYoutubeVideoId(timestampUrl);

  /// 从 timestamp_url 解析出的起播秒数(无 ?t= 时为 null)。
  int? get startSeconds {
    final m = RegExp(r'[?&]t=(\d+)').firstMatch(timestampUrl);
    return m == null ? null : int.tryParse(m.group(1)!);
  }
}

/// 从 YouTube URL 提取 11 位视频 ID。
/// 与 features/live/live_providers.dart 的 youtubeVideoId 同一正则,
/// 此处独立一份以保持本模型不依赖 live 特性(纯函数、可单测)。
String? parseYoutubeVideoId(String url) {
  final m = RegExp(r'(?:v=|youtu\.be/|/live/)([\w-]{11})').firstMatch(url);
  return m?.group(1);
}

/// 片段时长秒数 → "m:ss"(如 696 → "11:36")。
String qaFormatDuration(int seconds) {
  final m = seconds ~/ 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// DateTime → "YYYY-MM-DD"(只取日期,补零)。
String qaFormatDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

class QaSearchResponse {
  const QaSearchResponse({
    required this.total,
    required this.page,
    required this.perPage,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrev,
    required this.results,
  });

  final int total;
  final int page;
  final int perPage;
  final int totalPages; // 无结果时为 0,不是 1
  final bool hasNext;
  final bool hasPrev;
  final List<QaSegment> results;

  factory QaSearchResponse.fromJson(Map<String, dynamic> json) => QaSearchResponse(
        total: json['total'] as int,
        page: json['page'] as int,
        perPage: json['per_page'] as int,
        totalPages: json['total_pages'] as int,
        hasNext: json['has_next'] as bool,
        hasPrev: json['has_prev'] as bool,
        results: (json['results'] as List<dynamic>)
            .map((e) => QaSegment.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
