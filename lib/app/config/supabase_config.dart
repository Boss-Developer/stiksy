abstract class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://rjdhlodlnoxmctwwmkku.supabase.co',
  );
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const bucket = 'stiksy_bucket';
  static bool get configured => anonKey.isNotEmpty;
}
