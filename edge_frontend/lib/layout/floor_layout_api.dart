import 'dart:convert';

import 'package:http/http.dart' as http;

import 'floor_layout_models.dart';

Future<FloorLayoutSnapshot> fetchRestaurantLayout({
  required String edgeBaseUrl,
  required String? accessToken,
  required String restaurantId,
}) async {
  final base = edgeBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
  final uri = Uri.parse('$base/api/v1/restaurants/$restaurantId/layout');
  final headers = <String, String>{'Accept': 'application/json'};
  if (accessToken != null && accessToken.isNotEmpty) {
    headers['Authorization'] = 'Bearer $accessToken';
  }
  final res = await http.get(uri, headers: headers);
  if (res.statusCode != 200) {
    throw Exception('Salon planı alınamadı (${res.statusCode})');
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return FloorLayoutSnapshot.fromJson(map);
}
