/// Supabase connection settings. The anon key is public by design, but is
/// supplied at build time so it stays out of source control:
/// `flutter run --dart-define=SUPABASE_ANON_KEY=...`
abstract class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://rjdhlodlnoxmctwwmkku.supabase.co',
  );
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const bucket = 'stiksy_bucket';
  static const catalogPath = 'v1/catalog.json';
  static bool get configured => anonKey.isNotEmpty;
}
