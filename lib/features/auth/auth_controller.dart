import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../app/providers.dart';
import '../../core/config/app_config.dart';
import 'auth_service.dart';

enum AuthStatus { unknown, signedOut, signedIn, demo }

class AuthState {
  const AuthState({this.status = AuthStatus.unknown, this.session, this.busy = false, this.error, this.info});
  final AuthStatus status;
  final Session? session;
  final bool busy;
  final String? error;
  final String? info;

  bool get isIn => status == AuthStatus.signedIn || status == AuthStatus.demo;
  String get displayName => status == AuthStatus.demo ? 'Guest' : (session?.displayName?.trim().isNotEmpty == true ? session!.displayName!.trim() : (session?.email.split('@').first ?? ''));
  String get email => status == AuthStatus.demo ? 'Sample workspace' : (session?.email ?? '');

  AuthState copyWith({AuthStatus? status, Session? session, bool? busy, String? error, String? info, bool clearMessages = false}) => AuthState(
        status: status ?? this.status,
        session: session ?? this.session,
        busy: busy ?? this.busy,
        error: clearMessages ? null : (error ?? this.error),
        info: clearMessages ? null : (info ?? this.info),
      );
}

abstract class SessionStore {
  Future<Session?> read();
  Future<void> write(Session s);
  Future<void> clear();
}

/// Tokens go to the platform keystore/keychain (Android Keystore, iOS Keychain, Windows DPAPI). Passwords are never stored.
class SecureSessionStore implements SessionStore {
  SecureSessionStore([FlutterSecureStorage? s]) : _s = s ?? const FlutterSecureStorage();
  final FlutterSecureStorage _s;
  static const _key = 'finance_platform_session';

  @override
  Future<Session?> read() async {
    try {
      final raw = await _s.read(key: _key);
      return raw == null ? null : Session.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(Session s) async {
    try {
      await _s.write(key: _key, value: jsonEncode(s.toJson()));
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    try {
      await _s.delete(key: _key);
    } catch (_) {}
  }
}

class MemorySessionStore implements SessionStore {
  Session? _v;
  @override
  Future<Session?> read() async => _v;
  @override
  Future<void> write(Session s) async => _v = s;
  @override
  Future<void> clear() async => _v = null;
}

final sessionStoreProvider = Provider<SessionStore>((_) => SecureSessionStore());
final authServiceProvider = Provider<AuthService>((_) => AuthService(baseUrl: AppConfig.supabaseUrl, anonKey: AppConfig.supabaseAnonKey));

class AuthController extends Notifier<AuthState> {
  AuthService get _svc => ref.read(authServiceProvider);
  SessionStore get _store => ref.read(sessionStoreProvider);

  @override
  AuthState build() {
    Future.microtask(restore);
    return const AuthState();
  }

  Future<void> restore() async {
    if (!AppConfig.authConfigured) {
      state = AuthState(status: AppConfig.startInDemo ? AuthStatus.demo : AuthStatus.signedOut);
      return;
    }
    var s = await _store.read();
    if (s != null && s.isExpired) {
      try {
        s = await _svc.refresh(s.refreshToken);
        await _store.write(s);
      } on AuthException {
        await _store.clear();
        s = null;
      }
    }
    state = s == null ? const AuthState(status: AuthStatus.signedOut) : AuthState(status: AuthStatus.signedIn, session: s);
  }

  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(busy: true, clearMessages: true);
    try {
      final s = await _svc.signIn(email, password);
      await _store.write(s);
      state = AuthState(status: AuthStatus.signedIn, session: s);
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(busy: false, error: e.message);
      return false;
    }
  }

  /// Returns true when an account was created (signed in, or awaiting email confirmation).
  Future<bool> signUp({required String name, required String email, required String password}) async {
    state = state.copyWith(busy: true, clearMessages: true);
    try {
      final r = await _svc.signUp(email: email, password: password, displayName: name);
      if (r.session != null) {
        await _store.write(r.session!);
        state = AuthState(status: AuthStatus.signedIn, session: r.session);
      } else {
        state = state.copyWith(busy: false, info: 'Account created. Check $email for a confirmation link, then sign in.');
      }
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(busy: false, error: e.message);
      return false;
    }
  }

  Future<bool> sendReset(String email) async {
    state = state.copyWith(busy: true, clearMessages: true);
    try {
      await _svc.recover(email);
      // Same message whether or not the email exists, so accounts cannot be enumerated.
      state = state.copyWith(busy: false, info: 'If an account exists for $email, a reset link is on its way.');
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(busy: false, error: e.message);
      return false;
    }
  }

  void enterDemo() => state = const AuthState(status: AuthStatus.demo);

  Future<void> signOut() async {
    final s = state.session;
    if (s != null) await _svc.signOut(s.accessToken);
    await _store.clear();
    state = const AuthState(status: AuthStatus.signedOut);
  }

  void clearMessages() => state = state.copyWith(clearMessages: true);

  /// A valid access token, refreshing it first when it is about to expire.
  Future<String?> accessToken() async {
    var s = state.session;
    if (s == null) return null;
    if (s.isExpired) {
      try {
        s = await _svc.refresh(s.refreshToken);
        await _store.write(s);
        state = state.copyWith(session: s);
      } on AuthException {
        await signOut();
        return null;
      }
    }
    return s.accessToken;
  }

  /// Updates the display name in Supabase Auth metadata and in the shared profile row
  /// (the same row the Analyzer reads, which is how the two apps stay in sync).
  Future<String?> updateName(String name) async {
    final s = state.session;
    final token = await accessToken();
    if (s == null || token == null) return 'You are not signed in.';
    try {
      await _svc.updateDisplayName(token, name);
    } on AuthException catch (e) {
      return e.message;
    }
    final updated = state.session!.copyWith(displayName: name.trim());
    await _store.write(updated);
    state = state.copyWith(session: updated);
    final ok = await ref.read(apiClientProvider).patchProfile(token, {'display_name': name.trim()});
    return ok ? null : 'Saved to your account, but the shared profile service is unreachable right now.';
  }
}

final authProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

class ProfileInfo {
  const ProfileInfo({required this.displayName, required this.defaultCurrency, required this.timezone});
  final String? displayName;
  final String defaultCurrency;
  final String timezone;
}

/// Shared profile from the backend (null when signed out, in demo mode, or the backend is unreachable).
final profileProvider = FutureProvider.autoDispose<ProfileInfo?>((ref) async {
  final auth = ref.watch(authProvider);
  if (auth.status != AuthStatus.signedIn) return null;
  final token = await ref.read(authProvider.notifier).accessToken();
  if (token == null) return null;
  final j = await ref.read(apiClientProvider).fetchProfile(token);
  if (j == null) return null;
  return ProfileInfo(displayName: j['display_name'] as String?, defaultCurrency: (j['default_currency'] as String?) ?? 'INR', timezone: (j['timezone'] as String?) ?? 'UTC');
});
