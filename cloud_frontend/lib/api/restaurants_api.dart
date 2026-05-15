import 'dart:convert';

import 'package:http/http.dart' as http;

class RestaurantSummary {
  RestaurantSummary({
    required this.id,
    required this.name,
    required this.subscriptionStatus,
  });

  final String id;
  final String name;
  final String subscriptionStatus;

  factory RestaurantSummary.fromJson(Map<String, dynamic> j) {
    return RestaurantSummary(
      id: j['id'] as String,
      name: j['name'] as String? ?? '',
      subscriptionStatus: j['subscriptionStatus'] as String? ?? 'DEMO',
    );
  }
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
