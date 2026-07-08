import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/env.dart';
import 'core/settings.dart';
import 'l10n/gen/app_localizations.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabaseAnonKey);

  const app = ProviderScope(child: PureThoughtsApp());
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
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF8D6E63), // 沉静的暖木色基调
      ),
      // 全局字号缩放:与系统缩放叠乘,布局须适配大字号(NFR)
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final composed = TextScaler.linear(mq.textScaler.scale(fontScale));
        return MediaQuery(data: mq.copyWith(textScaler: composed), child: child!);
      },
    );
  }
}
