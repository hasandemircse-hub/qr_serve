/// Cloud API kökü. İsterseniz: `flutter run --dart-define=CLOUD_BASE_URL=https://cloud.example.com`
///
/// Üretimde Cloud Caddy aynı host'tan hem statik web'i hem API'yi servis ettiği için
/// `--dart-define=CLOUD_BASE_URL=` (boş) verilebilir → istekler sayfa origin'ine gider.
class AppConfig {
  AppConfig._();

  static const cloudBaseUrl = String.fromEnvironment(
    'CLOUD_BASE_URL',
    defaultValue: 'http://127.0.0.1:8080',
  );
}
