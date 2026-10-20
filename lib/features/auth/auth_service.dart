import 'dart:convert';

import 'package:http/http.dart' as http;

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message; // never includes request bodies (no passwords)
}

class Session {
  const Session({required this.accessToken, required this.refreshToken, required this.expiresAt, required this.userId, required this.email, this.displayName});
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String userId;
  final String email;
  final String? displayName;

  bool get isExpired => DateTime.now().isAfter(expiresAt.subtract(const Duration(seconds: 30)));

  Session copyWith({String? displayName}) => Session(
      accessToken: accessToken, refreshToken: refreshToken, expiresAt: expiresAt, userId: userId, email: email, displayName: displayName ?? this.displayName);

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'expires_at': expiresAt.millisecondsSinceEpoch,
        'user_id': userId,
        'email': email,
        'display_name': displayName,
      };

  static Session? fromJson(Map<String, dynamic> j) {
    try {
      return Session(
        accessToken: j['access_token'] as String,
        refreshToken: j['refresh_token'] as String,
        expiresAt: DateTime.fromMillisecondsSinceEpoch(j['expires_at'] as int),
        userId: j['user_id'] as String,
        email: j['email'] as String,
        displayName: j['display_name'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

class SignUpResult {
  const SignUpResult({this.session, required this.needsEmailConfirmation});
  final Session? session;
  final bool needsEmailConfirmation;
}

/// Talks to Supabase Auth (GoTrue) over its public REST API with the anon/publishable key.
/// Passwords exist only in the request body of a single call and are never stored or logged.
class AuthService {
  AuthService({required this.baseUrl, required this.anonKey, http.Client? client}) : _http = client ?? http.Client();
  final String baseUrl;
  final String anonKey;
  final http.Client _http;

  Uri _u(String path, [Map<String, String>? q]) => Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}/auth/v1$path').replace(queryParameters: q);

  Map<String, String> _headers([String? bearer]) => {
        'apikey': anonKey,
        'Content-Type': 'application/json',
        if (bearer != null) 'Authorization': 'Bearer $bearer',
      };

  Future<Map<String, dynamic>> _send(Future<http.Response> Function() call) async {
    final http.Response r;
    try {
      r = await call().timeout(const Duration(seconds: 15));
    } catch (_) {
      throw AuthException('Can\'t reach the sign-in service. Check your connection and try again.');
    }
    Map<String, dynamic> body = {};
    try {
      final d = jsonDecode(r.body.isEmpty ? '{}' : r.body);
      if (d is Map<String, dynamic>) body = d;
    } catch (_) {}
    if (r.statusCode >= 400) throw AuthException(_friendly(r.statusCode, body));
    return body;
  }

  static String _friendly(int status, Map<String, dynamic> body) {
    final code = '${body['error_code'] ?? body['code'] ?? ''}';
    final msg = '${body['msg'] ?? body['message'] ?? body['error_description'] ?? ''}'.toLowerCase();
    if (code == 'invalid_credentials' || msg.contains('invalid login')) return 'Incorrect email or password.';
    if (code == 'email_not_confirmed' || msg.contains('not confirmed')) return 'Please confirm your email first — check your inbox.';
    if (code == 'user_already_exists' || msg.contains('already registered')) return 'An account with this email already exists. Try signing in.';
    if (code == 'weak_password' || msg.contains('password')) return 'Choose a stronger password (at least 8 characters).';
    if (status == 429 || code.contains('rate_limit')) return 'Too many attempts. Please wait a moment and try again.';
    return 'Something went wrong. Please try again.';
  }

  Session? _session(Map<String, dynamic> b) {
    final token = b['access_token'] as String?;
    final refresh = b['refresh_token'] as String?;
    final user = b['user'] as Map<String, dynamic>?;
    if (token == null || refresh == null || user == null) return null;
    final expiresIn = (b['expires_in'] as num?)?.toInt() ?? 3600;
    final meta = (user['user_metadata'] as Map?)?.cast<String, dynamic>() ?? const {};
    return Session(
      accessToken: token,
      refreshToken: refresh,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
      userId: user['id'] as String,
      email: (user['email'] as String?) ?? '',
      displayName: meta['display_name'] as String?,
    );
  }

  Future<Session> signIn(String email, String password) async {
    final b = await _send(() => _http.post(_u('/token', {'grant_type': 'password'}), headers: _headers(), body: jsonEncode({'email': email.trim(), 'password': password})));
    return _session(b) ?? (throw AuthException('Sign-in failed. Please try again.'));
  }

  Future<SignUpResult> signUp({required String email, required String password, required String displayName}) async {
    final b = await _send(() => _http.post(_u('/signup'), headers: _headers(), body: jsonEncode({'email': email.trim(), 'password': password, 'data': {'display_name': displayName.trim()}})));
    final s = _session(b);
    return SignUpResult(session: s, needsEmailConfirmation: s == null);
  }

  Future<Session> refresh(String refreshToken) async {
    final b = await _send(() => _http.post(_u('/token', {'grant_type': 'refresh_token'}), headers: _headers(), body: jsonEncode({'refresh_token': refreshToken})));
    return _session(b) ?? (throw AuthException('Your session has expired. Please sign in again.'));
  }

  Future<void> recover(String email) => _send(() => _http.post(_u('/recover'), headers: _headers(), body: jsonEncode({'email': email.trim()})));

  Future<void> signOut(String accessToken) async {
    try {
      await _http.post(_u('/logout'), headers: _headers(accessToken)).timeout(const Duration(seconds: 8));
    } catch (_) {/* local sign-out proceeds regardless */}
  }

  Future<void> updateDisplayName(String accessToken, String name) =>
      _send(() => _http.put(_u('/user'), headers: _headers(accessToken), body: jsonEncode({'data': {'display_name': name.trim()}})));
}
