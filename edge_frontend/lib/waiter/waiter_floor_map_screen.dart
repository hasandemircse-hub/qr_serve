import 'package:flutter/material.dart';

import '../layout/floor_layout_api.dart';
import '../layout/floor_layout_models.dart';
import '../layout/floor_plan_painter.dart';
import '../layout/layout_ws_client.dart';
import 'edge_waiter_api.dart';

/// Garson: canlı salon haritası; masaya dokununca sipariş akışı.
class WaiterFloorMapScreen extends StatefulWidget {
  const WaiterFloorMapScreen({
    super.key,
    required this.edgeBaseUrl,
    required this.restaurantId,
    required this.accessToken,
    required this.tables,
    required this.zoneFilter,
    required this.onTableSelected,
  });

  final String edgeBaseUrl;
  final String restaurantId;
  final String? accessToken;
  final List<WaiterTableDto> tables;
  final String zoneFilter;
  final void Function(WaiterTableDto table) onTableSelected;

  @override
  State<WaiterFloorMapScreen> createState() => _WaiterFloorMapScreenState();
}

class _WaiterFloorMapScreenState extends State<WaiterFloorMapScreen> {
  static const _canvas = Size(1400, 900);

  FloorLayoutSnapshot? _snapshot;
  int _floorTab = 0;
  LayoutWebSocketClient? _client;
  String _status = 'Yükleniyor…';
  String? _selectedTableId;

  Map<String, WaiterTableDto> get _tablesById => {
        for (final t in widget.tables) t.id: t,
      };

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final snap = await fetchRestaurantLayout(
        edgeBaseUrl: widget.edgeBaseUrl,
        accessToken: widget.accessToken,
        restaurantId: widget.restaurantId,
      );
      if (mounted) {
        setState(() {
          _snapshot = snap;
          _status = 'Bağlanıyor…';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _status = 'Yükleme hatası: $e');
    }
    _connectWs();
  }

  void _connectWs() {
    final base = Uri.parse(widget.edgeBaseUrl.trim());
    final wsScheme = base.scheme == 'https' ? 'wss' : 'ws';
    final port = base.hasPort ? base.port : 8081;
    final uri = Uri.parse(
      '$wsScheme://${base.host}:$port/ws/v1/layout?restaurantId=${widget.restaurantId}',
    );
    _client = LayoutWebSocketClient(
      wsUri: uri,
      onSnapshot: (snap) {
        if (!mounted) return;
        setState(() {
          _snapshot = snap;
          if (_floorTab >= snap.floors.length) _floorTab = 0;
          _status = 'Canlı · ${snap.generatedAt}';
        });
      },
      onError: (e, _) {
        if (mounted) setState(() => _status = 'WS: $e');
      },
    )..connect();
  }

  @override
  void dispose() {
    _client?.disconnect();
    super.dispose();
  }

  bool _matchesZone(WaiterTableDto t) {
    if (widget.zoneFilter == 'Tümü') return true;
    return (t.zone ?? '').trim() == widget.zoneFilter;
  }

  bool _matchesZoneNode(TableLayoutNode node) {
    final dto = _tablesById[node.tableId];
    if (dto == null) return widget.zoneFilter == 'Tümü';
    return _matchesZone(dto);
  }

  void _onTableTap(TableLayoutNode node) {
    final dto = _tablesById[node.tableId];
    if (dto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu masa garson listesinde yok.')),
      );
      return;
    }
    if (!_matchesZone(dto)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bölge filtresi: ${widget.zoneFilter}')),
      );
      return;
    }
    setState(() => _selectedTableId = node.tableId);
    widget.onTableSelected(dto);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final floors = _snapshot?.floors ?? const <FloorLayoutFloor>[];
    final allTables = floors.isEmpty
        ? const <TableLayoutNode>[]
        : floors[_floorTab.clamp(0, floors.length - 1)].tables;
    final tables = allTables.where(_matchesZoneNode).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Salon haritası'),
        actions: [
          if (widget.zoneFilter != 'Tümü')
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Chip(
                  label: Text(widget.zoneFilter),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Text(_status, style: Theme.of(context).textTheme.bodySmall),
          ),
          if (floors.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            child: _snapshot == null
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return InteractiveViewer(
                        constrained: false,
                        boundaryMargin: const EdgeInsets.all(400),
                        minScale: 0.15,
                        maxScale: 4,
                        child: SizedBox(
                          width: _canvas.width,
                          height: _canvas.height,
                          child: Stack(
                            children: [
                              CustomPaint(
                                size: _canvas,
                                painter: FloorPlanPainter(tables: tables),
                              ),
                              for (final t in tables)
                                Positioned(
                                  left: t.x,
                                  top: t.y,
                                  width: t.width,
                                  height: t.height,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => _onTableTap(t),
                                      child: Container(
                                        decoration: _selectedTableId == t.tableId
                                            ? BoxDecoration(
                                                border: Border.all(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                  width: 3,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const _MapLegendBar(),
        ],
      ),
    );
  }
}

class _MapLegendBar extends StatelessWidget {
  const _MapLegendBar();

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          spacing: 16,
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
