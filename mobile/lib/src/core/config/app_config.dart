class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  static const bool firebaseEnabled = bool.fromEnvironment(
    'FIREBASE_ENABLED',
  );

  static const String firebaseApiKey =
      String.fromEnvironment('FIREBASE_API_KEY');
  static const String firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const String firebaseMessagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const String firebaseProjectId =
      String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const String firebaseAuthDomain =
      String.fromEnvironment('FIREBASE_AUTH_DOMAIN');

  static const String publicAppUrl = String.fromEnvironment(
    'PUBLIC_APP_URL',
    defaultValue: '',
  );
}
