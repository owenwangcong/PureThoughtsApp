import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/settings.dart';
import 'features/auth/auth_screen.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/settings/settings_screen.dart';

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
    ],
  );
});
