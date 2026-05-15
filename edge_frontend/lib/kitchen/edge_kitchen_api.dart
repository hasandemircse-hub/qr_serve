import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

String _root(String edgeBaseUrl) {
  final s = edgeBaseUrl.trim();
  return s.endsWith('/') ? s.substring(0, s.length - 1) : s;
}

Map<String, String> _authHeaders(String? accessToken) {
  final h = <String, String>{'Accept': 'application/json'};
  if (accessToken != null && accessToken.isNotEmpty) {
    h['Authorization'] = 'Bearer $accessToken';
  }
  return h;
}

Future<List<KitchenQueueLineDto>> fetchKitchenQueue({
  required String edgeBaseUrl,
  required String? accessToken,
}) async {
  final uri = Uri.parse('${_root(edgeBaseUrl)}/api/v1/kitchen/queue');
  final res = await http.get(uri, headers: _authHeaders(accessToken));
  if (res.statusCode != 200) {
    throw Exception('Mutfak kuyruğu alınamadı (${res.statusCode})');
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  final raw = map['lines'] as List<dynamic>? ?? [];
  return raw.map((e) => KitchenQueueLineDto.fromJson(e as Map<String, dynamic>)).toList();
}

Future<void> markKitchenLineReceived({
  required String edgeBaseUrl,
  required String? accessToken,
  required String orderId,
  required String lineId,
}) async {
  final uri = Uri.parse(
    '${_root(edgeBaseUrl)}/api/v1/kitchen/orders/$orderId/lines/$lineId/received',
  );
  final res = await http.post(uri, headers: _authHeaders(accessToken));
  if (res.statusCode != 200 && res.statusCode != 202) {
    throw Exception('Alındı işaretlenemedi (${res.statusCode})');
  }
}

Future<void> markKitchenLineReady({
  required String edgeBaseUrl,
  required String? accessToken,
  required String orderId,
  required String lineId,
}) async {
  final uri = Uri.parse(
    '${_root(edgeBaseUrl)}/api/v1/kitchen/orders/$orderId/lines/$lineId/ready',
  );
  final res = await http.post(uri, headers: _authHeaders(accessToken));
  if (res.statusCode != 200 && res.statusCode != 202) {
    throw Exception('Hazır işaretlenemedi (${res.statusCode})');
  }
}

/// Edge `GuestQrWebSocketConfig`: `/ws/v1/kitchen/push?restaurantId=…` (JWT yok; LAN).
String kitchenPushWebSocketUrl(String edgeBaseUrl, String restaurantId) {
  final b = Uri.parse(edgeBaseUrl.trim());
  final wsScheme = b.scheme == 'https' ? 'wss' : 'ws';
  final sb = StringBuffer('$wsScheme://${b.host}');
  if (b.hasPort) {
    sb.write(':${b.port}');
  }
  sb.write('/ws/v1/kitchen/push?restaurantId=${Uri.encodeQueryComponent(restaurantId)}');
  return sb.toString();
}

class KitchenPushConnection {
  KitchenPushConnection._(this._channel, this._subscription);

  final WebSocketChannel _channel;
  final StreamSubscription<dynamic> _subscription;

  static KitchenPushConnection connect({
    required String edgeBaseUrl,
    required String restaurantId,
    required void Function(String message) onMessage,
    void Function(Object error)? onError,
  }) {
    final url = kitchenPushWebSocketUrl(edgeBaseUrl, restaurantId);
    final channel = WebSocketChannel.connect(Uri.parse(url));
    final sub = channel.stream.listen(
      (event) {
        if (event is String) {
          onMessage(event);
        }
      },
      onError: onError,
    );
    return KitchenPushConnection._(channel, sub);
  }

  void dispose() {
    _subscription.cancel();
    _channel.sink.close();
  }
}

class KitchenQueueLineDto {
  KitchenQueueLineDto({
    required this.orderId,
    required this.orderNumber,
    required this.tableLabel,
    required this.orderChannel,
    required this.orderedAt,
    required this.lineId,
    required this.productName,
    required this.quantity,
    required this.kitchenLineStatus,
  });

  final String orderId;
  final String orderNumber;
  final String tableLabel;
  final String orderChannel;
  final String? orderedAt;
  final String lineId;
  final String productName;
  final int quantity;
  final String kitchenLineStatus;

  factory KitchenQueueLineDto.fromJson(Map<String, dynamic> j) {
    return KitchenQueueLineDto(
      orderId: j['orderId'].toString(),
      orderNumber: j['orderNumber'] as String? ?? '',
      tableLabel: j['tableLabel'] as String? ?? '-',
      orderChannel: j['orderChannel'] as String? ?? 'QR',
      orderedAt: _orderedAtToString(j['orderedAt']),
      lineId: j['lineId'].toString(),
      productName: j['productName'] as String? ?? '',
      quantity: (j['quantity'] as num?)?.toInt() ?? 1,
      kitchenLineStatus: j['kitchenLineStatus'] as String? ?? 'PENDING',
    );
  }

  static String? _orderedAtToString(dynamic v) {
    if (v == null) {
      return null;
    }
    if (v is String) {
      return v;
    }
    if (v is List && v.isNotEmpty) {
      try {
        final y = (v[0] as num).toInt();
        final mo = (v[1] as num).toInt();
        final d = (v[2] as num).toInt();
        if (v.length >= 5) {
          final h = (v[3] as num).toInt();
          final mi = (v[4] as num).toInt();
          return '$y-${mo.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')} '
              '${h.toString().padLeft(2, '0')}:${mi.toString().padLeft(2, '0')}';
        }
        return '$y-${mo.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      } catch (_) {
        return v.toString();
      }
    }
    return v.toString();
  }
}
