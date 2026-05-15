/// Cloud API kökü. İsterseniz: `flutter run --dart-define=CLOUD_BASE_URL=https://cloud.example.com`
class AppConfig {
  AppConfig._();

  static const cloudBaseUrl = String.fromEnvironment(
    'CLOUD_BASE_URL',
    defaultValue: 'http://127.0.0.1:8080',
  );
}
