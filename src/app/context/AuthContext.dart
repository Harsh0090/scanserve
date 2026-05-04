import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/apiClient.dart';
import '../../services/firebase_messaging_service.dart';

class AuthState {
  final Map<String, dynamic>? user;
  final bool loading2;

  AuthState({this.user, this.loading2 = true});

  AuthState copyWith({Map<String, dynamic>? user, bool? loading2, bool clearUser = false}) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      loading2: loading2 ?? this.loading2,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    loadSession();
    return AuthState(loading2: true);
  }

  Future<void> loadSession() async {
    try {
      final res = await apiFetch('/api/auth/me');
      print("🔍 AuthContext: Load Session Response: $res");
      final userData = res['data'] ?? res;
      final bool looksSubstantial = (userData is Map && (userData.containsKey('token') || userData.containsKey('restaurantId') || userData.containsKey('role')));

      if (res['success'] == true || (res is Map && looksSubstantial)) {
        print("✅ AuthContext: Session Loaded Successfully");
        state = state.copyWith(user: userData is Map<String, dynamic> ? userData : res, loading2: false);
        // Register Push Token (Un-await to avoid blocking UI)
        FirebaseMessagingService().registerToken();
      } else {
        print("⚠️ AuthContext: Session response invalid or not successful");
        state = state.copyWith(clearUser: true, loading2: false);
      }
    } catch (e) {
      print("❌ AuthContext: Failed to load session: $e");
      // If we are not logged in, apiFetch might throw. Just set loading to false.
      state = state.copyWith(clearUser: true, loading2: false);
    }
  }

  /// Manually update the user data (e.g., after successful login)
  void setUserData(Map<String, dynamic> data) {
    state = state.copyWith(user: data, loading2: false);
    FirebaseMessagingService().registerToken();
  }

  void reload() => loadSession();

  Future<void> logout() async {
    try {
      await apiFetch('/api/auth/logout', method: 'POST');
      state = state.copyWith(clearUser: true, loading2: false);
    } catch (e) {
      state = state.copyWith(clearUser: true, loading2: false);
    }
  }

  void mockLogin() {
    state = state.copyWith(
      user: {
        'restaurantId': 'mock123',
        'role': 'owner',
        'permissionLevel': 'FULL',
        'businessType': 'RESTAURANT',
        'name': 'Demo Admin',
      },
      loading2: false,
    );
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
