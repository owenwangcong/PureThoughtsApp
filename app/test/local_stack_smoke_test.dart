import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// P0.6 验收测试:匿名身份从本地 Supabase 栈读到公开表数据。
/// 依赖本地栈运行中(npx supabase start);未运行时跳过而非失败。
void main() {
  const url = 'http://127.0.0.1:54321';
  const anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

  Future<bool> stackReachable() async {
    try {
      final socket = await Socket.connect('127.0.0.1', 54321,
          timeout: const Duration(seconds: 2));
      await socket.close();
      return true;
    } on SocketException {
      return false;
    }
  }

  test('匿名可读全局功课清单(公开表),读不到报数表', () async {
    if (!await stackReachable()) {
      markTestSkipped('本地 Supabase 栈未运行,跳过(npx supabase start 后重跑)');
      return;
    }

    final client = SupabaseClient(url, anonKey);
    addTearDown(() => client.dispose());

    // 公开表:全局功课清单(seed 5 项)
    final types = await client
        .from('practice_types')
        .select('id, name_hant, name_hans, unit')
        .isFilter('group_id', null)
        .order('sort_order', ascending: true);
    expect(types.length, greaterThanOrEqualTo(5));
    expect(types.first['name_hant'], isNotEmpty);

    // 受保护表:匿名访问必须被拒(未授表级 GRANT)
    await expectLater(
      client.from('practice_logs').select('id'),
      throwsA(isA<PostgrestException>()),
    );
  });
}
