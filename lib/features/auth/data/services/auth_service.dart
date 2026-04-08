import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:relateos/config/supabase_config.dart';
import 'package:relateos/features/auth/data/models/user_model.dart';

/// Riverpod provider for authentication
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Current user state
final currentUserProvider = StateNotifierProvider<CurrentUserNotifier, AsyncValue<UserModel?>>((ref) {
  final authService = ref.watch(authServiceProvider);
  return CurrentUserNotifier(authService);
});

/// Auth state (logged in or not)
final authStateProvider = StreamProvider<RelateAuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateStream;
});

class AuthService {
  late final SupabaseClient _supabase;
  
  AuthService() {
    _supabase = supabaseClient;
  }
  
  Stream<RelateAuthState> get authStateStream {
    return _supabase.auth.onAuthStateChange.asyncMap((event) async {
      final session = event.session;
      if (session != null) {
        final user = await fetchUserData(session.user.id);
        return RelateAuthState.authenticated(user: user);
      } else {
        return const RelateAuthState.unauthenticated();
      }
    });
  }
  
  Future<UserModel?> getCurrentUser() async {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      return null;
    }
    return fetchUserData(session.user.id);
  }
  
  Future<UserModel> fetchUserData(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .single();
      
      return UserModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch user data: $e');
    }
  }
  
  /// Sign in with Apple
  Future<bool> signInWithApple() async {
    try {
      return await _supabase.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: 'io.supabase.flutter-app://callback',
      );
    } catch (e) {
      throw Exception('Apple Sign-In failed: $e');
    }
  }
  
  /// Sign in with Google
  Future<bool> signInWithGoogle() async {
    try {
      return await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.flutter-app://callback',
      );
    } catch (e) {
      throw Exception('Google Sign-In failed: $e');
    }
  }
  
  /// Sign in with email/password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception('Sign-in failed: $e');
    }
  }
  
  /// Sign up with email/password
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      
      // Create user record
      if (response.session?.user != null) {
        await _createUserRecord(response.session!.user);
      }
      
      return response;
    } catch (e) {
      throw Exception('Sign-up failed: $e');
    }
  }
  
  /// Create initial user record
  Future<void> _createUserRecord(User user) async {
    try {
      // Check if user already exists
      try {
        await _supabase
            .from('users')
            .select()
            .eq('id', user.id)
            .single();
        // User exists, skip creation
        return;
      } catch (_) {
        // User doesn't exist, create it
      }
      
      await _supabase.from('users').insert({
        'id': user.id,
        'created_at': DateTime.now().toIso8601String(),
        'preferred_language': 'zh-HK',
        'subscription_tier': 'free',
        'onboarding_completed': false,
      });
    } catch (e) {
      // Ignore duplicate or transient record creation failures.
    }
  }
  
  /// Update user onboarding status
  Future<void> completeOnboarding(String userId) async {
    try {
      await _supabase
          .from('users')
          .update({'onboarding_completed': true})
          .eq('id', userId);
    } catch (e) {
      throw Exception('Failed to complete onboarding: $e');
    }
  }
  
  /// Store baseline weights from quiz
  Future<void> saveBaselineWeights(
    String userId,
    double w1,
    double w2,
    double w3,
    int quizPercentile,
  ) async {
    try {
      await _supabase
          .from('users')
          .update({
            'baseline_weights': {
              'w1': w1,
              'w2': w2,
              'w3': w3,
              'quiz_percentile': quizPercentile,
            },
          })
          .eq('id', userId);
    } catch (e) {
      throw Exception('Failed to save baseline weights: $e');
    }
  }
  
  /// Log keyboard consent
  Future<void> logKeyboardConsent(String userId) async {
    try {
      await _supabase
          .from('users')
          .update({'consent_keyboard_granted': DateTime.now().toIso8601String()})
          .eq('id', userId);
    } catch (e) {
      throw Exception('Failed to log keyboard consent: $e');
    }
  }
  
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('Sign-out failed: $e');
    }
  }
}

/// Auth state
sealed class RelateAuthState {
  const RelateAuthState();
  
  const factory RelateAuthState.authenticated({
    required UserModel? user,
  }) = AuthenticatedState;
  
  const factory RelateAuthState.unauthenticated() = UnauthenticatedState;
}

class AuthenticatedState extends RelateAuthState {
  final UserModel? user;
  const AuthenticatedState({required this.user});
}

class UnauthenticatedState extends RelateAuthState {
  const UnauthenticatedState();
}

/// Notifier for managing current user state
class CurrentUserNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  final AuthService _authService;
  
  CurrentUserNotifier(this._authService) : super(const AsyncValue.loading()) {
    _loadCurrentUser();
  }
  
  Future<void> _loadCurrentUser() async {
    try {
      final user = await _authService.getCurrentUser();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
  
  Future<void> refresh() async {
    await _loadCurrentUser();
  }
}
