import 'package:go_router/go_router.dart';

import 'auth/cloud_auth_session.dart';
import 'guest/guest_qr_menu_screen.dart';
import 'ui/cloud_login_screen.dart';
import 'ui/restaurant_detail_page.dart';
import 'ui/superadmin_dashboard_page.dart';

GoRouter createCloudRouter(CloudAuthSession auth) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: auth,
    redirect: (context, state) {
      final loc = state.uri.path;
      // Misafir QR sayfaları kimlik doğrulama istemez (token URL'in içinde).
      if (loc.startsWith('/guest/')) return null;
      final loggedIn = auth.isLoggedIn;
      if (!loggedIn && loc != '/login') return '/login';
      if (loggedIn && loc == '/login') return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => CloudLoginScreen(auth: auth),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => SuperadminDashboardPage(auth: auth),
      ),
      GoRoute(
        path: '/restaurants/:id',
        builder: (context, state) => RestaurantDetailPage(
          auth: auth,
          restaurantId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/guest/qr',
        builder: (context, state) {
          final qp = state.uri.queryParameters;
          return GuestQrMenuScreen(
            restaurantId: qp['r'] ?? '',
            tableId: qp['t'] ?? '',
            token: qp['k'] ?? '',
          );
        },
      ),
    ],
  );
}
