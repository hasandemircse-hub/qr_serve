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

String _restaurantPath(
  String edgeBaseUrl,
  String restaurantId, [
  String suffix = '',
]) {
  return '${_root(edgeBaseUrl)}/api/v1/restaurants/$restaurantId$suffix';
}

Future<AdminMenuTreePayload> fetchAdminMenuTree({
  required String edgeBaseUrl,
  required String? accessToken,
  required String restaurantId,
}) async {
  final uri = Uri.parse(_restaurantPath(edgeBaseUrl, restaurantId, '/menus/tree'));
  final res = await http.get(uri, headers: _headers(accessToken));
  if (res.statusCode != 200) {
    throw Exception('Menü alınamadı (${res.statusCode}): ${res.body}');
  }
  return AdminMenuTreePayload.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

Future<AdminMenuDetailDto> createMenu({
  required String edgeBaseUrl,
  required String? accessToken,
  required String restaurantId,
  required String name,
  String? description,
  bool active = true,
}) async {
  final uri = Uri.parse(_restaurantPath(edgeBaseUrl, restaurantId, '/menus'));
  final res = await http.post(
    uri,
    headers: _headers(accessToken, jsonBody: true),
    body: jsonEncode({
      'name': name,
      if (description != null && description.isNotEmpty) 'description': description,
      'active': active,
    }),
  );
  if (res.statusCode != 200) {
    throw Exception('Menü oluşturulamadı (${res.statusCode}): ${res.body}');
  }
  return AdminMenuDetailDto.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

Future<AdminMenuDetailDto> updateMenu({
  required String edgeBaseUrl,
  required String? accessToken,
  required String restaurantId,
  required String menuId,
  required String name,
  String? description,
  required bool active,
}) async {
  final uri = Uri.parse(
    _restaurantPath(edgeBaseUrl, restaurantId, '/menus/$menuId'),
  );
  final res = await http.put(
    uri,
    headers: _headers(accessToken, jsonBody: true),
    body: jsonEncode({
      'name': name,
      if (description != null && description.isNotEmpty) 'description': description,
      'active': active,
    }),
  );
  if (res.statusCode != 200) {
    throw Exception('Menü güncellenemedi (${res.statusCode}): ${res.body}');
  }
  return AdminMenuDetailDto.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

Future<void> deleteMenu({
  required String edgeBaseUrl,
  required String? accessToken,
  required String restaurantId,
  required String menuId,
}) async {
  final uri = Uri.parse(
    _restaurantPath(edgeBaseUrl, restaurantId, '/menus/$menuId'),
  );
  final res = await http.delete(uri, headers: _headers(accessToken));
  if (res.statusCode != 204) {
    throw Exception('Menü silinemedi (${res.statusCode}): ${res.body}');
  }
}

Future<AdminProductDetailDto> createProduct({
  required String edgeBaseUrl,
  required String? accessToken,
  required String restaurantId,
  required String menuId,
  required String name,
  String? description,
  required double price,
  String? sku,
  double? taxRate,
}) async {
  final uri = Uri.parse(
    _restaurantPath(edgeBaseUrl, restaurantId, '/menus/$menuId/products'),
  );
  final body = <String, dynamic>{
    'name': name,
    'price': price,
    if (description != null && description.isNotEmpty) 'description': description,
    if (sku != null && sku.isNotEmpty) 'sku': sku,
    if (taxRate != null) 'taxRate': taxRate,
  };
  final res = await http.post(
    uri,
    headers: _headers(accessToken, jsonBody: true),
    body: jsonEncode(body),
  );
  if (res.statusCode != 200) {
    throw Exception('Ürün oluşturulamadı (${res.statusCode}): ${res.body}');
  }
  return AdminProductDetailDto.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

Future<AdminProductDetailDto> updateProduct({
  required String edgeBaseUrl,
  required String? accessToken,
  required String restaurantId,
  required String productId,
  required String name,
  String? description,
  required double price,
  String? sku,
  double? taxRate,
  String? menuId,
}) async {
  final uri = Uri.parse(
    _restaurantPath(edgeBaseUrl, restaurantId, '/products/$productId'),
  );
  final body = <String, dynamic>{
    'name': name,
    'price': price,
    if (description != null && description.isNotEmpty) 'description': description,
    if (sku != null && sku.isNotEmpty) 'sku': sku,
    if (taxRate != null) 'taxRate': taxRate,
    if (menuId != null && menuId.isNotEmpty) 'menuId': menuId,
  };
  final res = await http.put(
    uri,
    headers: _headers(accessToken, jsonBody: true),
    body: jsonEncode(body),
  );
  if (res.statusCode != 200) {
    throw Exception('Ürün güncellenemedi (${res.statusCode}): ${res.body}');
  }
  return AdminProductDetailDto.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

Future<void> reorderMenus({
  required String edgeBaseUrl,
  required String? accessToken,
  required String restaurantId,
  required List<String> orderedIds,
}) async {
  final uri = Uri.parse(_restaurantPath(edgeBaseUrl, restaurantId, '/menus/reorder'));
  final res = await http.put(
    uri,
    headers: _headers(accessToken, jsonBody: true),
    body: jsonEncode({'orderedIds': orderedIds}),
  );
  if (res.statusCode != 204) {
    throw Exception('Menü sırası kaydedilemedi (${res.statusCode}): ${res.body}');
  }
}

Future<void> reorderProducts({
  required String edgeBaseUrl,
  required String? accessToken,
  required String restaurantId,
  required String menuId,
  required List<String> orderedIds,
}) async {
  final uri = Uri.parse(
    _restaurantPath(edgeBaseUrl, restaurantId, '/menus/$menuId/products/reorder'),
  );
  final res = await http.put(
    uri,
    headers: _headers(accessToken, jsonBody: true),
    body: jsonEncode({'orderedIds': orderedIds}),
  );
  if (res.statusCode != 204) {
    throw Exception('Ürün sırası kaydedilemedi (${res.statusCode}): ${res.body}');
  }
}

Future<void> deleteProduct({
  required String edgeBaseUrl,
  required String? accessToken,
  required String restaurantId,
  required String productId,
}) async {
  final uri = Uri.parse(
    _restaurantPath(edgeBaseUrl, restaurantId, '/products/$productId'),
  );
  final res = await http.delete(uri, headers: _headers(accessToken));
  if (res.statusCode != 204) {
    throw Exception('Ürün silinemedi (${res.statusCode}): ${res.body}');
  }
}

class AdminMenuTreePayload {
  AdminMenuTreePayload({required this.menus});

  final List<AdminMenuDetailDto> menus;

  factory AdminMenuTreePayload.fromJson(Map<String, dynamic> j) {
    final raw = j['menus'] as List<dynamic>? ?? [];
    return AdminMenuTreePayload(
      menus: raw
          .map((e) => AdminMenuDetailDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class AdminMenuDetailDto {
  AdminMenuDetailDto({
    required this.id,
    required this.name,
    this.description,
    required this.active,
    required this.sortIndex,
    required this.products,
  });

  final String id;
  final String name;
  final String? description;
  final bool active;
  final int sortIndex;
  final List<AdminProductDetailDto> products;

  AdminMenuDetailDto copyWith({List<AdminProductDetailDto>? products}) {
    return AdminMenuDetailDto(
      id: id,
      name: name,
      description: description,
      active: active,
      sortIndex: sortIndex,
      products: products ?? this.products,
    );
  }

  factory AdminMenuDetailDto.fromJson(Map<String, dynamic> j) {
    final raw = j['products'] as List<dynamic>? ?? [];
    final products = raw
        .map((e) => AdminProductDetailDto.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
    return AdminMenuDetailDto(
      id: j['id'] as String,
      name: j['name'] as String,
      description: j['description'] as String?,
      active: j['active'] as bool? ?? true,
      sortIndex: (j['sortIndex'] as num?)?.toInt() ?? 0,
      products: products,
    );
  }
}

class AdminProductDetailDto {
  AdminProductDetailDto({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.sku,
    this.taxRate,
    required this.sortIndex,
  });

  final String id;
  final String name;
  final String? description;
  final double price;
  final String? sku;
  final double? taxRate;
  final int sortIndex;

  factory AdminProductDetailDto.fromJson(Map<String, dynamic> j) {
    return AdminProductDetailDto(
      id: j['id'] as String,
      name: j['name'] as String,
      description: j['description'] as String?,
      price: (j['price'] as num).toDouble(),
      sku: j['sku'] as String?,
      taxRate: j['taxRate'] == null ? null : (j['taxRate'] as num).toDouble(),
      sortIndex: (j['sortIndex'] as num?)?.toInt() ?? 0,
    );
  }
}
