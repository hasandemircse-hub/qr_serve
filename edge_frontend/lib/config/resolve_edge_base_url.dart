import 'package:flutter/foundation.dart' show kIsWeb;

/// Flutter Web'de sayfa `http://localhost:…` iken API tabanı `http://127.0.0.1:…`
/// olursa tarayıcıda özel ağ / loopback uyumsuzluğu nedeniyle HTTP ve WebSocket
/// bağlantıları başarısız olabiliyor. Bu durumda API host'unu sayfa ile aynı
/// loopback takma adına çekeriz (port yapılandırmadan kalır).
String resolveEdgeBaseUrl(String configured) {
  if (!kIsWeb) return configured;
  final raw = configured.trim();
  // Prod build: --dart-define=EDGE_BASE_URL= (boş) verilirse sayfa origin'ini kullan.
  // Bu sayede Caddy aynı host'tan hem statik web'i hem API'yi servis edebilir.
  if (raw.isEmpty) {
    final base = Uri.base;
    if (base.hasScheme && base.host.isNotEmpty) {
      return Uri(
        scheme: base.scheme,
        host: base.host,
        port: base.hasPort ? base.port : null,
      ).toString();
    }
    return configured;
  }
  final Uri configuredUri;
  try {
    configuredUri = Uri.parse(raw);
  } catch (_) {
    return configured;
  }
  if (!configuredUri.hasScheme || configuredUri.host.isEmpty) {
    return configured;
  }
  final pageHost = Uri.base.host;
  if (pageHost.isEmpty) return configured;
  if (configuredUri.host == pageHost) return configured;
  const loopback = {'localhost', '127.0.0.1'};
  // Telefon QR: sayfa 192.168.x.x iken API hâlâ 127.0.0.1 olursa istekler telefona gider.
  if (loopback.contains(configuredUri.host) && !loopback.contains(pageHost)) {
    return configuredUri
        .replace(
          host: pageHost,
          port: configuredUri.hasPort ? configuredUri.port : null,
        )
        .toString();
  }
  if (loopback.contains(configuredUri.host) && loopback.contains(pageHost)) {
    return configuredUri
        .replace(
          host: pageHost,
          port: configuredUri.hasPort ? configuredUri.port : null,
        )
        .toString();
  }
  return configured;
}
