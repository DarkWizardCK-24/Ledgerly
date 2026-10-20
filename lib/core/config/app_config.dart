/// Build-time configuration, supplied with `--dart-define`. Only PUBLIC values belong here
/// (the Supabase anon / publishable key). Never put a service-role key in a client app.
abstract final class AppConfig {
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8000');
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Dev/CI only: when Supabase isn't configured, skip the sign-in screen and open sample mode.
  static const startInDemo = bool.fromEnvironment('START_IN_DEMO');

  static bool get authConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
