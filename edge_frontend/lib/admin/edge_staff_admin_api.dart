import 'dart:convert';

import 'package:http/http.dart' as http;

String _root(String edgeBaseUrl) {
  final s = edgeBaseUrl.trim();
  return s.endsWith('/') ? s.substring(0, s.length - 1) : s;
}

Map<String, String> _headers(String? accessToken, {bool jsonBody = false}) {
  final h = <String, String>{'Accept': 'application/json'};
  if (jsonBody) h['Content-Type'] = 'application/json';
  if (accessToken != null && accessToken.isNotEmpty) {
    h['Authorization'] = 'Bearer $accessToken';
  }
  return h;
}

String _staffPath(
  String edgeBaseUrl,
  String restaurantId, [
  String suffix = '',
]) {
  return '${_root(edgeBaseUrl)}/api/v1/restaurants/$restaurantId/staff$suffix';
}

Future<StaffListPayload> fetchStaffMembers({
  required String edgeBaseUrl,
  required String? accessToken,
  required String restaurantId,
}) async {
  final uri = Uri.parse(_staffPath(edgeBaseUrl, restaurantId));
  final res = await http.get(uri, headers: _headers(accessToken));
  if (res.statusCode != 200) {
    throw Exception('Personel alınamadı (${res.statusCode}): ${res.body}');
  }
  return StaffListPayload.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

Future<StaffMemberDto> createStaffMember({
  required String edgeBaseUrl,
  required String? accessToken,
  required String restaurantId,
  required String email,
  required String displayName,
  required String role,
  required String password,
}) async {
  final uri = Uri.parse(_staffPath(edgeBaseUrl, restaurantId));
  final res = await http.post(
    uri,
    headers: _headers(accessToken, jsonBody: true),
    body: jsonEncode({
      'email': email,
      'displayName': displayName,
      'role': role,
      'password': password,
    }),
  );
  if (res.statusCode != 200) {
    throw Exception('Personel eklenemedi (${res.statusCode}): ${res.body}');
  }
  return StaffMemberDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
}

Future<StaffMemberDto> updateStaffMember({
  required String edgeBaseUrl,
  required String? accessToken,
  required String restaurantId,
  required String staffId,
  required String email,
  required String displayName,
  required String role,
}) async {
  final uri = Uri.parse(_staffPath(edgeBaseUrl, restaurantId, '/$staffId'));
  final res = await http.patch(
    uri,
    headers: _headers(accessToken, jsonBody: true),
    body: jsonEncode({
      'email': email,
      'displayName': displayName,
      'role': role,
    }),
  );
  if (res.statusCode != 200) {
    throw Exception('Personel güncellenemedi (${res.statusCode}): ${res.body}');
  }
  return StaffMemberDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
}

Future<void> resetStaffPassword({
  required String edgeBaseUrl,
  required String? accessToken,
  required String restaurantId,
  required String staffId,
  required String password,
}) async {
  final uri = Uri.parse(
    _staffPath(edgeBaseUrl, restaurantId, '/$staffId/reset-password'),
  );
  final res = await http.post(
    uri,
    headers: _headers(accessToken, jsonBody: true),
    body: jsonEncode({'password': password}),
  );
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw Exception('Şifre güncellenemedi (${res.statusCode}): ${res.body}');
  }
}

Future<void> deleteStaffMember({
  required String edgeBaseUrl,
  required String? accessToken,
  required String restaurantId,
  required String staffId,
}) async {
  final uri = Uri.parse(_staffPath(edgeBaseUrl, restaurantId, '/$staffId'));
  final res = await http.delete(uri, headers: _headers(accessToken));
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw Exception('Personel silinemedi (${res.statusCode}): ${res.body}');
  }
}

class StaffListPayload {
  StaffListPayload({required this.staff});

  final List<StaffMemberDto> staff;

  factory StaffListPayload.fromJson(Map<String, dynamic> j) {
    final raw = j['staff'] as List<dynamic>? ?? [];
    return StaffListPayload(
      staff: raw
          .map((e) => StaffMemberDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class StaffMemberDto {
  StaffMemberDto({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String email;
  final String displayName;
  final String role;
  final String? createdAt;
  final String? updatedAt;

  factory StaffMemberDto.fromJson(Map<String, dynamic> j) {
    return StaffMemberDto(
      id: j['id']?.toString() ?? '',
      email: j['email'] as String? ?? '',
      displayName: j['displayName'] as String? ?? '',
      role: j['role'] as String? ?? '',
      createdAt: _dateToString(j['createdAt']),
      updatedAt: _dateToString(j['updatedAt']),
    );
  }

  String get label => displayName.isNotEmpty ? displayName : email;
}

String? _dateToString(dynamic v) {
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
