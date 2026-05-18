import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../waiter/edge_waiter_api.dart';
import '../widgets/product_option_picker_dialog.dart';
import 'guest_menu_ws_client.dart';

/// Misafir QR: Edge veya Cloud BFF guest API + Edge WebSocket.
class GuestQrMenuScreen extends StatefulWidget {
  const GuestQrMenuScreen({
    super.key,
    required this.guestApiBaseUrl,
    required this.realtimeBaseUrl,
    this.useCloudGuestApi = false,
    required this.restaurantId,
    required this.tableId,
    required this.token,
  });

  final String guestApiBaseUrl;
  final String realtimeBaseUrl;
  final bool useCloudGuestApi;
  final String restaurantId;
  final String tableId;
  final String token;

  @override
  State<GuestQrMenuScreen> createState() => _GuestQrMenuScreenState();
}

class _GuestQrMenuScreenState extends State<GuestQrMenuScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabs;
  final List<_CartLine> _cart = [];
  GuestMenuWebSocketClient? _ws;
  String _subtitle = 'Yükleniyor…';
  List<_GuestMenu> _menus = const [];
  final Map<String, Map<String, dynamic>> _orders = {};
  String _wsStatus = 'Bağlanıyor…';
  String _wsBaseUrl = '';

  bool get _paramsOk =>
      widget.restaurantId.isNotEmpty && widget.tableId.isNotEmpty && widget.token.isNotEmpty;

  String get _apiBase => widget.guestApiBaseUrl.replaceAll(RegExp(r'/+$'), '');

  String _guest(String suffix) {
    final tok = Uri.encodeComponent(widget.token);
    final prefix = widget.useCloudGuestApi
        ? '/api/v1/public/guest/r'
        : '/api/v1/guest/r';
    return '$_apiBase$prefix/${widget.restaurantId}/t/${widget.tableId}/$tok$suffix';
  }

  Uri _wsUri() {
    final wsBase = _wsBaseUrl.isNotEmpty ? _wsBaseUrl : widget.realtimeBaseUrl;
    final u = Uri.parse(wsBase.trim());
    final port = u.hasPort ? u.port : 8081;
    final scheme = u.scheme == 'https' ? 'wss' : 'ws';
    return Uri.parse(
      '$scheme://${u.host}:$port/ws/v1/guest?'
      'restaurantId=${Uri.encodeQueryComponent(widget.restaurantId)}'
      '&tableId=${Uri.encodeQueryComponent(widget.tableId)}'
      '&token=${Uri.encodeQueryComponent(widget.token)}',
    );
  }

  @override
  void initState() {
    super.initState();
    if (_paramsOk) {
      _tabs = TabController(length: 3, vsync: this);
      _bootstrap();
    }
  }

  Future<void> _bootstrap() async {
    try {
      final s = await http.get(Uri.parse(_guest('/session')), headers: const {'Accept': 'application/json'});
      if (s.statusCode != 200) {
        setState(() => _subtitle = 'Oturum hatası ${s.statusCode}');
        return;
      }
      final sj = jsonDecode(s.body) as Map<String, dynamic>;
      final rn = sj['restaurantName'] as String? ?? '';
      final tl = sj['tableLabel'] as String? ?? '';
      final edgeWs = sj['edgeRealtimeBaseUrl'] as String? ?? '';
      _wsBaseUrl = edgeWs.isNotEmpty ? edgeWs : widget.realtimeBaseUrl;
      setState(() => _subtitle = '$rn · Masa $tl');
      await _loadMenu();
      await _loadOrders();
      _connectWs();
    } catch (e) {
      setState(() => _subtitle = 'Hata: $e');
    }
  }

  Future<void> _loadMenu() async {
    final r = await http.get(Uri.parse(_guest('/menu')), headers: const {'Accept': 'application/json'});
    if (r.statusCode != 200) return;
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    final menus = (data['menus'] as List<dynamic>? ?? [])
        .map((e) => _GuestMenu.fromJson(e as Map<String, dynamic>))
        .toList();
    setState(() => _menus = menus);
  }

  Future<void> _loadOrders() async {
    final r = await http.get(Uri.parse(_guest('/orders/open')), headers: const {'Accept': 'application/json'});
    if (r.statusCode != 200) return;
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    _hydrateOrders(data);
    setState(() {});
  }

  void _hydrateOrders(Map<String, dynamic> data) {
    _orders.clear();
    for (final o in data['orders'] as List<dynamic>? ?? []) {
      final m = o as Map<String, dynamic>;
      final id = m['orderId'] as String? ?? '';
      if (id.isEmpty) continue;
      _orders[id] = Map<String, dynamic>.from(m);
    }
  }

  void _connectWs() {
    _ws?.disconnect();
    _ws = GuestMenuWebSocketClient(
      wsUri: _wsUri(),
      onJson: (obj) {
        final t = obj['type'] as String?;
        if (t == 'ORDER_CONFIRMED') {
          final id = obj['orderId'] as String? ?? '';
          if (id.isNotEmpty) {
            _orders[id] = {
              'orderId': id,
              'orderNumber': obj['orderNumber'],
              'status': 'OPEN',
              'orderedAt': null,
              'lines': obj['lines'],
            };
          }
          setState(() {});
        } else if (t == 'LINE_KITCHEN_STATUS') {
          final oid = obj['orderId'] as String?;
          final lid = obj['lineId']?.toString();
          final st = obj['kitchenLineStatus'] as String?;
          if (oid != null && _orders.containsKey(oid) && lid != null) {
            final lines = (_orders[oid]!['lines'] as List<dynamic>?) ?? [];
            for (final ln in lines) {
              final mm = ln as Map<String, dynamic>;
              if (mm['lineItemId']?.toString() == lid) {
                mm['kitchenLineStatus'] = st;
                break;
              }
            }
          }
          setState(() {});
        }
      },
      onError: (e, _) {
        if (mounted) setState(() => _wsStatus = 'WS: $e');
      },
    )..connect();
    setState(() => _wsStatus = 'Bağlı');
  }

  @override
  void dispose() {
    _ws?.disconnect();
    _tabs?.dispose();
    super.dispose();
  }

  Future<void> _addProduct(_GuestProduct p) async {
    Map<String, dynamic> selected = emptySelectedOptionsJson();
    final wizRes = await http.get(
      Uri.parse(_guest('/products/${p.id}/option-wizard')),
      headers: const {'Accept': 'application/json'},
    );
    if (wizRes.statusCode == 200) {
      final wiz = jsonDecode(wizRes.body) as Map<String, dynamic>;
      final groups = (wiz['groups'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      if (groups.isNotEmpty && mounted) {
        final picked = await showProductOptionPickerDialog(
          context,
          productName: p.name,
          groups: groups,
        );
        if (picked == null) return;
        selected = picked;
      }
    }
    if (!mounted) return;
    setState(() {
      _cart.add(_CartLine(productId: p.id, label: p.name, quantity: 1, selectedOptions: selected));
    });
    if (_tabs!.index != 1) _tabs!.animateTo(1);
  }

  Future<void> _submitOrder() async {
    if (_cart.isEmpty) return;
    final lines = _cart
        .map(
          (c) => {
            'productId': c.productId,
            'quantity': c.quantity,
            'selectedOptions': c.selectedOptions,
          },
        )
        .toList();
    final res = await http.post(
      Uri.parse(_guest('/orders')),
      headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'lines': lines}),
    );
    if (!mounted) return;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sipariş: ${res.statusCode} ${res.body}')),
      );
      return;
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sipariş: ${body['orderNumber']}')),
    );
    setState(() => _cart.clear());
    await _loadOrders();
    _tabs!.animateTo(2);
  }

  Future<void> _serviceRequest(String type) async {
    final res = await http.post(
      Uri.parse(_guest('/service-requests')),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'type': type}),
    );
    if (!mounted) return;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('İstek gönderilemedi')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('İstek iletildi')));
  }

  @override
  Widget build(BuildContext context) {
    if (!_paramsOk) {
      return Scaffold(
        appBar: AppBar(title: const Text('Misafir')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Geçersiz bağlantı. Misafir lab ekranından bir masaya tıklayın '
              'veya r, t, k sorgu parametrelerinin dolu olduğundan emin olun.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              final r = Uri.encodeQueryComponent(widget.restaurantId);
              context.go('/guest-lab?restaurantId=$r');
            }
          },
        ),
        title: const Text('Misafir menü'),
        bottom: TabBar(
          controller: _tabs!,
          tabs: const [
            Tab(text: 'Menü'),
            Tab(text: 'Sepet'),
            Tab(text: 'Durum'),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_subtitle, style: Theme.of(context).textTheme.titleSmall),
                  Text(_wsStatus, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs!,
              children: [
                _MenuTab(menus: _menus, onProduct: _addProduct),
                _CartTab(
                  cart: _cart,
                  onRemove: (i) => setState(() => _cart.removeAt(i)),
                  onSubmit: _submitOrder,
                ),
                _StatusTab(
                  orders: _orders.values.toList(),
                  onRefresh: _loadOrders,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _serviceRequest('CALL_WAITER'),
                  icon: const Icon(Icons.room_service_outlined),
                  label: const Text('Garson'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _serviceRequest('REQUEST_BILL'),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Hesap'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestMenu {
  _GuestMenu({required this.name, required this.products});
  final String name;
  final List<_GuestProduct> products;

  factory _GuestMenu.fromJson(Map<String, dynamic> j) {
    final prods = (j['products'] as List<dynamic>? ?? [])
        .map((e) => _GuestProduct.fromJson(e as Map<String, dynamic>))
        .toList();
    return _GuestMenu(name: j['name'] as String? ?? '', products: prods);
  }
}

class _GuestProduct {
  _GuestProduct({required this.id, required this.name, this.description, required this.price});
  final String id;
  final String name;
  final String? description;
  final double price;

  factory _GuestProduct.fromJson(Map<String, dynamic> j) {
    return _GuestProduct(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      description: j['description'] as String?,
      price: (j['price'] as num?)?.toDouble() ?? 0,
    );
  }
}

class _CartLine {
  _CartLine({
    required this.productId,
    required this.label,
    required this.quantity,
    required this.selectedOptions,
  });
  final String productId;
  final String label;
  final int quantity;
  final Map<String, dynamic> selectedOptions;
}

class _MenuTab extends StatelessWidget {
  const _MenuTab({required this.menus, required this.onProduct});
  final List<_GuestMenu> menus;
  final void Function(_GuestProduct p) onProduct;

  @override
  Widget build(BuildContext context) {
    if (menus.isEmpty) {
      return const Center(child: Text('Menü boş veya yüklenemedi.'));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final m in menus) ...[
          Text(m.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (final p in m.products)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(p.name),
                subtitle: p.description != null && p.description!.isNotEmpty
                    ? Text(p.description!, maxLines: 2, overflow: TextOverflow.ellipsis)
                    : null,
                trailing: Text(
                  '${p.price.toStringAsFixed(2)} ₺',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () => onProduct(p),
              ),
            ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _CartTab extends StatelessWidget {
  const _CartTab({
    required this.cart,
    required this.onRemove,
    required this.onSubmit,
  });
  final List<_CartLine> cart;
  final void Function(int index) onRemove;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    if (cart.isEmpty) {
      return const Center(child: Text('Sepet boş. Menüden ürün ekleyin.'));
    }
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: cart.length,
            itemBuilder: (context, i) {
              final c = cart[i];
              return Card(
                child: ListTile(
                  title: Text(c.label),
                  subtitle: Text('Adet: ${c.quantity}'),
                  trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => onRemove(i)),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: onSubmit,
            child: const Text('Siparişi gönder'),
          ),
        ),
      ],
    );
  }
}

class _StatusTab extends StatelessWidget {
  const _StatusTab({required this.orders, required this.onRefresh});
  final List<Map<String, dynamic>> orders;
  final Future<void> Function() onRefresh;

  static String _kLabel(String? st) {
    return switch (st) {
      'READY' => 'Hazır',
      'RECEIVED' => 'Hazırlanıyor',
      _ => 'Bekliyor',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => onRefresh(),
            icon: const Icon(Icons.refresh),
            label: const Text('Yenile'),
          ),
        ),
        Expanded(
          child: orders.isEmpty
              ? const Center(child: Text('Açık sipariş yok.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: orders.length,
                  itemBuilder: (context, i) {
                    final o = orders[i];
                    final lines = (o['lines'] as List<dynamic>? ?? []);
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              o['orderNumber']?.toString() ?? o['orderId'].toString(),
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(o['status']?.toString() ?? '', style: Theme.of(context).textTheme.bodySmall),
                            const Divider(),
                            for (final ln in lines)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${ln['productName']} × ${ln['quantity']}',
                                      ),
                                    ),
                                    Chip(
                                      label: Text(_kLabel(ln['kitchenLineStatus'] as String?)),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                              ),
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
}
