/// Defines API endpoints for the LayerX app.
abstract class AppUrls {
  AppUrls._();

  static const String baseAPIURL = 'https://api.example.com/';

  static const String login = 'auth/login';
  static const String logout = 'auth/logout';
  static const String signup = 'auth/signup';
  static const String updateAccount = 'auth/update';
  static const String appSettings = 'settings';
}
