import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/settings.dart';
import 'features/auth/auth_screen.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/dashboard/group_stats_screen.dart';
import 'features/events/calendar_screen.dart';
import 'features/dashboard/my_dashboard_screen.dart';
import 'features/groups/group_detail_screen.dart';
import 'features/groups/groups_screen.dart';
import 'features/legal/privacy_screen.dart';
import 'features/live/live_screen.dart';
import 'features/live/video_player_screen.dart';
import 'features/live/web_view_screen.dart';
import 'features/logs/group_logs_screen.dart';
import 'features/logs/report_log_screen.dart';
import 'features/moderation/admin_reports_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/scriptures/scriptures_screen.dart';
import 'features/settings/settings_screen.dart';
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
      GoRoute(path: '/groups', builder: (context, state) => const GroupsScreen()),
      GoRoute(
        path: '/groups/:gid',
        builder: (context, state) =>
            GroupDetailScreen(groupId: state.pathParameters['gid']!),
      ),
      GoRoute(
        path: '/groups/:gid/report',
        builder: (context, state) =>
            ReportLogScreen(groupId: state.pathParameters['gid']!),
      ),
      GoRoute(
        path: '/groups/:gid/logs',
        builder: (context, state) =>
            GroupLogsScreen(groupId: state.pathParameters['gid']!),
      ),
      GoRoute(
        path: '/groups/:gid/stats',
        builder: (context, state) =>
            GroupStatsScreen(groupId: state.pathParameters['gid']!),
      ),
      GoRoute(path: '/dashboard', builder: (context, state) => const MyDashboardScreen()),
      GoRoute(path: '/privacy', builder: (context, state) => const PrivacyScreen()),
      GoRoute(
          path: '/notifications',
          builder: (context, state) => const NotificationsScreen()),
      GoRoute(path: '/vows', builder: (context, state) => const VowsScreen()),
      GoRoute(path: '/tools', builder: (context, state) => const ToolsScreen()),
      GoRoute(path: '/calendar', builder: (context, state) => const CalendarScreen()),
      GoRoute(path: '/live', builder: (context, state) => const LiveScreen()),
      GoRoute(
        path: '/watch/:vid',
        builder: (context, state) =>
            VideoPlayerScreen(videoId: state.pathParameters['vid']!),
      ),
      GoRoute(
        path: '/webview',
        builder: (context, state) => WebViewScreen(
          url: state.uri.queryParameters['url']!,
          title: state.uri.queryParameters['title'],
          applyFontScale: state.uri.queryParameters['zoom'] == '1',
        ),
      ),
      GoRoute(
          path: '/scriptures',
          builder: (context, state) => const ScripturesScreen()),
      GoRoute(path: '/tools/timer', builder: (context, state) => const TimerScreen()),
      GoRoute(path: '/tools/counter', builder: (context, state) => const CounterScreen()),
      GoRoute(
          path: '/admin/reports',
          builder: (context, state) => const AdminReportsScreen()),
    ],
  );
});
