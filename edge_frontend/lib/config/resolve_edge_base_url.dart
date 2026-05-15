import 'package:flutter/foundation.dart' show kIsWeb;

/// Flutter Web'de sayfa `http://localhost:…` iken API tabanı `http://127.0.0.1:…`
/// olursa tarayıcıda özel ağ / loopback uyumsuzluğu nedeniyle HTTP ve WebSocket
/// bağlantıları başarısız olabiliyor. Bu durumda API host'unu sayfa ile aynı
/// loopback takma adına çekeriz (port yapılandırmadan kalır).
String resolveEdgeBaseUrl(String configured) {
  if (!kIsWeb) return configured;
  final raw = configured.trim();
  if (raw.isEmpty) return configured;
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
