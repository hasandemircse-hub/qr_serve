/// Backend `UserRole` ile aynı isimler (Edge personel; SUPERADMIN → `cloud_frontend`).
enum AppUserRole {
  restaurantAdmin,
  waiter,
  kitchen,
  cashier;

  static AppUserRole? fromApi(String? raw) {
    switch (raw) {
      case 'RESTAURANT_ADMIN':
        return AppUserRole.restaurantAdmin;
      case 'WAITER':
        return AppUserRole.waiter;
      case 'KITCHEN':
        return AppUserRole.kitchen;
      case 'CASHIER':
        return AppUserRole.cashier;
      default:
        return null;
    }
  }

  String get landingPath {
    switch (this) {
      case AppUserRole.restaurantAdmin:
        return '/admin';
      case AppUserRole.waiter:
        return '/waiter';
      case AppUserRole.kitchen:
        return '/kitchen';
      case AppUserRole.cashier:
        return '/cashier';
    }
  }
}
