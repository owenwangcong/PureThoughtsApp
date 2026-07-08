/// 编译期环境配置,经 --dart-define 覆盖;默认指向本地 Supabase 栈。
///
/// 默认 anon key 是 Supabase CLI 本地栈的公开演示密钥(所有本地环境相同),非机密。
/// 生产构建必须传入自托管实例的真实值:
///   flutter build ... --dart-define=SUPABASE_URL=https://api.example.org \
///                     --dart-define=SUPABASE_ANON_KEY=...
///
/// 注意:Android 模拟器访问宿主机需用 --dart-define=SUPABASE_URL=http://10.0.2.2:54321
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'http://127.0.0.1:54321',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0',
  );

  /// 为空则不启用 Sentry(本地开发默认关闭)
  static const sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');
}
