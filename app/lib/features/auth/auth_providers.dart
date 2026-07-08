import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authStateChangesProvider = StreamProvider<AuthState>(
  (ref) => Supabase.instance.client.auth.onAuthStateChange,
);

/// 当前登录用户;未登录为 null(匿名浏览是合法状态,PRD §2)
final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateChangesProvider);
  return Supabase.instance.client.auth.currentUser;
});
