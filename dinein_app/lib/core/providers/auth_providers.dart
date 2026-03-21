import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_repository.dart';

/// Stream of Supabase auth state changes.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return AuthRepository.instance.onAuthStateChange;
});

/// Current authenticated user (nullable).
final currentUserProvider = Provider<User?>((ref) {
  return AuthRepository.instance.currentUser;
});

/// Current user's profile role.
final userProfileProvider = FutureProvider<String?>((ref) async {
  try {
    final user = ref.watch(currentUserProvider);
    if (user == null) return null;
    return await AuthRepository.instance.getUserRole(user.id);
  } catch (_) {
    return null;
  }
});
