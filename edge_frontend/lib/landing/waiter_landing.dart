import 'dart:convert';

import 'package:flutter/material.dart';

import '../auth/auth_session.dart';
import '../widgets/product_option_picker_dialog.dart';
import '../widgets/staff_profile_banner.dart';
import '../waiter/edge_waiter_api.dart';
import '../waiter/waiter_floor_map_screen.dart';

/// Garson: Edge'den masa listesi, menü + sepet, `POST /api/v1/waiter/orders`.
class WaiterLanding extends StatefulWidget {
  const WaiterLanding({
    super.key,
    required this.auth,
    required this.edgeBaseUrl,
  });

  final AuthSession auth;
  final String edgeBaseUrl;

  @override
  State<WaiterLanding> createState() => _WaiterLandingState();
}

class _WaiterLandingState extends State<WaiterLanding> {
  String _zone = 'Tümü';

  static const _zones = ['Tümü', 'Salon', 'Teras', 'Paket'];

  List<WaiterTableDto>? _tables;
  Object? _tablesError;
  bool _tablesLoading = true;

  List<WaiterReadyLineDto> _readyLines = [];
  final Set<String> _dismissedLineIds = {};
  bool _readyLoading = false;
  Object? _readyError;
  WaiterPushConnection? _push;

  int get _readyBadgeCount =>
      _readyLines.where((l) => !_dismissedLineIds.contains(l.lineId)).length;

  @override
  void initState() {
    super.initState();
    _loadTables();
    _loadReadyLines();
    _connectPush();
  }

  @override
  void dispose() {
    _push?.dispose();
    super.dispose();
  }

  void _connectPush() {
    final rid = widget.auth.restaurantId;
    if (rid == null || rid.isEmpty) return;
    try {
      _push = WaiterPushConnection.connect(
        edgeBaseUrl: widget.edgeBaseUrl,
        restaurantId: rid,
        onMessage: _onPushMessage,
      );
    } catch (_) {
      // WS isteğe bağlı
    }
  }

