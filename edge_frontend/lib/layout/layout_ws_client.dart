import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'floor_layout_models.dart';

typedef LayoutSnapshotHandler = void Function(FloorLayoutSnapshot snapshot);

/// Edge üzerinden `ws://…/ws/v1/layout?restaurantId=` kanalına bağlanır.
class LayoutWebSocketClient {
  LayoutWebSocketClient({
    required this.wsUri,
    required this.onSnapshot,
    this.onError,
  });

  final Uri wsUri;
  final LayoutSnapshotHandler onSnapshot;
  final void Function(Object error, StackTrace stack)? onError;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;

  void connect() {
    disconnect();
    _channel = WebSocketChannel.connect(wsUri);
    _sub = _channel!.stream.listen(
      (message) {
        if (message is String) {
          final snap = FloorLayoutSnapshot.tryParse(message);
          if (snap != null) onSnapshot(snap);
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
