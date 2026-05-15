import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cloud JWT (yalnızca merkez süper yönetici).
class CloudAuthSession extends ChangeNotifier {
  CloudAuthSession();

  static const _kToken = 'qs_cloud_access_token';
  static const _kEmail = 'qs_cloud_email';
  static const _kDisplay = 'qs_cloud_display_name';

  String? accessToken;
  String? email;
  String? displayName;

  bool get isLoggedIn => accessToken != null && accessToken!.isNotEmpty;

  Future<void> restore() async {
    final p = await SharedPreferences.getInstance();
    accessToken = p.getString(_kToken);
    email = p.getString(_kEmail);
    displayName = p.getString(_kDisplay);
    notifyListeners();
  }

  Future<void> signInFromLoginJson(String responseBody) async {
    final map = jsonDecode(responseBody) as Map<String, dynamic>;
    final role = map['role'] as String?;
    if (role != 'SUPERADMIN') {
      throw Exception('Bu uygulama yalnızca süper yönetici (SUPERADMIN) içindir.');
    }
    accessToken = map['accessToken'] as String?;
    email = map['email'] as String?;
    displayName = map['displayName'] as String?;

    final p = await SharedPreferences.getInstance();
    if (accessToken != null) await p.setString(_kToken, accessToken!);
    if (email != null) await p.setString(_kEmail, email!);
    if (displayName != null) await p.setString(_kDisplay, displayName!);
    notifyListeners();
  }

  Future<void> signOut() async {
    accessToken = null;
    email = null;
    displayName = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_kToken);
    await p.remove(_kEmail);
    await p.remove(_kDisplay);
    notifyListeners();
  }
}