  void _onPushMessage(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final t = map['type'] as String?;
      if (t == 'LINE_KITCHEN_STATUS') {
        final status = map['kitchenLineStatus'] as String? ?? '';
        final lineId = map['lineId']?.toString() ?? '';
        if (status == 'READY' && lineId.isNotEmpty) {
          final row = WaiterReadyLineDto.fromPush(map);
          if (!mounted) return;
          setState(() {
            _dismissedLineIds.remove(lineId);
            _readyLines.removeWhere((l) => l.lineId == lineId);
            _readyLines.insert(0, row);
          });
          _toast(context, 'Hazır: Masa ${row.tableLabel} · ${row.productName}');
        } else if (lineId.isNotEmpty) {
          setState(() {
            _readyLines.removeWhere((l) => l.lineId == lineId);
          });
        }
      } else if (t == 'GUEST_SERVICE_REQUEST') {
        final tableLabel = map['tableLabel'] as String? ?? '-';
        final reqType = map['requestType'] as String? ?? '';
        if (mounted) {
          _toast(context, 'Masa $tableLabel: $reqType');
        }
      }
    } catch (_) {
      // yut
    }
  }

  Future<void> _loadReadyLines() async {
    setState(() {
      _readyLoading = true;
      _readyError = null;
    });
    try {
      final list = await fetchWaiterReadyLines(
        edgeBaseUrl: widget.edgeBaseUrl,
        accessToken: widget.auth.accessToken,
      );
      if (!mounted) return;
      setState(() {
        _readyLines = list.where((l) => !_dismissedLineIds.contains(l.lineId)).toList();
        _readyLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _readyError = e;
        _readyLoading = false;
      });
    }
  }

  void _dismissReadyLine(String lineId) {
    setState(() {
      _dismissedLineIds.add(lineId);
      _readyLines.removeWhere((l) => l.lineId == lineId);
    });
  }

  void _showReadySheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final visible = _readyLines.where((l) => !_dismissedLineIds.contains(l.lineId)).toList();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Hazır siparişler', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (visible.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('Şu an hazır bekleyen satır yok.'),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: visible.length,
                  itemBuilder: (context, i) {
                    final l = visible[i];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                        title: Text('Masa ${l.tableLabel}'),
                        subtitle: Text('${l.productName} × ${l.quantity}\n${l.orderNumber}'),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.done_all),
                          tooltip: 'Teslim alındı',
                          onPressed: () {
                            _dismissReadyLine(l.lineId);
                            Navigator.pop(ctx);
                            setState(() {});
                          },
                        ),
                      ),
                    );
                  },
                ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _loadReadyLines();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Listeyi yenile'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadTables() async {
    setState(() {
      _tablesLoading = true;
      _tablesError = null;
    });
    try {
      final list = await fetchWaiterTables(
        edgeBaseUrl: widget.edgeBaseUrl,
        accessToken: widget.auth.accessToken,
      );
      if (!mounted) return;
      setState(() {
        _tables = list;
        _tablesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _tablesError = e;
        _tablesLoading = false;
      });
    }
  }

  List<WaiterTableDto> _filteredTables() {
    final all = _tables ?? const <WaiterTableDto>[];
    if (_zone == 'Tümü') return all;
    return all.where((t) => (t.zone ?? '').trim() == _zone).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Garson'),
        actions: [
          IconButton(
            tooltip: 'Masaları yenile',
            onPressed: _tablesLoading ? null : _loadTables,
            icon: _tablesLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Hazır siparişler',
            onPressed: _showReadySheet,
            icon: Badge(
              isLabelVisible: _readyBadgeCount > 0,
              label: Text('$_readyBadgeCount'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: widget.auth.signOut,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          StaffProfileBanner(
            auth: widget.auth,
            roleLabel: 'GARSON',
            icon: Icons.room_service_outlined,
            subtitle: 'Masayı seçin; menüden ürün ekleyip Edge’e sipariş gönderin.',
          ),
          const SizedBox(height: 16),
          _ReadyLinesPanel(
            loading: _readyLoading,
            error: _readyError,
            lines: _readyLines,
            dismissed: _dismissedLineIds,
            onRefresh: _loadReadyLines,
            onDismiss: _dismissReadyLine,
          ),
          const SizedBox(height: 20),
          if (_tablesError != null) ...[
            Card(
              color: scheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Masalar yüklenemedi: $_tablesError',
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _loadTables,
                      child: const Text('Yeniden dene'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text('Bölge', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final z in _zones)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(z),
                      selected: _zone == z,
                      onSelected: (_) => setState(() => _zone = z),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Masalar', style: Theme.of(context).textTheme.titleLarge),
              TextButton.icon(
                onPressed: _tables == null || _tables!.isEmpty
                    ? null
                    : () => _openFloorMap(context),
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('Harita'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_tablesLoading && _tables == null)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_filteredTables().isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                _tables == null || _tables!.isEmpty
                    ? 'Bu restoran için kayıtlı masa yok. Admin ekranından masa ekleyin.'
                    : 'Bu bölgede masa yok.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            )
          else
            LayoutBuilder(
              builder: (context, c) {
                final cross = c.maxWidth > 700 ? 4 : (c.maxWidth > 480 ? 3 : 2);
                final list = _filteredTables();
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: cross,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.05,
                  children: [
                    for (final t in list)
                      _TableCardFromDto(
                        table: t,
                        onTap: () => _openOrderFlow(context, t),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  static void _toast(BuildContext context, String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  void _openFloorMap(BuildContext context) {
    final rid = widget.auth.restaurantId;
    if (rid == null || rid.isEmpty) {
      _toast(context, 'Restoran bilgisi eksik (JWT).');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WaiterFloorMapScreen(
          edgeBaseUrl: widget.edgeBaseUrl,
          restaurantId: rid,
          accessToken: widget.auth.accessToken,
          tables: _tables ?? const [],
          zoneFilter: _zone,
          onTableSelected: (t) => _openOrderFlow(context, t),
        ),
      ),
    );
  }

  Future<void> _openOrderFlow(BuildContext context, WaiterTableDto table) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final h = MediaQuery.sizeOf(ctx).height * 0.9;
        return SizedBox(
          height: h,
          child: _WaiterTableOrderPanel(
            edgeBaseUrl: widget.edgeBaseUrl,
            accessToken: widget.auth.accessToken,
            table: table,
            onPlaced: (r) {
              if (context.mounted) {
                _toast(
                  context,
                  'Sipariş ${r.orderNumber} gönderildi (${r.grandTotal.toStringAsFixed(2)} ₺).',
                );
              }
            },
          ),
        );
      },
    );
  }
}

class _ReadyLinesPanel extends StatelessWidget {
  const _ReadyLinesPanel({
    required this.loading,
    required this.error,
    required this.lines,
    required this.dismissed,
    required this.onRefresh,
    required this.onDismiss,
  });

  final bool loading;
  final Object? error;
  final List<WaiterReadyLineDto> lines;
  final Set<String> dismissed;
  final VoidCallback onRefresh;
  final void Function(String lineId) onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visible = lines.where((l) => !dismissed.contains(l.lineId)).toList();

    return Card(
      color: scheme.primaryContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.room_service, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Mutfaktan hazır',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: 'Yenile',
                  onPressed: loading ? null : onRefresh,
                  icon: loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
            if (error != null)
              Text('$error', style: TextStyle(color: scheme.error)),
            if (visible.isEmpty && error == null && !loading)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('Hazır bekleyen ürün yok. Mutfak “Hazır” işaretleyince burada görünür.'),
              )
            else
              for (final l in visible.take(5))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.check_circle, color: Colors.green, size: 22),
                  title: Text('Masa ${l.tableLabel} · ${l.productName}'),
                  subtitle: Text('× ${l.quantity}  ·  ${l.orderNumber}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.done_all, size: 20),
                    tooltip: 'Teslim alındı',
                    onPressed: () => onDismiss(l.lineId),
                  ),
                ),
            if (visible.length > 5)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '+ ${visible.length - 5} satır daha (zil simgesine tıklayın)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CartLine {
  _CartLine({
    required this.productId,
    required this.name,
    required this.unitPrice,
    required this.selectedOptions,
  });

  final String productId;
  final String name;
  final double unitPrice;
  final Map<String, dynamic> selectedOptions;
  int qty = 1;

  double get lineTotal => unitPrice * qty;

  String get optionsKey => jsonEncode(selectedOptions);
}

class _WaiterTableOrderPanel extends StatefulWidget {
  const _WaiterTableOrderPanel({
    required this.edgeBaseUrl,
    required this.accessToken,
    required this.table,
    required this.onPlaced,
  });

  final String edgeBaseUrl;
  final String? accessToken;
  final WaiterTableDto table;
  final void Function(WaiterPlaceOrderResult r) onPlaced;

  @override
  State<_WaiterTableOrderPanel> createState() => _WaiterTableOrderPanelState();
}

class _WaiterTableOrderPanelState extends State<_WaiterTableOrderPanel> {
  late Future<WaiterMenuPayload> _menuFuture;
  final List<_CartLine> _cart = [];
  bool _submitting = false;
  bool _addingProduct = false;

  @override
  void initState() {
    super.initState();
    _menuFuture = fetchWaiterMenu(
      edgeBaseUrl: widget.edgeBaseUrl,
      accessToken: widget.accessToken,
    );
  }

  Future<void> _submit() async {
    if (_cart.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final lines = _cart
          .map(
            (l) => <String, dynamic>{
              'productId': l.productId,
              'quantity': l.qty,
              'selectedOptions': l.selectedOptions,
            },
          )
          .toList();
      final res = await placeWaiterOrder(
        edgeBaseUrl: widget.edgeBaseUrl,
        accessToken: widget.accessToken,
        tableId: widget.table.id,
        lines: lines,
      );
      if (!mounted) return;
      widget.onPlaced(res);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _addProduct(WaiterMenuProductDto p) async {
    if (_addingProduct) return;
    setState(() => _addingProduct = true);
    try {
      Map<String, dynamic> selected = emptySelectedOptionsJson();
      List<Map<String, dynamic>> wizardGroups = const [];
      try {
        final wiz = await fetchProductOptionWizard(
          edgeBaseUrl: widget.edgeBaseUrl,
          accessToken: widget.accessToken,
          productId: p.id,
        );
        wizardGroups = wiz.groups;
        if (wizardGroups.isNotEmpty && mounted) {
          final picked = await showProductOptionPickerDialog(
            context,
            productName: p.name,
            groups: wizardGroups,
          );
          if (picked == null) return;
          selected = picked;
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Seçenekler yüklenemedi: $e')),
        );
        return;
      }
      if (!mounted) return;
      final unitPrice = wizardGroups.isEmpty
          ? p.price
          : unitPriceWithSelectedOptions(p.price, wizardGroups, selected);
      final optionsKey = jsonEncode(selected);
      setState(() {
        final idx = _cart.indexWhere(
          (l) => l.productId == p.id && l.optionsKey == optionsKey,
        );
        if (idx >= 0) {
          _cart[idx].qty += 1;
        } else {
          _cart.add(
            _CartLine(
              productId: p.id,
              name: p.name,
              unitPrice: unitPrice,
              selectedOptions: selected,
            ),
          );
        }
      });
    } finally {
      if (mounted) setState(() => _addingProduct = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Masa ${widget.table.label}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if ((widget.table.zone ?? '').isNotEmpty)
                Text(
                  widget.table.zone!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
        if (_cart.isNotEmpty)
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: ExpansionTile(
              initiallyExpanded: true,
              title: Text('Sepet (${_cart.fold<int>(0, (a, b) => a + b.qty)} ürün)'),
              children: [
                for (var i = 0; i < _cart.length; i++)
                  Builder(
                    builder: (context) {
                      final l = _cart[i];
                      final hasOptions =
                          ((l.selectedOptions['steps'] as List<dynamic>?) ?? []).isNotEmpty;
                      return ListTile(
                        dense: true,
                        title: Text(l.name),
                        subtitle: Text(
                          hasOptions
                              ? '${l.unitPrice.toStringAsFixed(2)} ₺ × ${l.qty} (seçenekli)'
                              : '${l.unitPrice.toStringAsFixed(2)} ₺ × ${l.qty}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () {
                                setState(() {
                                  if (l.qty > 1) {
                                    l.qty -= 1;
                                  } else {
                                    _cart.removeAt(i);
                                  }
                                });
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => setState(() => l.qty += 1),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Siparişi Edge’e gönder'),
                  ),
                ),
              ],
            ),
          ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<WaiterMenuPayload>(
            future: _menuFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Menü: ${snap.error}'),
                  ),
                );
              }
              final menu = snap.data!;
              if (menu.menus.isEmpty) {
                return const Center(child: Text('Aktif menü yok.'));
              }
              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  for (final m in menu.menus) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        m.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    for (final p in m.products)
                      ListTile(
                        title: Text(p.name),
                        subtitle: Text('${p.price.toStringAsFixed(2)} ₺'),
                        trailing: IconButton(
                          icon: _addingProduct
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.add_shopping_cart_outlined),
                          onPressed: _addingProduct ? null : () => _addProduct(p),
                        ),
                        onTap: _addingProduct ? null : () => _addProduct(p),
                      ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TableCardFromDto extends StatelessWidget {
  const _TableCardFromDto({
    required this.table,
    required this.onTap,
  });

  final WaiterTableDto table;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = scheme.surfaceContainerHighest;
    final zone = (table.zone ?? '').trim().isEmpty ? '—' : table.zone!.trim();
    final seats = table.seatCount;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      table.label,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  Icon(Icons.event_seat_outlined, size: 22, color: scheme.primary),
                ],
              ),
              const Spacer(),
              Text(zone, style: Theme.of(context).textTheme.labelMedium),
              if (seats != null && seats > 0)
                Text(
                  '$seats kişi',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              const SizedBox(height: 6),
              Text(
                'Sipariş al',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
