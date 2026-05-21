import 'dart:convert';

import 'package:http/http.dart' as http;

class AdminUser {
  AdminUser({
    required this.id,
    required this.restaurantId,
    required this.email,
    required this.role,
    this.displayName,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? restaurantId;
  final String email;
  final String? displayName;
  final String role;
  final String? createdAt;
  final String? updatedAt;

  factory AdminUser.fromJson(Map<String, dynamic> j) {
    return AdminUser(
      id: j['id'].toString(),
      restaurantId: j['restaurantId']?.toString(),
      email: j['email'] as String? ?? '',
      displayName: j['displayName'] as String?,
      role: j['role'] as String? ?? 'WAITER',
      createdAt: _toIsoString(j['createdAt']),
      updatedAt: _toIsoString(j['updatedAt']),
    );
  }

  String get roleLabel => switch (role) {
    'SUPERADMIN' => 'Süper Yönetici',
    'RESTAURANT_ADMIN' => 'Restoran Yöneticisi',
    'WAITER' => 'Garson',
    'KITCHEN' => 'Mutfak',
    'CASHIER' => 'Kasiyer',
    _ => role,
  };
}

String? _toIsoString(dynamic v) {
  if (v == null) return null;
  if (v is String) return v;
  if (v is List && v.length >= 5) {
    try {
      final y = (v[0] as num).toInt();
      final mo = (v[1] as num).toInt();
      final d = (v[2] as num).toInt();
      final h = (v[3] as num).toInt();
      final mi = (v[4] as num).toInt();
      return '$y-${mo.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')} '
          '${h.toString().padLeft(2, '0')}:${mi.toString().padLeft(2, '0')}';
    } catch (_) {
      return v.toString();
    }
  }
  return v.toString();
}

String _root(String base) =>
    base.endsWith('/') ? base.substring(0, base.length - 1) : base;

Future<List<AdminUser>> fetchUsers({
  required String cloudBaseUrl,
  required String accessToken,
  required String restaurantId,
}) async {
  final uri = Uri.parse(
    '${_root(cloudBaseUrl)}/api/v1/admin/restaurants/$restaurantId/users',
  );
  final res = await http.get(
    uri,
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Accept': 'application/json',
    },
  );
  if (res.statusCode != 200) {
    throw Exception('Kullanıcı listesi (${res.statusCode}): ${res.body}');
  }
  final list = jsonDecode(res.body) as List<dynamic>;
  return list
      .map((e) => AdminUser.fromJson(e as Map<String, dynamic>))
      .toList();
}

Future<AdminUser> createUser({
  required String cloudBaseUrl,
  required String accessToken,
  required String restaurantId,
  required String email,
  required String password,
  required String role,
  String? displayName,
}) async {
  final uri = Uri.parse(
    '${_root(cloudBaseUrl)}/api/v1/admin/restaurants/$restaurantId/users',
  );
  final res = await http.post(
    uri,
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    body: jsonEncode({
      'email': email,
      'password': password,
      'role': role,
      'displayName': displayName,
    }),
  );
  if (res.statusCode != 200 && res.statusCode != 201) {
    throw Exception('Kullanıcı oluşturma (${res.statusCode}): ${res.body}');
  }
  return AdminUser.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
}

Future<AdminUser> updateUser({
  required String cloudBaseUrl,
  required String accessToken,
  required String userId,
  String? displayName,
  String? role,
  String? password,
}) async {
  final uri = Uri.parse('${_root(cloudBaseUrl)}/api/v1/admin/users/$userId');
  final body = <String, dynamic>{};
  if (displayName != null) body['displayName'] = displayName;
  if (role != null) body['role'] = role;
  if (password != null && password.isNotEmpty) body['password'] = password;
  final res = await http.patch(
    uri,
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    body: jsonEncode(body),
  );
  if (res.statusCode != 200) {
    throw Exception('Kullanıcı güncelleme (${res.statusCode}): ${res.body}');
  }
  return AdminUser.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
}

Future<void> deleteUser({
  required String cloudBaseUrl,
  required String accessToken,
  required String userId,
}) async {
  final uri = Uri.parse('${_root(cloudBaseUrl)}/api/v1/admin/users/$userId');
  final res = await http.delete(
    uri,
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Accept': 'application/json',
    },
  );
  if (res.statusCode != 204 &&
      (res.statusCode < 200 || res.statusCode >= 300)) {
    throw Exception('Kullanıcı silme (${res.statusCode}): ${res.body}');
  }
}
