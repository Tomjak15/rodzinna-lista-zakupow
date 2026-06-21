class BackendConfig {
  static const serverUrl = String.fromEnvironment(
    'SERVER_URL',
    defaultValue:
        'https://rodzinna-lista-zakupow-api.rodzinna-lista-zakupow-tomek.workers.dev',
  );

  static bool get isConfigured => serverUrl.startsWith('http');

  static String get normalizedServerUrl => serverUrl.endsWith('/')
      ? serverUrl.substring(0, serverUrl.length - 1)
      : serverUrl;
}
