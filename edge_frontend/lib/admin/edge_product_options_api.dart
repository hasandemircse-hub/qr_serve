import 'dart:convert';

import 'package:http/http.dart' as http;

String _root(String edgeBaseUrl) {
  final s = edgeBaseUrl.trim();
  return s.endsWith('/') ? s.substring(0, s.length - 1) : s;
}

Map<String, String> _headers(String? accessToken) {
  final h = <String, String>{
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  if (accessToken != null && accessToken.isNotEmpty) {
    h['Authorization'] = 'Bearer $accessToken';
  }
  return h;
}

String _restaurantPath(String edgeBaseUrl, String restaurantId, String suffix) {
  return '${_root(edgeBaseUrl)}/api/v1/restaurants/$restaurantId$suffix';
}

Future<AdminMenuProductsPayload> fetchAdminMenuProducts({
  required String edgeBaseUrl,
  required String? accessToken,
  required String restaurantId,
}) async {
  final uri = Uri.parse(_restaurantPath(edgeBaseUrl, restaurantId, '/menu-products'));
  final res = await http.get(uri, headers: _headers(accessToken));
  if (res.statusCode != 200) {
    throw Exception('Menü ürünleri alınamadı (${res.statusCode}): ${res.body}');
  }
  return AdminMenuProductsPayload.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
}

Future<AdminProductOptionGroupsPayload> fetchAdminOptionGroups({
  required String edgeBaseUrl,
  required String? accessToken,
  required String restaurantId,
  required String productId,
}) async {
  final uri = Uri.parse(
    _restaurantPath(edgeBaseUrl, restaurantId, '/products/$productId/option-groups'),
  );
  final res = await http.get(uri, headers: _headers(accessToken));
  if (res.statusCode != 200) {
    throw Exception('Seçenek grupları alınamadı (${res.statusCode}): ${res.body}');
  }
  return AdminProductOptionGroupsPayload.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
}

Future<void> createOptionGroup({
  required String edgeBaseUrl,
  required String? accessToken,
  required String restaurantId,
  required String productId,
  required String name,
  required String selectionType,
  int? sortIndex,
}) async {
  final uri = Uri.parse(
    _restaurantPath(edgeBaseUrl, restaurantId, '/products/$productId/option-groups'),
  );
  final body = <String, dynamic>{
    'name': name,
    'selectionType': selectionType,
    if (sortIndex != null) 'sortIndex': sortIndex,
  };
  final res = await http.post(uri, headers: _headers(accessToken), body: jsonEncode(body));
  if (res.statusCode != 200) {
    throw Exception('Grup eklenemedi (${res.statusCode}): ${res.body}');
  }
}

Future<void> updateOptionGroup({
  required String edgeBaseUrl,
  required String? accessToken,
  required String restaurantId,
  required String groupId,
  required String name,
  required String selectionType,
  int? sortIndex,
}) async {
  final uri = Uri.parse(_restaurantPath(edgeBaseUrl, restaurantId, '/option-groups/$groupId'));
  final body = <String, dynamic>{
    'name': name,
    'selectionType': selectionType,
    if (sortIndex != null) 'sortIndex': sortIndex,
  };
  final res = await http.put(uri, headers: _headers(accessToken), body: jsonEncode(body));
  if (res.statusCode != 200) {
    throw Exception('Grup güncellenemedi (${res.statusCode}): ${res.body}');
  }
}

Future<void> deleteOptionGroup({
  required String edgeBaseUrl,
  required String? accessToken,
  required String restaurantId,
  required String groupId,
}) async {
  final uri = Uri.parse(_restaurantPath(edgeBaseUrl, restaurantId, '/option-groups/$groupId'));
  final res = await http.delete(uri, headers: _headers(accessToken));
  if (res.statusCode != 200 && res.statusCode != 204) {
    throw Exception('Grup silinemedi (${res.statusCode}): ${res.body}');
  }
}

Future<void> createProductOption({
  required String edgeBaseUrl,
  required String? accessToken,
  required String restaurantId,
  required String groupId,
  required String label,
  required double priceAdjustment,
  int? sortIndex,
}) async {
  final uri = Uri.parse(_restaurantPath(edgeBaseUrl, restaurantId, '/option-groups/$groupId/options'));
  final body = <String, dynamic>{
    'label': label,
    'priceAdjustment': priceAdjustment,
    if (sortIndex != null) 'sortIndex': sortIndex,
  };
  final res = await http.post(uri, headers: _headers(accessToken), body: jsonEncode(body));
  if (res.statusCode != 200) {
    throw Exception('Seçenek eklenemedi (${res.statusCode}): ${res.body}');
  }
}

Future<void> updateProductOption({
  required String edgeBaseUrl,
  required String? accessToken,
  required String restaurantId,
  required String optionId,
  required String label,
  required double priceAdjustment,
  int? sortIndex,
}) async {
  final uri = Uri.parse(_restaurantPath(edgeBaseUrl, restaurantId, '/options/$optionId'));
  final body = <String, dynamic>{
    'label': label,
    'priceAdjustment': priceAdjustment,
    if (sortIndex != null) 'sortIndex': sortIndex,
  };
  final res = await http.put(uri, headers: _headers(accessToken), body: jsonEncode(body));
  if (res.statusCode != 200) {
    throw Exception('Seçenek güncellenemedi (${res.statusCode}): ${res.body}');
  }
}

Future<void> deleteProductOption({
  required String edgeBaseUrl,
  required String? accessToken,
  required String restaurantId,
  required String optionId,
}) async {
  final uri = Uri.parse(_restaurantPath(edgeBaseUrl, restaurantId, '/options/$optionId'));
  final res = await http.delete(uri, headers: _headers(accessToken));
  if (res.statusCode != 200 && res.statusCode != 204) {
    throw Exception('Seçenek silinemedi (${res.statusCode}): ${res.body}');
  }
}

class AdminMenuProductsPayload {
  AdminMenuProductsPayload({required this.menus});

  final List<AdminMenuDto> menus;

  factory AdminMenuProductsPayload.fromJson(Map<String, dynamic> j) {
    final raw = j['menus'] as List<dynamic>? ?? [];
    return AdminMenuProductsPayload(
      menus: raw.map((e) => AdminMenuDto.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  List<AdminProductDto> get allProducts {
    final out = <AdminProductDto>[];
    for (final m in menus) {
      for (final p in m.products) {
        out.add(p);
      }
    }
    return out;
  }
}

class AdminMenuDto {
  AdminMenuDto({required this.id, required this.name, required this.products});

  final String id;
  final String name;
  final List<AdminProductDto> products;

  factory AdminMenuDto.fromJson(Map<String, dynamic> j) {
    final raw = j['products'] as List<dynamic>? ?? [];
    return AdminMenuDto(
      id: j['id'] as String,
      name: j['name'] as String? ?? '',
      products: raw.map((e) => AdminProductDto.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class AdminProductDto {
  AdminProductDto({
    required this.id,
    required this.name,
    required this.price,
    required this.optionGroupCount,
  });

  final String id;
  final String name;
  final double price;
  final int optionGroupCount;

  factory AdminProductDto.fromJson(Map<String, dynamic> j) {
    return AdminProductDto(
      id: j['id'] as String,
      name: j['name'] as String? ?? '',
      price: (j['price'] as num?)?.toDouble() ?? 0,
      optionGroupCount: (j['optionGroupCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminProductOptionGroupsPayload {
  AdminProductOptionGroupsPayload({
    required this.productId,
    required this.productName,
    required this.groups,
  });

  final String productId;
  final String productName;
  final List<AdminOptionGroupDto> groups;

  factory AdminProductOptionGroupsPayload.fromJson(Map<String, dynamic> j) {
    final raw = j['groups'] as List<dynamic>? ?? [];
    return AdminProductOptionGroupsPayload(
      productId: j['productId'] as String? ?? '',
      productName: j['productName'] as String? ?? '',
      groups: raw.map((e) => AdminOptionGroupDto.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class AdminOptionGroupDto {
  AdminOptionGroupDto({
    required this.id,
    required this.name,
    required this.selectionType,
    required this.sortIndex,
    required this.options,
  });

  final String id;
  final String name;
  final String selectionType;
  final int sortIndex;
  final List<AdminOptionItemDto> options;

  factory AdminOptionGroupDto.fromJson(Map<String, dynamic> j) {
    final raw = j['options'] as List<dynamic>? ?? [];
    return AdminOptionGroupDto(
      id: j['id'] as String,
      name: j['name'] as String? ?? '',
      selectionType: j['selectionType'] as String? ?? 'SINGLE',
      sortIndex: (j['sortIndex'] as num?)?.toInt() ?? 0,
      options: raw.map((e) => AdminOptionItemDto.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class AdminOptionItemDto {
  AdminOptionItemDto({
    required this.id,
    required this.label,
    required this.priceAdjustment,
    required this.sortIndex,
  });

  final String id;
  final String label;
  final double priceAdjustment;
  final int sortIndex;

  factory AdminOptionItemDto.fromJson(Map<String, dynamic> j) {
    return AdminOptionItemDto(
      id: j['id'] as String,
      label: j['label'] as String? ?? '',
      priceAdjustment: (j['priceAdjustment'] as num?)?.toDouble() ?? 0,
      sortIndex: (j['sortIndex'] as num?)?.toInt() ?? 0,
    );
  }
}
