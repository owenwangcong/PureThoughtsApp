import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/env.dart';
import 'core/prefs.dart';
import 'core/settings.dart';
import 'core/theme/app_theme.dart';
import 'features/reminders/reminder_scheduler.dart';
import 'l10n/gen/app_localizations.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  // debug 版应用内环境切换(设置页「開發環境」):写入偏好,重启生效;
  // release 构建 kDebugMode 恒 false,该分支被编译器剔除
  var supabaseUrl = Env.supabaseUrl;
  var supabaseKey = Env.supabaseAnonKey;
  if (kDebugMode &&
      prefs.getString(PrefKeys.debugEnv) == 'prod' &&
      Env.prodSupabaseAnonKey.isNotEmpty) {
    supabaseUrl = Env.prodSupabaseUrl;
    supabaseKey = Env.prodSupabaseAnonKey;
  }
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);

  // 正念提醒本地通知基建(P2.8):初始化时区与插件;已注册的按周通知由 OS 持有,
  // 无需每次启动重排。失败不致命(内部已 try 包裹)。
  await ReminderScheduler.instance.init();

  final app = ProviderScope(
    overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    child: const PureThoughtsApp(),
  );
  if (Env.sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) => options.dsn = Env.sentryDsn,
      appRunner: () => runApp(app),
    );
  } else {
    runApp(app);
  }
}

class PureThoughtsApp extends ConsumerWidget {
  const PureThoughtsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final fontScale = ref.watch(fontScaleProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      routerConfig: ref.watch(routerProvider),
      locale: locale,
      supportedLocales: const [LocaleController.zhHant, LocaleController.zhHans],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      // 宣纸 + 古铜金双主题(PRD v0.5.4 §11)
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      // 全局字号缩放:与系统缩放叠乘,布局须适配大字号(NFR)
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final composed = TextScaler.linear(mq.textScaler.scale(fontScale));
        return MediaQuery(data: mq.copyWith(textScaler: composed), child: child!);
      },
    );
  }
}
