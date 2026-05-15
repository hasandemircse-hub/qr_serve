import 'dart:convert';

import 'package:flutter/material.dart';

import '../auth/auth_session.dart';
import '../kitchen/edge_kitchen_api.dart';
import '../widgets/staff_profile_banner.dart';

/// Mutfak: Edge `GET /api/v1/kitchen/queue`, satır durumu `POST …/received|ready`, WS yenileme.
class KitchenLanding extends StatefulWidget {
  const KitchenLanding({
    super.key,
    required this.auth,
    required this.edgeBaseUrl,
  });

  final AuthSession auth;
  final String edgeBaseUrl;

  @override
  State<KitchenLanding> createState() => _KitchenLandingState();
}

class _KitchenLandingState extends State<KitchenLanding> with SingleTickerProviderStateMixin {
  late TabController _tabs;

  List<KitchenQueueLineDto> _lines = [];
  Object? _loadError;
  bool _loading = true;
  KitchenPushConnection? _push;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadQueue();
    final rid = widget.auth.restaurantId;
    if (rid != null && rid.isNotEmpty) {
      try {
        _push = KitchenPushConnection.connect(
          edgeBaseUrl: widget.edgeBaseUrl,
          restaurantId: rid,
          onMessage: _onPushMessage,
        );
      } catch (_) {
        // WS isteğe bağlı; REST kuyruk çalışır
      }
    }
  }

  void _onPushMessage(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final t = map['type'] as String?;
      if (t == 'NEW_GUEST_ORDER' || t == 'LINE_KITCHEN_STATUS') {
        _loadQueue(silent: true);
      }
    } catch (_) {
      // yut
    }
  }

  Future<void> _loadQueue({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final list = await fetchKitchenQueue(
        edgeBaseUrl: widget.edgeBaseUrl,
        accessToken: widget.auth.accessToken,
      );
      if (!mounted) return;
      setState(() {
        _lines = list;
        if (!silent) {
          _loading = false;
          _loadError = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (!silent) {
          _loadError = e;
          _loading = false;
        }
      });
    }
  }

  @override
  void dispose() {
    _push?.dispose();
    _tabs.dispose();
    super.dispose();
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  List<KitchenQueueLineDto> _byStatus(String status) =>
      _lines.where((l) => l.kitchenLineStatus == status).toList();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final waiting = _byStatus('PENDING');
    final active = _byStatus('RECEIVED');
    final ready = _byStatus('READY');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mutfak'),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: 'Bekleyen (${waiting.length})'),
            Tab(text: 'Üzerinde (${active.length})'),
            Tab(text: 'Hazır (${ready.length})'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _loading ? null : _loadQueue,
            icon: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Ses / yazıcı',
            onPressed: () => _toast('İstasyon ayarları yakında.'),
            icon: const Icon(Icons.volume_up_outlined),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: widget.auth.signOut,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: StaffProfileBanner(
              auth: widget.auth,
              roleLabel: 'MUTFAK',
              icon: Icons.restaurant,
              subtitle: 'Açık adisyon satırları Edge’den; push ile otomatik yenilenir.',
            ),
          ),
          if (_loadError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Card(
                color: scheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(child: Text('$_loadError')),
                      TextButton(onPressed: _loadQueue, child: const Text('Tekrar')),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _KitchenLineTab(
                  lines: waiting,
                  emptyHint: 'Bekleyen satır yok.',
                  scheme: scheme,
                  primaryLabel: 'Başlat',
                  onPrimary: (line) => _markReceived(line),
                ),
                _KitchenLineTab(
                  lines: active,
                  emptyHint: 'Üzerinde çalışılan satır yok.',
                  scheme: scheme,
                  primaryLabel: 'Hazır',
                  onPrimary: (line) => _markReady(line),
                ),
                _KitchenLineTab(
                  lines: ready,
                  emptyHint: 'Hazır satır yok.',
                  scheme: scheme,
                  primaryLabel: 'Servise çıktı',
                  onPrimary: (_) => _toast('Servis/garson tarafı sonraki sprintte bağlanacak.'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markReceived(KitchenQueueLineDto line) async {
    try {
      await markKitchenLineReceived(
        edgeBaseUrl: widget.edgeBaseUrl,
        accessToken: widget.auth.accessToken,
        orderId: line.orderId,
        lineId: line.lineId,
      );
      await _loadQueue(silent: true);
      if (mounted) _toast('Satır mutfağa alındı.');
    } catch (e) {
      if (mounted) _toast('$e');
    }
  }

  Future<void> _markReady(KitchenQueueLineDto line) async {
    try {
      await markKitchenLineReady(
        edgeBaseUrl: widget.edgeBaseUrl,
        accessToken: widget.auth.accessToken,
        orderId: line.orderId,
        lineId: line.lineId,
      );
      await _loadQueue(silent: true);
      if (mounted) _toast('Hazır olarak işaretlendi.');
    } catch (e) {
      if (mounted) _toast('$e');
    }
  }
}

class _KitchenLineTab extends StatelessWidget {
  const _KitchenLineTab({
    required this.lines,
    required this.emptyHint,
    required this.scheme,
    required this.primaryLabel,
    required this.onPrimary,
  });

  final List<KitchenQueueLineDto> lines;
  final String emptyHint;
  final ColorScheme scheme;
  final String primaryLabel;
  final void Function(KitchenQueueLineDto) onPrimary;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 56, color: scheme.outline),
              const SizedBox(height: 16),
              Text(emptyHint, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: lines.length,
      itemBuilder: (context, i) {
        final line = lines[i];
        final ch = line.orderChannel.trim().toUpperCase();
        final priority = ch == 'WAITER';
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        line.orderNumber.isNotEmpty ? line.orderNumber : line.orderId,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    if (priority)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: const Text('Garson'),
                        avatar: const Icon(Icons.room_service_outlined, size: 18),
                      ),
                    Chip(label: Text(line.tableLabel)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${line.productName} × ${line.quantity}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (line.orderedAt != null && line.orderedAt!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      line.orderedAt!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => onPrimary(line),
                    child: Text(primaryLabel),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
