import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

String _root(String edgeBaseUrl) {
  final s = edgeBaseUrl.trim();
  return s.endsWith('/') ? s.substring(0, s.length - 1) : s;
}

Map<String, String> _authHeaders(String? accessToken) {
  final h = <String, String>{
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };
  if (accessToken != null && accessToken.isNotEmpty) {
    h['Authorization'] = 'Bearer $accessToken';
  }
  return h;
}

String cashierPushWebSocketUrl(String edgeBaseUrl, String restaurantId) {
  final b = Uri.parse(edgeBaseUrl.trim());
  final wsScheme = b.scheme == 'https' ? 'wss' : 'ws';
  final sb = StringBuffer('$wsScheme://${b.host}');
  if (b.hasPort) {
    sb.write(':${b.port}');
  }
  sb.write(
    '/ws/v1/cashier/push?restaurantId=${Uri.encodeQueryComponent(restaurantId)}',
  );
  return sb.toString();
}

class CashierPushConnection {
  CashierPushConnection._(this._channel, this._subscription);

  final WebSocketChannel _channel;
  final StreamSubscription<dynamic> _subscription;

  static CashierPushConnection connect({
    required String edgeBaseUrl,
    required String restaurantId,
    required void Function(String message) onMessage,
    void Function(Object error)? onError,
  }) {
    final url = cashierPushWebSocketUrl(edgeBaseUrl, restaurantId);
    final channel = WebSocketChannel.connect(Uri.parse(url));
    final sub = channel.stream.listen((event) {
      if (event is String) {
        onMessage(event);
      }
    }, onError: onError);
    return CashierPushConnection._(channel, sub);
  }

  void dispose() {
    _subscription.cancel();
    _channel.sink.close();
  }
}

