import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/settings.dart';
import 'features/auth/auth_screen.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/community/community_screen.dart';
import 'features/events/calendar_screen.dart';
import 'features/events/event_agenda_editor.dart';
import 'features/events/event_detail_screen.dart';
import 'features/events/event_types_screen.dart';
import 'features/events/occurrence_utils.dart';
import 'features/dashboard/my_dashboard_screen.dart';
import 'features/legal/privacy_screen.dart';
import 'features/live/live_screen.dart';
import 'features/live/video_player_screen.dart';
import 'features/live/web_view_screen.dart';
import 'features/logs/community_logs_screen.dart';
import 'features/logs/report_log_screen.dart';
import 'features/moderation/admin_notify_screen.dart';
import 'features/moderation/admin_reports_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/qa/qa_detail_screen.dart';
import 'features/qa/qa_models.dart';
import 'features/qa/qa_search_screen.dart';
import 'features/qa/qa_tag_picker_screen.dart';
import 'features/reminders/mindfulness_screen.dart';
import 'features/reminders/reminder_help_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/study_qa/study_qa_compose_screen.dart';
import 'features/study_qa/study_qa_list_screen.dart';
import 'features/study_qa/study_qa_thread_screen.dart';
import 'features/tools/counter_screen.dart';
import 'features/tools/timer_screen.dart';
import 'features/tools/tools_screen.dart';
import 'features/vows/vows_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final onboarded = ref.watch(onboardingDoneProvider);
  return GoRouter(
    // 匿名可浏览(PRD §2),不强制登录;仅首启引导做强制跳转
    redirect: (context, state) {
      if (!onboarded && state.matchedLocation != '/onboarding') return '/onboarding';
      if (onboarded && state.matchedLocation == '/onboarding') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      // ---- 共修報數(PRD v0.6.0 §3:去群化后的单一共修体) ----
      GoRoute(path: '/community', builder: (context, state) => const CommunityScreen()),
      GoRoute(
          path: '/community/logs',
          builder: (context, state) => const CommunityLogsScreen()),
      GoRoute(path: '/report', builder: (context, state) => const ReportLogScreen()),

      // 旧「群」路由的兼容重定向:线上旧版 App 的收藏、以及服务端仍在发的
      // `announcement → /groups/<id>` 深链都会落到这里(设计 §5.9 双向兼容)。
      // 新版普及后随 P9.8 一并撤除。
      GoRoute(path: '/groups', redirect: (_, _) => '/community'),
      GoRoute(path: '/groups/:gid', redirect: (_, _) => '/community'),
      GoRoute(path: '/groups/:gid/report', redirect: (_, _) => '/report'),
      GoRoute(path: '/groups/:gid/logs', redirect: (_, _) => '/community/logs'),
      GoRoute(path: '/groups/:gid/stats', redirect: (_, _) => '/community'),
      GoRoute(path: '/dashboard', builder: (context, state) => const MyDashboardScreen()),
      GoRoute(path: '/privacy', builder: (context, state) => const PrivacyScreen()),
      GoRoute(
          path: '/notifications',
          builder: (context, state) => const NotificationsScreen()),
      GoRoute(path: '/vows', builder: (context, state) => const VowsScreen()),
      GoRoute(path: '/tools', builder: (context, state) => const ToolsScreen()),
      GoRoute(path: '/calendar', builder: (context, state) => const CalendarScreen()),
      GoRoute(
          path: '/calendar/types',
          builder: (context, state) => const EventTypesScreen()),
      // 活动详情整页(取代 bottom sheet;经 extra 传 Occurrence)
      GoRoute(
        path: '/calendar/event',
        builder: (context, state) =>
            EventDetailScreen(occ: state.extra as Occurrence?),
      ),
      // 管理员编辑时间表/资料(经 extra 传 event map)
      // ⚠️ 必须声明在下面的 :eventId 之前,否则 'agenda' 会被当成活动 id
      GoRoute(
        path: '/calendar/event/agenda',
        builder: (context, state) =>
            EventAgendaEditorScreen(event: state.extra as Map<String, dynamic>?),
      ),
      // 可 URL 化的活动详情(P2.16):推送 / 通知中心深链走这条。
      // 上面那条只吃内存里的 Occurrence 对象,无法用 URL 表达,推送点开只能落到日历。
      // date = occurrence_date(活动时区日期),用来定位循环活动的具体某一场。
      GoRoute(
        path: '/calendar/event/:eventId',
        builder: (context, state) => EventDetailScreen(
          eventId: state.pathParameters['eventId'],
          dateKey: state.uri.queryParameters['date'],
        ),
      ),
      GoRoute(path: '/live', builder: (context, state) => const LiveScreen()),
      GoRoute(
        path: '/watch/:vid',
        builder: (context, state) => VideoPlayerScreen(
          videoId: state.pathParameters['vid']!,
          startSeconds: int.tryParse(state.uri.queryParameters['t'] ?? ''),
        ),
      ),
      // 往期问答检索(PRD §6;匿名可用)
      GoRoute(path: '/qa', builder: (context, state) => const QaSearchScreen()),
      GoRoute(
        path: '/qa/tags',
        builder: (context, state) => QaTagPickerScreen(
          initial: (state.extra as List<String>?) ?? const [],
        ),
      ),
      GoRoute(
        path: '/qa/detail',
        builder: (context, state) =>
            QaDetailScreen(segment: state.extra as QaSegment?),
      ),
      // 学修问答(PRD §16;登录后可用,入口经首页 _guard)
      GoRoute(
          path: '/study-qa',
          builder: (context, state) => const StudyQaListScreen()),
      GoRoute(
          path: '/study-qa/new',
          builder: (context, state) => const StudyQaComposeScreen()),
      GoRoute(
        path: '/study-qa/:tid',
        builder: (context, state) => StudyQaThreadScreen(
          threadId: state.pathParameters['tid']!,
          // 管理员语境(P8.6):列表管理 tab 与 qa_question 通知深链带 ?as=admin
          asAdmin: state.uri.queryParameters['as'] == 'admin',
        ),
      ),
      GoRoute(
        path: '/webview',
        builder: (context, state) => WebViewScreen(
          url: state.uri.queryParameters['url']!,
          title: state.uri.queryParameters['title'],
          applyFontScale: state.uri.queryParameters['zoom'] == '1',
          prefillName: state.uri.queryParameters['name'],
          prefillEmail: state.uri.queryParameters['mail'],
          externalUrl: state.uri.queryParameters['ext'],
        ),
      ),
      GoRoute(path: '/tools/timer', builder: (context, state) => const TimerScreen()),
      GoRoute(path: '/tools/counter', builder: (context, state) => const CounterScreen()),
      GoRoute(
          path: '/tools/mindfulness',
          builder: (context, state) => const MindfulnessScreen()),
      GoRoute(
          path: '/tools/mindfulness/help',
          builder: (context, state) => const ReminderHelpScreen()),
      GoRoute(
          path: '/admin/reports',
          builder: (context, state) => const AdminReportsScreen()),
      GoRoute(
          path: '/admin/notify',
          builder: (context, state) => const AdminNotifyScreen()),
    ],
  );
});
