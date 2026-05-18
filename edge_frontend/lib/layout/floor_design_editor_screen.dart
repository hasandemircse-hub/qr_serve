import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';

import '../guest/guest_table_qr_sheet.dart';
import 'floor_layout_models.dart';

class _TablePose {
  _TablePose({
    required this.x,
    required this.y,
    required this.rotation,
    this.zone,
  });

  double x;
  double y;
  double rotation;
  String? zone;
}

/// Restoran yöneticisi: salon krokisi (sürükle-bırak, dönüş, bölge), kayıt, birleştir / böl, QR PDF.
class FloorDesignEditorScreen extends StatefulWidget {
  const FloorDesignEditorScreen({
    super.key,
    required this.edgeBaseUrl,
    required this.restaurantId,
    required this.authToken,
  });

  final String edgeBaseUrl;
  final String restaurantId;
  final String authToken;

  @override
  State<FloorDesignEditorScreen> createState() => _FloorDesignEditorScreenState();
}

class _FloorDesignEditorScreenState extends State<FloorDesignEditorScreen> {
  static const Size _canvas = Size(1400, 900);

  FloorLayoutSnapshot? _snapshot;
  final Map<String, _TablePose> _poses = {};
  int _floorTab = 0;
  String? _selectedTableId;
  bool _mergeMode = false;
  final Set<String> _mergePick = {};
  bool _loading = true;
  String? _error;
  final TextEditingController _zoneCtl = TextEditingController();

  Uri _api(String path) {
    final base = widget.edgeBaseUrl.replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base$path');
  }

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${widget.authToken}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  @override
  void initState() {
    super.initState();
    if (widget.authToken.isNotEmpty) {
      _load();
    } else {
      setState(() {
        _loading = false;
        _error = 'Oturum bulunamadı; lütfen yeniden giriş yapın.';
      });
    }
  }

