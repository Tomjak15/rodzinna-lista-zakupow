class BackendConfig {
  static const serverUrl = String.fromEnvironment(
    'SERVER_URL',
    defaultValue: 'https://rodzinna-lista-zakupow--tomjak15.replit.app',
  );

  static bool get isConfigured => serverUrl.startsWith('http');

  static String get normalizedServerUrl => serverUrl.endsWith('/')
      ? serverUrl.substring(0, serverUrl.length - 1)
      : serverUrl;
}
