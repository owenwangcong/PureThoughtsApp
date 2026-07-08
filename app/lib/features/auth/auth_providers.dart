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

/// 当前用户的 profiles 行;未登录为 null
final myProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return Supabase.instance.client.from('profiles').select().eq('id', user.id).maybeSingle();
});
