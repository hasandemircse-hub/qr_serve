import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:go_router/go_router.dart';

import 'auth/auth_session.dart';
import 'config/resolve_cloud_base_url.dart';
import 'config/resolve_edge_base_url.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Web'de varsayılan path stratejisi yalnızca pathname okur; `#/guest-lab` gibi
  // hash içi rotalar eşleşmez ve boş sayfa oluşur. Misafir lab linkleri hash ile uyumlu olsun.
  if (kIsWeb) {
    setUrlStrategy(const HashUrlStrategy());
  }
  final auth = AuthSession();
  await auth.restore();
  runApp(QuickServeEdgeApp(auth: auth));
}

class QuickServeEdgeApp extends StatefulWidget {
  const QuickServeEdgeApp({super.key, required this.auth});

  final AuthSession auth;

  /// Seed ile uyumlu demo kimlikleri (migration-local).
  static const demoRestaurantId = '11111111-1111-1111-1111-111111111111';
  static const demoProductId = '44444444-4444-4444-4444-444444444444';

  /// Edge HTTP API tabanı. Web build'de [resolveEdgeBaseUrl] ile sayfa host'una
  /// hizalanır. Üretimde build sırasında: `--dart-define=EDGE_BASE_URL=` (boş)
  /// veya `--dart-define=EDGE_BASE_URL=https://edge.example.com`.
  static const edgeBaseUrlConfigured = String.fromEnvironment(
    'EDGE_BASE_URL',
    defaultValue: 'http://127.0.0.1:8081',
  );

  /// Cloud misafir BFF (internet QR REST). WebSocket hâlâ Edge üzerinden.
  static const cloudBaseUrlConfigured = String.fromEnvironment(
    'CLOUD_BASE_URL',
    defaultValue: 'http://127.0.0.1:8080',
  );

  @override
  State<QuickServeEdgeApp> createState() => _QuickServeEdgeAppState();
}

class _QuickServeEdgeAppState extends State<QuickServeEdgeApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final edgeBaseUrl =
        resolveEdgeBaseUrl(QuickServeEdgeApp.edgeBaseUrlConfigured);
    final cloudBaseUrl =
        resolveCloudBaseUrl(QuickServeEdgeApp.cloudBaseUrlConfigured);
    _router = createAppRouter(
      auth: widget.auth,
      edgeBaseUrl: edgeBaseUrl,
      cloudBaseUrl: cloudBaseUrl,
      demoRestaurantId: QuickServeEdgeApp.demoRestaurantId,
      demoProductId: QuickServeEdgeApp.demoProductId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'QuickServe Edge',
      theme: AppTheme.light(),
      routerConfig: _router,
    );
  }
}