Future<List<CashierOpenOrderDto>> fetchCashierOpenOrders({
  required String edgeBaseUrl,
  required String? accessToken,
}) async {
  final uri = Uri.parse('${_root(edgeBaseUrl)}/api/v1/cashier/open-orders');
  final res = await http.get(uri, headers: _authHeaders(accessToken));
  if (res.statusCode != 200) {
    throw Exception('Açık adisyonlar alınamadı (${res.statusCode})');
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  final raw = map['orders'] as List<dynamic>? ?? [];
  return raw
      .map((e) => CashierOpenOrderDto.fromJson(e as Map<String, dynamic>))
      .toList();
}

Future<BillingSummaryDto> fetchBillingSummary({
  required String edgeBaseUrl,
  required String? accessToken,
  required String restaurantId,
  required String orderId,
}) async {
  final uri = Uri.parse(
    '${_root(edgeBaseUrl)}/api/v1/restaurants/$restaurantId/orders/$orderId/billing',
  );
  final res = await http.get(uri, headers: _authHeaders(accessToken));
  if (res.statusCode != 200) {
    throw Exception('Adisyon özeti alınamadı (${res.statusCode})');
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return BillingSummaryDto.fromJson(map);
}

Future<BillingPaymentResultDto> postBillingPayment({
  required String edgeBaseUrl,
  required String? accessToken,
  required String restaurantId,
  required String orderId,
  required Map<String, dynamic> body,
}) async {
  final uri = Uri.parse(
    '${_root(edgeBaseUrl)}/api/v1/restaurants/$restaurantId/orders/$orderId/billing/payments',
  );
  final res = await http.post(
    uri,
    headers: _authHeaders(accessToken),
    body: jsonEncode(body),
  );
  if (res.statusCode != 200 && res.statusCode != 201) {
    throw Exception('Ödeme başarısız (${res.statusCode}): ${res.body}');
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return BillingPaymentResultDto.fromJson(map);
}

Map<String, dynamic> buildRemainderPaymentBody({
  required String method,
  double tipAmount = 0,
}) {
  return {
    'mode': 'REMAINDER',
    'fixedAmount': null,
    'linePayments': null,
    'method': method,
    'tipAmount': tipAmount,
    'externalReference': null,
    'printToPrinterId': null,
  };
}

Map<String, dynamic> buildFixedAmountPaymentBody({
  required String method,
  required double fixedAmount,
  double tipAmount = 0,
}) {
  return {
    'mode': 'FIXED_AMOUNT',
    'fixedAmount': fixedAmount,
    'linePayments': null,
    'method': method,
    'tipAmount': tipAmount,
    'externalReference': null,
    'printToPrinterId': null,
  };
}

Future<CloseTableSessionResultDto> closeTableSession({
  required String edgeBaseUrl,
  required String? accessToken,
  required String tableId,
  Map<String, dynamic>? body,
}) async {
  final uri = Uri.parse(
    '${_root(edgeBaseUrl)}/api/v1/cashier/tables/$tableId/close-session',
  );
  final headers = _authHeaders(accessToken);
  if (body != null) headers['Content-Type'] = 'application/json';
  final res = await http.post(
    uri,
    headers: headers,
    body: body == null ? null : jsonEncode(body),
  );
  if (res.statusCode != 200) {
    throw Exception(
      _formatApiError('Masa kapatılamadı', res.statusCode, res.body),
    );
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return CloseTableSessionResultDto.fromJson(map);
}

class CloseTableSessionResultDto {
  CloseTableSessionResultDto({
    required this.tableId,
    required this.tableLabel,
    required this.closedOrderIds,
    required this.tableReleased,
  });

  final String tableId;
  final String tableLabel;
  final List<String> closedOrderIds;
  final bool tableReleased;

  factory CloseTableSessionResultDto.fromJson(Map<String, dynamic> j) {
    final raw = j['closedOrderIds'] as List<dynamic>? ?? [];
    return CloseTableSessionResultDto(
      tableId: j['tableId']?.toString() ?? '',
      tableLabel: j['tableLabel'] as String? ?? '',
      closedOrderIds: raw.map((e) => e.toString()).toList(),
      tableReleased: j['tableReleased'] as bool? ?? false,
    );
  }
}

class CashierOpenOrderDto {
  CashierOpenOrderDto({
    required this.orderId,
    required this.orderNumber,
    required this.tableId,
    required this.tableLabel,
    required this.status,
    required this.orderTotal,
    required this.remainingPrincipal,
    required this.lineCount,
  });

  final String orderId;
  final String orderNumber;
  final String tableId;
  final String tableLabel;
  final String status;
  final double orderTotal;
  final double remainingPrincipal;
  final int lineCount;

  factory CashierOpenOrderDto.fromJson(Map<String, dynamic> j) {
    return CashierOpenOrderDto(
      orderId: j['orderId'].toString(),
      orderNumber: j['orderNumber'] as String? ?? '',
      tableId: j['tableId']?.toString() ?? '',
      tableLabel: j['tableLabel'] as String? ?? '-',
      status: j['status'] as String? ?? 'OPEN',
      orderTotal: _readMoney(j['orderTotal']),
      remainingPrincipal: _readMoney(j['remainingPrincipal']),
      lineCount: (j['lineCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class BillingSummaryDto {
  BillingSummaryDto({
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.orderTotal,
    required this.principalPaid,
    required this.remainingPrincipal,
    required this.lines,
    required this.payments,
  });

  final String orderId;
  final String orderNumber;
  final String status;
  final double orderTotal;
  final double principalPaid;
  final double remainingPrincipal;
  final List<BillingLineDto> lines;
  final List<dynamic> payments;

  factory BillingSummaryDto.fromJson(Map<String, dynamic> j) {
    final rawLines = j['lines'] as List<dynamic>? ?? [];
    return BillingSummaryDto(
      orderId: j['orderId'].toString(),
      orderNumber: j['orderNumber'] as String? ?? '',
      status: j['status'] as String? ?? '',
      orderTotal: _readMoney(j['orderTotal']),
      principalPaid: _readMoney(j['principalPaid']),
      remainingPrincipal: _readMoney(j['remainingPrincipal']),
      lines: rawLines
          .map((e) => BillingLineDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      payments: j['payments'] as List<dynamic>? ?? const [],
    );
  }
}

class BillingLineDto {
  BillingLineDto({
    required this.lineItemId,
    required this.productName,
    required this.quantity,
    required this.lineTotal,
    required this.remainingOnLine,
  });

  final String lineItemId;
  final String productName;
  final int quantity;
  final double lineTotal;
  final double remainingOnLine;

  factory BillingLineDto.fromJson(Map<String, dynamic> j) {
    return BillingLineDto(
      lineItemId: j['lineItemId'].toString(),
      productName: j['productName'] as String? ?? '',
      quantity: (j['quantity'] as num?)?.toInt() ?? 0,
      lineTotal: _readMoney(j['lineTotal']),
      remainingOnLine: _readMoney(j['remainingOnLine']),
    );
  }
}

class BillingPaymentResultDto {
  BillingPaymentResultDto({
    required this.paymentId,
    required this.principalAmount,
    required this.tipAmount,
    required this.remainingPrincipalAfter,
    required this.orderStatus,
  });

  final String paymentId;
  final double principalAmount;
  final double tipAmount;
  final double remainingPrincipalAfter;
  final String orderStatus;

  factory BillingPaymentResultDto.fromJson(Map<String, dynamic> j) {
    return BillingPaymentResultDto(
      paymentId: j['paymentId'].toString(),
      principalAmount: _readMoney(j['principalAmount']),
      tipAmount: _readMoney(j['tipAmount']),
      remainingPrincipalAfter: _readMoney(j['remainingPrincipalAfter']),
      orderStatus: j['orderStatus'] as String? ?? '',
    );
  }
}

String _formatApiError(String prefix, int statusCode, String body) {
  try {
    final map = jsonDecode(body) as Map<String, dynamic>;
    final msg = map['message'] as String? ?? map['error'] as String?;
    if (msg != null && msg.isNotEmpty) {
      return '$prefix ($statusCode): $msg';
    }
  } catch (_) {
    // body JSON değil
  }
  if (body.trim().isNotEmpty) {
    return '$prefix ($statusCode): $body';
  }
  return '$prefix ($statusCode)';
}

double _readMoney(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}
