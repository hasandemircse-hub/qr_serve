import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

String _root(String edgeBaseUrl) {
  final s = edgeBaseUrl.trim();
  return s.endsWith('/') ? s.substring(0, s.length - 1) : s;
}

Map<String, String> _authHeaders(String? accessToken) {
  final h = <String, String>{'Content-Type': 'application/json'};
  if (accessToken != null && accessToken.isNotEmpty) {
    h['Authorization'] = 'Bearer $accessToken';
  }
  return h;
}

Future<List<WaiterTableDto>> fetchWaiterTables({
  required String edgeBaseUrl,
  required String? accessToken,
}) async {
  final uri = Uri.parse('${_root(edgeBaseUrl)}/api/v1/waiter/tables');
  final res = await http.get(uri, headers: _authHeaders(accessToken));
  if (res.statusCode != 200) {
    throw Exception('Masalar alınamadı (${res.statusCode})');
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  final list = map['tables'] as List<dynamic>? ?? [];
  return list
      .map((e) => WaiterTableDto.fromJson(e as Map<String, dynamic>))
      .toList();
}

Future<ProductOptionWizardPayload> fetchProductOptionWizard({
  required String edgeBaseUrl,
  required String? accessToken,
  required String productId,
}) async {
  final uri = Uri.parse('${_root(edgeBaseUrl)}/api/v1/qr/products/$productId/option-wizard');
  final res = await http.get(uri, headers: _authHeaders(accessToken));
  if (res.statusCode != 200) {
    throw Exception('Seçenekler alınamadı (${res.statusCode})');
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ProductOptionWizardPayload.fromJson(map);
}

Future<WaiterMenuPayload> fetchWaiterMenu({
  required String edgeBaseUrl,
  required String? accessToken,
}) async {
  final uri = Uri.parse('${_root(edgeBaseUrl)}/api/v1/waiter/menu');
  final res = await http.get(uri, headers: _authHeaders(accessToken));
  if (res.statusCode != 200) {
    throw Exception('Menü alınamadı (${res.statusCode})');
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return WaiterMenuPayload.fromJson(map);
}

Future<List<WaiterReadyLineDto>> fetchWaiterReadyLines({
  required String edgeBaseUrl,
  required String? accessToken,
}) async {
  final uri = Uri.parse('${_root(edgeBaseUrl)}/api/v1/waiter/ready-lines');
  final res = await http.get(uri, headers: _authHeaders(accessToken));
  if (res.statusCode != 200) {
    throw Exception('Hazır siparişler alınamadı (${res.statusCode})');
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  final raw = map['lines'] as List<dynamic>? ?? [];
  return raw.map((e) => WaiterReadyLineDto.fromJson(e as Map<String, dynamic>)).toList();
}

String waiterPushWebSocketUrl(String edgeBaseUrl, String restaurantId) {
  final b = Uri.parse(edgeBaseUrl.trim());
  final wsScheme = b.scheme == 'https' ? 'wss' : 'ws';
  final sb = StringBuffer('$wsScheme://${b.host}');
  if (b.hasPort) {
    sb.write(':${b.port}');
  }
  sb.write('/ws/v1/waiter/push?restaurantId=${Uri.encodeQueryComponent(restaurantId)}');
  return sb.toString();
}

class WaiterPushConnection {
  WaiterPushConnection._(this._channel, this._subscription);

  final WebSocketChannel _channel;
  final StreamSubscription<dynamic> _subscription;

  static WaiterPushConnection connect({
    required String edgeBaseUrl,
    required String restaurantId,
    required void Function(String message) onMessage,
    void Function(Object error)? onError,
  }) {
    final url = waiterPushWebSocketUrl(edgeBaseUrl, restaurantId);
    final channel = WebSocketChannel.connect(Uri.parse(url));
    final sub = channel.stream.listen(
      (event) {
        if (event is String) {
          onMessage(event);
        }
      },
      onError: onError,
    );
    return WaiterPushConnection._(channel, sub);
  }

  void dispose() {
    _subscription.cancel();
    _channel.sink.close();
  }
}

bool _httpOk(int statusCode) => statusCode >= 200 && statusCode < 300;

String _transferErrorMessage(int statusCode, String body) {
  final lower = body.toLowerCase();
  if (statusCode == 400 && lower.contains('no open orders')) {
    return 'Bu masada devredilecek açık adisyon yok.';
  }
  if (statusCode == 400 && lower.contains('must differ')) {
    return 'Kaynak ve hedef masa aynı olamaz.';
  }
  if (body.trim().isEmpty) {
    return 'Masa devri başarısız ($statusCode).';
  }
  return 'Masa devri başarısız ($statusCode): $body';
}

Future<TransferTableOrdersResult> transferTableOrders({
  required String edgeBaseUrl,
  required String? accessToken,
  required String sourceTableId,
  required String targetTableId,
}) async {
  final uri = Uri.parse('${_root(edgeBaseUrl)}/api/v1/waiter/tables/transfer-orders');
  final body = jsonEncode({
    'sourceTableId': sourceTableId,
    'targetTableId': targetTableId,
  });
  final res = await http.post(uri, headers: _authHeaders(accessToken), body: body);
  if (!_httpOk(res.statusCode)) {
    throw Exception(_transferErrorMessage(res.statusCode, res.body));
  }
  if (res.body.trim().isEmpty) {
    return TransferTableOrdersResult(
      sourceTableLabel: '',
      targetTableLabel: '',
      transferredCount: 0,
    );
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  final rawIds = map['transferredOrderIds'] as List<dynamic>? ?? [];
  return TransferTableOrdersResult(
    sourceTableLabel: map['sourceTableLabel'] as String? ?? '',
    targetTableLabel: map['targetTableLabel'] as String? ?? '',
    transferredCount: (map['transferredCount'] as num?)?.toInt() ?? rawIds.length,
  );
}

Future<void> markWaiterLineDelivered({
  required String edgeBaseUrl,
  required String? accessToken,
  required String orderId,
  required String lineId,
}) async {
  final uri = Uri.parse(
    '${_root(edgeBaseUrl)}/api/v1/waiter/orders/$orderId/lines/$lineId/delivered',
  );
  final res = await http.post(uri, headers: _authHeaders(accessToken));
  if (!_httpOk(res.statusCode)) {
    throw Exception('Servis çıkışı kaydedilemedi (${res.statusCode}): ${res.body}');
  }
}

Future<WaiterPlaceOrderResult> placeWaiterOrder({
  required String edgeBaseUrl,
  required String? accessToken,
  required String tableId,
  required List<Map<String, dynamic>> lines,
}) async {
  final uri = Uri.parse('${_root(edgeBaseUrl)}/api/v1/waiter/orders');
  final body = jsonEncode({
    'tableId': tableId,
    'lines': lines,
  });
  final res = await http.post(uri, headers: _authHeaders(accessToken), body: body);
  if (res.statusCode != 200) {
    throw Exception('Sipariş gönderilemedi (${res.statusCode}): ${res.body}');
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return WaiterPlaceOrderResult(
    orderId: map['orderId'] as String? ?? '',
    orderNumber: map['orderNumber'] as String? ?? '',
    grandTotal: (map['grandTotal'] as num?)?.toDouble() ?? 0,
  );
}

class WaiterTableDto {
  WaiterTableDto({
    required this.id,
    required this.label,
    this.zone,
    this.seatCount,
  });

  final String id;
  final String label;
  final String? zone;
  final int? seatCount;

  factory WaiterTableDto.fromJson(Map<String, dynamic> j) {
    return WaiterTableDto(
      id: j['id'] as String,
      label: j['label'] as String? ?? '',
      zone: j['zone'] as String?,
      seatCount: (j['seatCount'] as num?)?.toInt(),
    );
  }
}

class WaiterMenuPayload {
  WaiterMenuPayload({required this.menus});

  final List<WaiterMenuMenuDto> menus;

  factory WaiterMenuPayload.fromJson(Map<String, dynamic> j) {
    final raw = j['menus'] as List<dynamic>? ?? [];
    return WaiterMenuPayload(
      menus: raw
          .map((e) => WaiterMenuMenuDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class WaiterMenuMenuDto {
  WaiterMenuMenuDto({
    required this.id,
    required this.name,
    required this.products,
  });

  final String id;
  final String name;
  final List<WaiterMenuProductDto> products;

  factory WaiterMenuMenuDto.fromJson(Map<String, dynamic> j) {
    final raw = j['products'] as List<dynamic>? ?? [];
    return WaiterMenuMenuDto(
      id: j['id'] as String,
      name: j['name'] as String? ?? '',
      products: raw
          .map((e) => WaiterMenuProductDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class WaiterMenuProductDto {
  WaiterMenuProductDto({
    required this.id,
    required this.name,
    this.description,
    required this.price,
  });

  final String id;
  final String name;
  final String? description;
  final double price;

  factory WaiterMenuProductDto.fromJson(Map<String, dynamic> j) {
    return WaiterMenuProductDto(
      id: j['id'] as String,
      name: j['name'] as String? ?? '',
      description: j['description'] as String?,
      price: (j['price'] as num?)?.toDouble() ?? 0,
    );
  }
}

class WaiterReadyLineDto {
  WaiterReadyLineDto({
    required this.orderId,
    required this.orderNumber,
    required this.tableLabel,
    required this.tableId,
    required this.lineId,
    required this.productName,
    required this.quantity,
    required this.kitchenLineStatus,
  });

  final String orderId;
  final String orderNumber;
  final String tableLabel;
  final String tableId;
  final String lineId;
  final String productName;
  final int quantity;
  final String kitchenLineStatus;

  factory WaiterReadyLineDto.fromJson(Map<String, dynamic> j) {
    return WaiterReadyLineDto(
      orderId: j['orderId'].toString(),
      orderNumber: j['orderNumber'] as String? ?? '',
      tableLabel: j['tableLabel'] as String? ?? '-',
      tableId: j['tableId']?.toString() ?? '',
      lineId: j['lineId'].toString(),
      productName: j['productName'] as String? ?? '',
      quantity: (j['quantity'] as num?)?.toInt() ?? 1,
      kitchenLineStatus: j['kitchenLineStatus'] as String? ?? 'READY',
    );
  }

  factory WaiterReadyLineDto.fromPush(Map<String, dynamic> j) {
    return WaiterReadyLineDto(
      orderId: j['orderId']?.toString() ?? '',
      orderNumber: j['orderNumber'] as String? ?? '',
      tableLabel: j['tableLabel'] as String? ?? '-',
      tableId: j['tableId']?.toString() ?? '',
      lineId: j['lineId']?.toString() ?? '',
      productName: j['productName'] as String? ?? '',
      quantity: (j['quantity'] as num?)?.toInt() ?? 1,
      kitchenLineStatus: j['kitchenLineStatus'] as String? ?? 'READY',
    );
  }
}

class TransferTableOrdersResult {
  TransferTableOrdersResult({
    required this.sourceTableLabel,
    required this.targetTableLabel,
    required this.transferredCount,
  });

  final String sourceTableLabel;
  final String targetTableLabel;
  final int transferredCount;
}

class WaiterPlaceOrderResult {
  WaiterPlaceOrderResult({
    required this.orderId,
    required this.orderNumber,
    required this.grandTotal,
  });

  final String orderId;
  final String orderNumber;
  final double grandTotal;
}

/// Ürün seçeneği yoksa (demo ürün gibi) backend `steps: []` bekler.
Map<String, dynamic> emptySelectedOptionsJson() => {
      'schemaVersion': 1,
      'steps': <dynamic>[],
    };

class ProductOptionWizardPayload {
  ProductOptionWizardPayload({
    required this.productId,
    required this.groups,
  });

  final String productId;
  final List<Map<String, dynamic>> groups;

  factory ProductOptionWizardPayload.fromJson(Map<String, dynamic> j) {
    final raw = j['groups'] as List<dynamic>? ?? [];
    return ProductOptionWizardPayload(
      productId: j['productId'] as String? ?? '',
      groups: raw.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
    );
  }
}
