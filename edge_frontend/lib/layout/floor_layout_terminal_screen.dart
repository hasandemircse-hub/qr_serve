import 'package:flutter/material.dart';

import 'floor_layout_models.dart';
import 'floor_plan_painter.dart';
import 'layout_ws_client.dart';

/// Garson / kasa terminali: WebSocket ile anlık salon + masa durumu.
class FloorLayoutTerminalScreen extends StatefulWidget {
  const FloorLayoutTerminalScreen({
    super.key,
    required this.restaurantId,
    this.wsHost = '127.0.0.1:8081',
    this.useTls = false,
  });

  final String restaurantId;
  final String wsHost;
  final bool useTls;

  @override
  State<FloorLayoutTerminalScreen> createState() =>
      _FloorLayoutTerminalScreenState();
}

class _FloorLayoutTerminalScreenState extends State<FloorLayoutTerminalScreen> {
  FloorLayoutSnapshot? _snapshot;
  int _floorTab = 0;
  LayoutWebSocketClient? _client;
  String _status = 'Bağlanıyor…';

  @override
  void initState() {
    super.initState();
    _connect();
  }

  void _connect() {
    final scheme = widget.useTls ? 'wss' : 'ws';
    final uri = Uri.parse(
      '$scheme://${widget.wsHost}/ws/v1/layout?restaurantId=${widget.restaurantId}',
    );
    _client = LayoutWebSocketClient(
      wsUri: uri,
      onSnapshot: (snap) {
        setState(() {
          _snapshot = snap;
          if (_floorTab >= snap.floors.length) {
            _floorTab = 0;
          }
          _status = 'Bağlı · ${snap.generatedAt}';
        });
      },
      onError: (e, st) {
        setState(() {
          _status = 'Hata: $e';
        });
      },
    )..connect();
  }

  @override
  void dispose() {
    _client?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final floors = _snapshot?.floors ?? const <FloorLayoutFloor>[];
    final tables = floors.isEmpty
        ? const <TableLayoutNode>[]
        : floors[_floorTab.clamp(0, floors.length - 1)].tables;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            _status,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        if (floors.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < floors.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        selected: _floorTab == i,
                        label: Text(floors[i].label),
                        onSelected: (_) => setState(() => _floorTab = i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return InteractiveViewer(
                constrained: false,
                boundaryMargin: const EdgeInsets.all(400),
                minScale: 0.2,
                maxScale: 4,
                child: CustomPaint(
                  size: Size(
                    constraints.maxWidth.clamp(320, 2000),
                    constraints.maxHeight.clamp(240, 2000),
                  ),
                  painter: FloorPlanPainter(tables: tables),
                ),
              );
            },
          ),
        ),
        const _LegendBar(),
      ],
    );
  }
}

class _LegendBar extends StatelessWidget {
  const _LegendBar();

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          spacing: 16,
          runSpacing: 4,
          children: const [
            _LegendDot(color: Colors.greenAccent, label: 'Boş'),
            _LegendDot(color: Colors.redAccent, label: 'Dolu'),
            _LegendDot(color: Colors.orangeAccent, label: 'Rezerve'),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.5),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black45),
          ),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}
