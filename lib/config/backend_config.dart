class BackendConfig {
  static const serverUrl = String.fromEnvironment(
    'SERVER_URL',
    defaultValue:
        'https://grams-tribune-handhelds-recognised.trycloudflare.com',
  );

  static bool get isConfigured => serverUrl.startsWith('http');

  static String get normalizedServerUrl => serverUrl.endsWith('/')
      ? serverUrl.substring(0, serverUrl.length - 1)
      : serverUrl;
}
