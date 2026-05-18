import 'dart:convert';

import 'package:http/http.dart' as http;

class RestaurantSummary {
  RestaurantSummary({
    required this.id,
    required this.name,
    required this.subscriptionStatus,
    this.edgeId,
    this.publicEdgeUrl,
    this.lastHelloAt,
    this.lastAcknowledgedUpdatedAt,
    required this.edgeStatus,
  });

  final String id;
  final String name;
  final String subscriptionStatus;
  final String? edgeId;
  final String? publicEdgeUrl;
  final String? lastHelloAt;
  final String? lastAcknowledgedUpdatedAt;
  final String edgeStatus;

  factory RestaurantSummary.fromJson(Map<String, dynamic> j) {
    return RestaurantSummary(
      id: j['id'].toString(),
      name: j['name'] as String? ?? '',
      subscriptionStatus: j['subscriptionStatus'] as String? ?? 'DEMO',
      edgeId: j['edgeId']?.toString(),
      publicEdgeUrl: j['publicEdgeUrl'] as String?,
      lastHelloAt: _dateToString(j['lastHelloAt']),
      lastAcknowledgedUpdatedAt: _dateToString(j['lastAcknowledgedUpdatedAt']),
      edgeStatus: j['edgeStatus'] as String? ?? 'NEVER_SEEN',
    );
  }

  String get edgeStatusLabel => switch (edgeStatus) {
        'ONLINE' => 'Çevrimiçi',
        'OFFLINE' => 'Çevrimdışı',
        _ => 'Kayıt yok',
      };
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

Future<List<RestaurantSummary>> fetchRestaurants({
  required String cloudBaseUrl,
  required String accessToken,
}) async {
  final root = cloudBaseUrl.endsWith('/') ? cloudBaseUrl.substring(0, cloudBaseUrl.length - 1) : cloudBaseUrl;
  final uri = Uri.parse('$root/api/v1/admin/restaurants');
  final res = await http.get(
    uri,
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Accept': 'application/json',
    },
  );
  if (res.statusCode != 200) {
    throw Exception('Liste (${res.statusCode}): ${res.body}');
  }
  final list = jsonDecode(res.body) as List<dynamic>;
  return list.map((e) => RestaurantSummary.fromJson(e as Map<String, dynamic>)).toList();
}

Future<void> patchRestaurantSubscription({
  required String cloudBaseUrl,
  required String accessToken,
  required String restaurantId,
  required String subscriptionStatus,
}) async {
  final root = cloudBaseUrl.endsWith('/') ? cloudBaseUrl.substring(0, cloudBaseUrl.length - 1) : cloudBaseUrl;
  final uri = Uri.parse('$root/api/v1/admin/restaurants/$restaurantId/subscription');
  final res = await http.patch(
    uri,
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({'subscriptionStatus': subscriptionStatus}),
  );
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw Exception('Güncelleme (${res.statusCode}): ${res.body}');
  }
}
