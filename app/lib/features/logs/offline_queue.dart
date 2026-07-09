import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/prefs.dart';
import '../../l10n/gen/app_localizations.dart';
import '../dashboard/dashboard_providers.dart';

/// 离线报数暂存(PRD §11,P5.1):网络失败的报数进本地队列,联网自动补传。
/// 报数为追加型记录,直接补传无覆盖冲突(PRD 定案)。
class OfflineLogQueue {
  OfflineLogQueue(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'pending_practice_logs';

  List<Map<String, dynamic>> pending() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    return [
      for (final e in jsonDecode(raw) as List)
        Map<String, dynamic>.from(e as Map),
    ];
  }

  Future<void> add(List<Map<String, dynamic>> rows) async {
    await _prefs.setString(_key, jsonEncode([...pending(), ...rows]));
  }

  Future<void> replaceAll(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) {
      await _prefs.remove(_key);
    } else {
      await _prefs.setString(_key, jsonEncode(rows));
    }
  }
}

final offlineQueueProvider =
    Provider<OfflineLogQueue>((ref) => OfflineLogQueue(ref.watch(sharedPrefsProvider)));

enum SubmitResult { ok, queued }

/// 提交报数:网络类错误 → 暂存队列(queued);
/// 服务器明确拒绝(PostgrestException,如 RLS/校验)原样抛出,不入队。
Future<SubmitResult> submitPracticeLogs(
    WidgetRef ref, List<Map<String, dynamic>> rows) async {
  try {
    await Supabase.instance.client.from('practice_logs').insert(rows);
    return SubmitResult.ok;
  } on PostgrestException {
    rethrow;
  } catch (_) {
    await ref.read(offlineQueueProvider).add(rows);
    return SubmitResult.queued;
  }
}

/// 补传离线队列;返回成功条数。整批被拒时逐条重试,
/// 被服务器明确拒绝的条目丢弃(避免坏数据卡死队列),网络失败的保留。
Future<int> flushOfflineLogs(WidgetRef ref) async {
  final queue = ref.read(offlineQueueProvider);
  final rows = queue.pending();
  if (rows.isEmpty || Supabase.instance.client.auth.currentUser == null) return 0;
  try {
    await Supabase.instance.client.from('practice_logs').insert(rows);
    await queue.replaceAll(const []);
    return rows.length;
  } on PostgrestException {
    var ok = 0;
    final remain = <Map<String, dynamic>>[];
    for (final r in rows) {
      try {
        await Supabase.instance.client.from('practice_logs').insert(r);
        ok++;
      } on PostgrestException {
        // 明确拒绝:丢弃
      } catch (_) {
        remain.add(r);
      }
    }
    await queue.replaceAll(remain);
    return ok;
  } catch (_) {
    return 0; // 仍离线,下次再试
  }
}

var _sessionFlushDone = false;

/// 每会话一次的自动补传(首页登录态触发);补传成功给轻提示并刷新统计
void scheduleOfflineFlush(BuildContext context, WidgetRef ref) {
  if (_sessionFlushDone) return;
  _sessionFlushDone = true;
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  Future(() async {
    final flushed = await flushOfflineLogs(ref);
    if (flushed > 0) {
      ref.invalidate(myRecentSelfLogsProvider);
      ref.invalidate(myDailyStatsProvider);
      ref.invalidate(myTotalsProvider);
      messenger?.showSnackBar(SnackBar(content: Text(l10n.offlineFlushed)));
    }
  });
}
