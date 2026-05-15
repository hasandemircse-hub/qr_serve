import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_user_role.dart';

/// JWT ve rol; Edge personel uygulaması (Cloud süperadmin ayrı `cloud_frontend` projesinde).
class AuthSession extends ChangeNotifier {
  AuthSession();

  static const _kToken = 'qs_access_token';
  static const _kRole = 'qs_role';
  static const _kRestaurant = 'qs_restaurant_id';
  static const _kEmail = 'qs_email';
  static const _kDisplay = 'qs_display_name';

  String? accessToken;
  AppUserRole? role;
  String? restaurantId;
  String? email;
  String? displayName;

  bool get isLoggedIn => accessToken != null && accessToken!.isNotEmpty && role != null;

  Future<void> restore() async {
    final p = await SharedPreferences.getInstance();
    accessToken = p.getString(_kToken);
    role = AppUserRole.fromApi(p.getString(_kRole));
    restaurantId = p.getString(_kRestaurant);
    email = p.getString(_kEmail);
    displayName = p.getString(_kDisplay);
    if (accessToken != null && accessToken!.isNotEmpty && role == null) {
      await signOut();
      return;
    }
    notifyListeners();
  }

  Future<void> signInFromLoginJson(String responseBody) async {
    final map = jsonDecode(responseBody) as Map<String, dynamic>;
    final roleStr = map['role'] as String?;
    final parsed = AppUserRole.fromApi(roleStr);
    if (parsed == null) {
      throw Exception(
        'Bu hesap Edge personel rolleriyle uyumlu değil. Merkez yönetimi için QuickServe Cloud uygulamasını (cloud_frontend) kullanın.',
      );
    }
    accessToken = map['accessToken'] as String?;
    role = parsed;
    restaurantId = map['restaurantId'] as String?;
    email = map['email'] as String?;
    displayName = map['displayName'] as String?;

    final p = await SharedPreferences.getInstance();
    if (accessToken != null) await p.setString(_kToken, accessToken!);
    if (roleStr != null) await p.setString(_kRole, roleStr);
    if (restaurantId != null) await p.setString(_kRestaurant, restaurantId!);
    if (email != null) await p.setString(_kEmail, email!);
    if (displayName != null) await p.setString(_kDisplay, displayName!);
    notifyListeners();
  }

  Future<void> signOut() async {
    accessToken = null;
    role = null;
    restaurantId = null;
    email = null;
    displayName = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_kToken);
    await p.remove(_kRole);
    await p.remove(_kRestaurant);
    await p.remove(_kEmail);
    await p.remove(_kDisplay);
    notifyListeners();
  }
}
