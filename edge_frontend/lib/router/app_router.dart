import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/app_user_role.dart';
import '../auth/auth_session.dart';
import '../guest/guest_lab_screen.dart';
import '../guest/guest_qr_menu_screen.dart';
import '../landing/cashier_landing.dart';
import '../landing/kitchen_landing.dart';
import '../landing/restaurant_admin_landing.dart';
import '../landing/waiter_landing.dart';
import '../screens/login_screen.dart';
import '../setup/setup_wizard_screen.dart';

GoRouter createAppRouter({
  required AuthSession auth,
  required String edgeBaseUrl,
  required String demoRestaurantId,
  required String demoProductId,
}) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: auth,
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Rota')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SelectableText(
            'Bu adres uygulama rotasıyla eşleşmedi.\n\n'
            'Misafir lab (hash): /#/guest-lab?restaurantId=<uuid>\n'
            'Misafir lab (path): /guest-lab?restaurantId=<uuid>\n\n'
            'Tarayıcıdaki tam yol: ${state.uri}',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
    redirect: (BuildContext context, GoRouterState state) {
      final loggedIn = auth.isLoggedIn;
      final loc = state.uri.path;
      final isGuestTestRoute = loc == '/guest-lab' || loc.startsWith('/guest/');
      if (!loggedIn && loc != '/login' && !isGuestTestRoute) {
        return '/login';
      }
      if (loggedIn && loc == '/login') {
        return auth.role?.landingPath ?? '/login';
      }
      if (loggedIn && auth.role != null) {
        final home = auth.role!.landingPath;
        if (loc == '/' || loc.isEmpty) return home;
        if (isGuestTestRoute) return null;
        final allowed = _pathsForRole(auth.role!);
        if (!allowed.contains(loc)) {
          return home;
        }
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/guest-lab',
        builder: (context, state) {
          final rid = state.uri.queryParameters['restaurantId'] ??
              state.uri.queryParameters['r'] ??
              demoRestaurantId;
          return GuestLabScreen(
            edgeBaseUrl: edgeBaseUrl,
            restaurantId: rid,
          );
        },
      ),
      GoRoute(
        path: '/guest/qr',
        builder: (context, state) {
          final r = state.uri.queryParameters['r'] ?? '';
          final t = state.uri.queryParameters['t'] ?? '';
          final k = state.uri.queryParameters['k'] ?? '';
          return GuestQrMenuScreen(
            edgeBaseUrl: edgeBaseUrl,
            restaurantId: r,
            tableId: t,
            token: k,
          );
        },
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(
          auth: auth,
          edgeBaseUrl: edgeBaseUrl,
        ),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => RestaurantAdminLanding(
          auth: auth,
          edgeBaseUrl: edgeBaseUrl,
          demoRestaurantId: demoRestaurantId,
          demoProductId: demoProductId,
        ),
      ),
      GoRoute(
        path: '/admin/setup',
        builder: (context, state) => SetupWizardScreen(edgeBaseUrl: edgeBaseUrl),
      ),
      GoRoute(
        path: '/waiter',
        builder: (context, state) => WaiterLanding(
          auth: auth,
          edgeBaseUrl: edgeBaseUrl,
        ),
      ),
      GoRoute(
        path: '/kitchen',
        builder: (context, state) => KitchenLanding(
          auth: auth,
          edgeBaseUrl: edgeBaseUrl,
        ),
      ),
      GoRoute(
        path: '/cashier',
        builder: (context, state) => CashierLanding(
          auth: auth,
          edgeBaseUrl: edgeBaseUrl,
        ),
      ),
      GoRoute(
        path: '/',
        redirect: (context, state) {
          final q = state.uri.query;
          final suffix = q.isEmpty ? '' : '?$q';
          return '/login$suffix';
        },
      ),
    ],
  );
}

List<String> _pathsForRole(AppUserRole r) {
  switch (r) {
    case AppUserRole.restaurantAdmin:
      return ['/admin', '/admin/setup'];
    case AppUserRole.waiter:
      return ['/waiter'];
    case AppUserRole.kitchen:
      return ['/kitchen'];
    case AppUserRole.cashier:
      return ['/cashier'];
  }
}
