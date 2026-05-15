import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

typedef GuestWsJsonHandler = void Function(Map<String, dynamic> json);

/// Edge `ws://…/ws/v1/guest?restaurantId=&tableId=&token=`
class GuestMenuWebSocketClient {
  GuestMenuWebSocketClient({
    required this.wsUri,
    required this.onJson,
    this.onError,
  });

  final Uri wsUri;
  final GuestWsJsonHandler onJson;
  final void Function(Object error, StackTrace stack)? onError;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;

  void connect() {
    disconnect();
    _channel = WebSocketChannel.connect(wsUri);
    _sub = _channel!.stream.listen(
      (message) {
        if (message is String) {
          try {
            final map = jsonDecode(message) as Map<String, dynamic>;
            onJson(map);
          } catch (_) {}
        }
      },
      onError: (Object e, StackTrace st) => onError?.call(e, st),
      onDone: () {},
    );
  }

  void disconnect() {
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close();
    _channel = null;
  }
}