  @override
  void dispose() {
    _zoneCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http.get(
        _api('/api/v1/restaurants/${widget.restaurantId}/layout'),
        headers: _headers,
      );
      if (res.statusCode != 200) {
        setState(() {
          _error = 'Yükleme ${res.statusCode}: ${res.body}';
          _loading = false;
        });
        return;
      }
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final snap = FloorLayoutSnapshot.fromJson(map);
      _poses.clear();
      for (final f in snap.floors) {
        for (final t in f.tables) {
          _poses[t.tableId] = _TablePose(
            x: t.x,
            y: t.y,
            rotation: t.rotation,
            zone: t.zone,
          );
        }
      }
      setState(() {
        _snapshot = snap;
        _floorTab = 0;
        _loading = false;
        _syncZoneField();
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  int _currentFloorIndexForApi() {
    final floors = _snapshot?.floors ?? const <FloorLayoutFloor>[];
    if (floors.isEmpty) return 0;
    return floors[_floorTab.clamp(0, floors.length - 1)].floorIndex;
  }

  String _suggestedNewTableLabel() {
    final floors = _snapshot?.floors ?? const <FloorLayoutFloor>[];
    if (floors.isEmpty) return 'M1';
    final f = floors[_floorTab.clamp(0, floors.length - 1)];
    return 'M${f.tables.length + 1}';
  }

  Future<void> _createTable() async {
    if (widget.authToken.isEmpty || _snapshot == null) return;
    try {
      final res = await http.post(
        _api('/api/v1/restaurants/${widget.restaurantId}/tables'),
        headers: _headers,
        body: jsonEncode({
          'label': _suggestedNewTableLabel(),
          'floorIndex': _currentFloorIndexForApi(),
          'shape': 'SQUARE',
          'seatCount': 4,
        }),
      );
      if (!mounted) return;
      if (res.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Masa eklenemedi: ${res.statusCode} ${res.body}'),
          ),
        );
        return;
      }
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final snap = FloorLayoutSnapshot.fromJson(map);
      _poses.clear();
      for (final f in snap.floors) {
        for (final t in f.tables) {
          _poses[t.tableId] = _TablePose(
            x: t.x,
            y: t.y,
            rotation: t.rotation,
            zone: t.zone,
          );
        }
      }
      setState(() {
        _snapshot = snap;
        _syncZoneField();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Yeni masa eklendi. Konumu burada sürükleyip Kaydet ile sabitleyin.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _syncZoneField() {
    final id = _selectedTableId;
    if (id == null) {
      _zoneCtl.text = '';
      return;
    }
    final t = _tableById(id);
    if (t == null) {
      _zoneCtl.text = '';
      return;
    }
    _zoneCtl.text = _poses[id]?.zone ?? t.zone ?? '';
  }

  TableLayoutNode? _tableById(String id) {
    final floors = _snapshot?.floors ?? const <FloorLayoutFloor>[];
    for (final f in floors) {
      for (final t in f.tables) {
        if (t.tableId == id) return t;
      }
    }
    return null;
  }

  List<TableLayoutNode> _tablesForCurrentFloor() {
    final floors = _snapshot?.floors ?? const <FloorLayoutFloor>[];
    if (floors.isEmpty) return const [];
    final f = floors[_floorTab.clamp(0, floors.length - 1)];
    return f.tables;
  }

  String _availabilityWire(TableAvailability a) {
    return switch (a) {
      TableAvailability.occupied => 'OCCUPIED',
      TableAvailability.reserved => 'RESERVED',
      _ => 'EMPTY',
    };
  }

  String _shapeWire(TableShape s) => s == TableShape.round ? 'ROUND' : 'SQUARE';

  Future<void> _saveLayout() async {
    final snap = _snapshot;
    if (snap == null) return;
    final body = <String, dynamic>{
      'schemaVersion': snap.schemaVersion,
      'restaurantId': snap.restaurantId,
      'floors': snap.floors.map((f) {
        return {
          'floorIndex': f.floorIndex,
          'label': f.label,
          'tables': f.tables.map((t) {
            final p = _poses[t.tableId];
            return {
              'tableId': t.tableId,
              'label': t.label,
              'shape': _shapeWire(t.shape),
              'x': p?.x ?? t.x,
              'y': p?.y ?? t.y,
              'width': t.width,
              'height': t.height,
              'floorIndex': f.floorIndex,
              'groupId': t.groupId,
              'availabilityStatus': _availabilityWire(t.availability),
              'seatCount': t.seatCount,
              'zone': p?.zone ?? t.zone,
              'rotation': p?.rotation ?? t.rotation,
            };
          }).toList(),
        };
      }).toList(),
    };
    try {
      final res = await http.put(
        _api('/api/v1/restaurants/${widget.restaurantId}/layout'),
        headers: _headers,
        body: jsonEncode(body),
      );
      if (!mounted) return;
      if (res.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kayıt başarısız: ${res.statusCode} ${res.body}')),
        );
        return;
      }
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final next = FloorLayoutSnapshot.fromJson(map);
      setState(() {
        _snapshot = next;
        for (final f in next.floors) {
          for (final t in f.tables) {
            final prev = _poses[t.tableId];
            _poses[t.tableId] = _TablePose(
              x: t.x,
              y: t.y,
              rotation: t.rotation,
              zone: prev?.zone ?? t.zone,
            );
          }
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Salon düzeni kaydedildi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _mergeSelected() async {
    if (_mergePick.length < 2) return;
    final ids = _mergePick.toList();
    try {
      final res = await http.post(
        _api('/api/v1/restaurants/${widget.restaurantId}/tables/merge'),
        headers: _headers,
        body: jsonEncode({'tableIds': ids}),
      );
      if (!mounted) return;
      if (res.statusCode < 200 || res.statusCode >= 300) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Birleştirme: ${res.statusCode} ${res.body}')),
        );
        return;
      }
      setState(() {
        _mergePick.clear();
        _mergeMode = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masalar birleştirildi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _unmergeSelected() async {
    final id = _selectedTableId;
    if (id == null) return;
    try {
      final res = await http.post(
        _api('/api/v1/restaurants/${widget.restaurantId}/tables/unmerge'),
        headers: _headers,
        body: jsonEncode({'tableId': id}),
      );
      if (!mounted) return;
      if (res.statusCode < 200 || res.statusCode >= 300) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ayırma: ${res.statusCode} ${res.body}')),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Birleştirme kaldırıldı (grup tamamı).')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _showPhoneQr(String tableId) async {
    try {
      final uri = _api(
        '/api/v1/restaurants/${widget.restaurantId}/tables/$tableId/guest-phone-qr',
      );
      final res = await http.get(uri, headers: {
        'Authorization': 'Bearer ${widget.authToken}',
        'Accept': 'application/json',
      });
      if (!mounted) return;
      if (res.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('QR link: ${res.statusCode} ${res.body}')),
        );
        return;
      }
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final url = j['phoneScanUrl'] as String? ?? '';
      if (url.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Telefon QR linki boş')),
        );
        return;
      }
      await showGuestTableQrSheet(
        context,
        tableLabel: j['tableLabel'] as String? ?? tableId,
        phoneScanUrl: url,
        restaurantId: j['restaurantId']?.toString() ?? widget.restaurantId,
        qrTableId: j['qrTableId']?.toString() ?? tableId,
        token: j['token'] as String? ?? '',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _downloadQrPdf(String tableId) async {
    try {
      final uri = _api(
        '/api/v1/restaurants/${widget.restaurantId}/tables/$tableId/qr-menu.pdf',
      );
      final res = await http.get(uri, headers: {
        'Authorization': 'Bearer ${widget.authToken}',
        'Accept': 'application/pdf',
      });
      if (!mounted) return;
      if (res.statusCode < 200 || res.statusCode >= 300) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF: ${res.statusCode}')),
        );
        return;
      }
      await Printing.sharePdf(bytes: res.bodyBytes, filename: 'masa-$tableId-qr.pdf');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _showSplitDialog() async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final orderCtl = TextEditingController();
    final partsCtl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Sipariş böl'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Her alt liste yeni bir siparişe taşınan satır kimlikleridir. '
                  'Tüm satırlar tam olarak bir kez atanmalıdır.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: orderCtl,
                  decoration: const InputDecoration(
                    labelText: 'Sipariş UUID',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: partsCtl,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'parts (JSON)',
                    hintText: '[["line-uuid-1"],["line-uuid-2","line-uuid-3"]]',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            FilledButton(
              onPressed: () async {
                final oid = orderCtl.text.trim();
                final raw = partsCtl.text.trim();
                if (oid.isEmpty || raw.isEmpty) return;
                List<dynamic> parsed;
                try {
                  parsed = jsonDecode(raw) as List<dynamic>;
                } catch (_) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Geçersiz JSON')),
                  );
                  return;
                }
                final parts = parsed
                    .map((e) => (e as List<dynamic>).map((x) => x as String).toList())
                    .toList();
                try {
                  final res = await http.post(
                    _api(
                      '/api/v1/restaurants/${widget.restaurantId}/orders/$oid/split',
                    ),
                    headers: _headers,
                    body: jsonEncode({'parts': parts}),
                  );
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (!mounted) return;
                  if (res.statusCode < 200 || res.statusCode >= 300) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Bölme: ${res.statusCode} ${res.body}')),
                    );
                    return;
                  }
                  final map = jsonDecode(res.body) as Map<String, dynamic>;
                  final ids = (map['newOrderIds'] as List<dynamic>?)?.join(', ') ?? '';
                  messenger.showSnackBar(
                    SnackBar(content: Text('Yeni siparişler: $ids')),
                  );
                } catch (e) {
                  if (!ctx.mounted) return;
                  if (!mounted) return;
                  messenger.showSnackBar(SnackBar(content: Text('$e')));
                }
              },
              child: const Text('Böl'),
            ),
          ],
        );
      },
    );
    orderCtl.dispose();
    partsCtl.dispose();
  }

  Color _fillFor(TableAvailability a) {
    return switch (a) {
      TableAvailability.occupied => Colors.redAccent.withValues(alpha: 0.35),
      TableAvailability.reserved => Colors.orangeAccent.withValues(alpha: 0.4),
      TableAvailability.empty => Colors.greenAccent.withValues(alpha: 0.25),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Yeniden dene')),
            ],
          ),
        ),
      );
    }

    final floors = _snapshot?.floors ?? const <FloorLayoutFloor>[];
    final tables = _tablesForCurrentFloor();
    final selected = _selectedTableId;
    final selPose = selected != null ? _poses[selected] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.tonalIcon(
                onPressed: _saveLayout,
                icon: const Icon(Icons.save),
                label: const Text('Kaydet'),
              ),
              FilledButton.tonalIcon(
                onPressed:
                    _snapshot != null && widget.authToken.isNotEmpty ? _createTable : null,
                icon: const Icon(Icons.add_box_outlined),
                label: const Text('Yeni masa'),
              ),
              FilterChip(
                label: const Text('Birleştirme seçimi'),
                selected: _mergeMode,
                onSelected: (v) => setState(() {
                  _mergeMode = v;
                  if (!v) _mergePick.clear();
                }),
              ),
              FilledButton.tonal(
                onPressed: _mergePick.length >= 2 ? _mergeSelected : null,
                child: Text('Birleştir (${_mergePick.length})'),
              ),
              FilledButton.tonal(
                onPressed: selected != null ? _unmergeSelected : null,
                child: const Text('Birleştirmeyi kaldır'),
              ),
              FilledButton.tonal(
                onPressed: _showSplitDialog,
                child: const Text('Sipariş böl'),
              ),
              FilledButton.tonalIcon(
                onPressed: selected != null ? () => _showPhoneQr(selected) : null,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Telefon QR'),
              ),
              FilledButton.tonalIcon(
                onPressed: selected != null ? () => _downloadQrPdf(selected) : null,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Masa QR PDF'),
              ),
            ],
          ),
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
                        onSelected: (_) => setState(() {
                          _floorTab = i;
                          _selectedTableId = null;
                          _syncZoneField();
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (selected != null && selPose != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Dönüş: ${selPose.rotation.round()}°'),
                Slider(
                  value: selPose.rotation.clamp(0, 359),
                  min: 0,
                  max: 359,
                  divisions: 72,
                  label: '${selPose.rotation.round()}°',
                  onChanged: (v) {
                    setState(() {
                      selPose.rotation = v;
                      _poses[selected] = selPose;
                    });
                  },
                ),
                TextField(
                  controller: _zoneCtl,
                  decoration: const InputDecoration(
                    labelText: 'Bölge (zone)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (z) {
                    _poses[selected]?.zone = z.isEmpty ? null : z;
                  },
                ),
              ],
            ),
          ),
        Expanded(
          child: LayoutBuilder(
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
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _GridPainter(step: 32),
                        ),
                      ),
                      for (final t in tables)
                        _buildTableWidget(t),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTableWidget(TableLayoutNode t) {
    final pose = _poses[t.tableId]!;
    final isSel = _selectedTableId == t.tableId;
    final inMerge = _mergePick.contains(t.tableId);
    final borderColor = _mergeMode && inMerge
        ? Colors.deepPurple
        : (isSel ? Colors.blue : Colors.black87);
    final borderW = (isSel || inMerge) ? 3.0 : 2.0;

    Widget face;
    if (t.shape == TableShape.round) {
      face = ClipOval(
        child: Container(
          width: t.width,
          height: t.height,
          color: _fillFor(t.availability),
          alignment: Alignment.center,
          child: Text(
            t.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: Colors.black87,
            ),
          ),
        ),
      );
    } else {
      face = Container(
        width: t.width,
        height: t.height,
        decoration: BoxDecoration(
          color: _fillFor(t.availability),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor, width: borderW),
        ),
        alignment: Alignment.center,
        child: Text(
          t.label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: Colors.black87,
          ),
        ),
      );
    }

    if (t.shape == TableShape.round) {
      face = Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: borderW),
        ),
        child: face,
      );
    }

    return Positioned(
      left: pose.x,
      top: pose.y,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            if (_mergeMode) {
              if (_mergePick.contains(t.tableId)) {
                _mergePick.remove(t.tableId);
              } else if (_mergePick.length < 2) {
                _mergePick.add(t.tableId);
              } else {
                _mergePick.remove(_mergePick.first);
                _mergePick.add(t.tableId);
              }
            } else {
              _selectedTableId = t.tableId;
              _syncZoneField();
            }
          });
        },
        onPanUpdate: (d) {
          setState(() {
            pose.x += d.delta.dx;
            pose.y += d.delta.dy;
          });
        },
        child: Transform.rotate(
          angle: pose.rotation * math.pi / 180,
          child: face,
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({this.step = 32});

  final double step;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFFF5F5F5);
    canvas.drawRect(Offset.zero & size, bg);
    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => oldDelegate.step != step;
}
