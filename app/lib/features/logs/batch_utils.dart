// 报数体验优化的纯逻辑(PRD v0.5.3 §4.2),独立成文件便于单测。

/// 「重複上次」:取该群**最近一天**(local_date 最大)的自报组合(功课 → 数量)。
/// 同一功课当天报多次时取最新一条(入参按 created_at 降序)。
Map<String, double> latestBatch(
  List<Map<String, dynamic>> recentSelfLogs,
  String groupId,
) {
  final mine =
      recentSelfLogs.where((r) => r['group_id'] == groupId).toList();
  if (mine.isEmpty) return const {};
  String? latest;
  for (final r in mine) {
    final d = r['local_date'] as String?;
    if (d != null && (latest == null || d.compareTo(latest) > 0)) latest = d;
  }
  final out = <String, double>{};
  for (final r in mine.where((r) => r['local_date'] == latest)) {
    out.putIfAbsent(
      r['practice_type_id'] as String,
      () => double.tryParse('${r['quantity']}') ?? 0,
    );
  }
  return out;
}

/// 「常用功课」:该群最近自报的功课去重(保持最近优先顺序),最多 [limit] 个。
List<String> frequentTypeIds(
  List<Map<String, dynamic>> recentSelfLogs,
  String groupId, {
  int limit = 6,
}) {
  final seen = <String>{};
  final out = <String>[];
  for (final r in recentSelfLogs) {
    if (r['group_id'] != groupId) continue;
    final id = r['practice_type_id'] as String;
    if (seen.add(id)) out.add(id);
    if (out.length >= limit) break;
  }
  return out;
}
