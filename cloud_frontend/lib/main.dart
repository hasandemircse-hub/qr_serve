import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_router.dart';
import 'auth/cloud_auth_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final auth = CloudAuthSession();
  await auth.restore();
  runApp(QuickServeCloudApp(auth: auth));
}

class QuickServeCloudApp extends StatefulWidget {
  const QuickServeCloudApp({super.key, required this.auth});

  final CloudAuthSession auth;

  @override
  State<QuickServeCloudApp> createState() => _QuickServeCloudAppState();
}

class _QuickServeCloudAppState extends State<QuickServeCloudApp> {
  late final GoRouter _router = createCloudRouter(widget.auth);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'QuickServe Cloud',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}
