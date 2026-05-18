import 'resolve_edge_base_url.dart';

/// Cloud misafir BFF tabanı; web'de loopback host hizalaması [resolveEdgeBaseUrl] ile aynı.
String resolveCloudBaseUrl(String configured) => resolveEdgeBaseUrl(configured);
