/// Supabase connection settings. The anon key is public by design, but is
/// supplied at build time so it stays out of source control:
/// `flutter run --dart-define=SUPABASE_ANON_KEY=...`
abstract class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://rjdhlodlnoxmctwwmkku.supabase.co',
  );
  static const anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJqZGhsb2Rsbm94bWN0d3dta2t1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE0NDg4NzMsImV4cCI6MjEwNzAyNDg3M30.uElQOVg4ZPkMZgHshXUiSYJV25_SBrXSng2rKj9ac50',
  );
  static const bucket = 'stiksy_bucket';
  static const catalogPath = 'v1/catalog.json';
  static bool get configured => anonKey.isNotEmpty;
}
