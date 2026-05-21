import 'package:go_router/go_router.dart';

import 'auth/cloud_auth_session.dart';
import 'ui/cloud_login_screen.dart';
import 'ui/restaurant_detail_page.dart';
import 'ui/superadmin_dashboard_page.dart';

GoRouter createCloudRouter(CloudAuthSession auth) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: auth,
    redirect: (context, state) {
      final loggedIn = auth.isLoggedIn;
      final loc = state.uri.path;
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
    ],
  );
}
