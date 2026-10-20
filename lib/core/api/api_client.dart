import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class ApiStatus {
  const ApiStatus({required this.apiUp, required this.databaseReady, this.detail});
  final bool apiUp;
  final bool databaseReady;
  final String? detail;
}

class ApiClient {
  ApiClient({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;
  static String get _base => AppConfig.apiBaseUrl;

  Future<ApiStatus> checkStatus() async {
    try {
      final h = await _http.get(Uri.parse('$_base/api/v1/health')).timeout(const Duration(seconds: 5));
      if (h.statusCode != 200) return const ApiStatus(apiUp: false, databaseReady: false);
      final r = await _http.get(Uri.parse('$_base/api/v1/ready')).timeout(const Duration(seconds: 8));
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      return ApiStatus(apiUp: true, databaseReady: r.statusCode == 200, detail: body['database'] as String?);
    } catch (_) {
      return const ApiStatus(apiUp: false, databaseReady: false, detail: 'Backend unreachable');
    }
  }

  Map<String, String> _auth(String token) => {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};

  /// The shared profile row (same one the Analyzer uses). Null on any failure.
  Future<Map<String, dynamic>?> fetchProfile(String token) async {
    try {
      final r = await _http.get(Uri.parse('$_base/api/v1/profiles/me'), headers: _auth(token)).timeout(const Duration(seconds: 8));
      return r.statusCode == 200 ? jsonDecode(r.body) as Map<String, dynamic> : null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> patchProfile(String token, Map<String, dynamic> changes) async {
    try {
      final r = await _http.patch(Uri.parse('$_base/api/v1/profiles/me'), headers: _auth(token), body: jsonEncode(changes)).timeout(const Duration(seconds: 8));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
