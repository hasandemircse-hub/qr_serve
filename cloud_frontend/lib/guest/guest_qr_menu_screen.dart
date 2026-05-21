import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'product_option_picker_dialog.dart';

/// Misafir QR (Cloud public guest API): menü, sepet, sipariş durumu.
///
/// Akış:
///  1. `/session` — masa & restoran adı, sipariş alma kapalı mı?
///  2. `/menu` — kategoriler & ürünler
///  3. `/orders/open` — açık siparişler (her 10 sn polling)
///  4. `/orders` POST — sepetteki sipariş kalemleri
///  5. `/service-requests` POST — garson çağır / hesap iste
class GuestQrMenuScreen extends StatefulWidget {
  const GuestQrMenuScreen({
    super.key,
    required this.restaurantId,
    required this.tableId,
    required this.token,
  });

  final String restaurantId;
  final String tableId;
  final String token;

  @override
  State<GuestQrMenuScreen> createState() => _GuestQrMenuScreenState();
}

enum _EdgeConn {
  connecting,
  online,
  offline,
  invalid,
}

class _GuestQrMenuScreenState extends State<GuestQrMenuScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabs;
  final List<_CartLine> _cart = [];
  String _subtitle = 'Yükleniyor…';
  List<_GuestMenu> _menus = const [];
  final Map<String, Map<String, dynamic>> _orders = {};
  Timer? _pollTimer;
  bool _submitting = false;
  _EdgeConn _edgeConn = _EdgeConn.connecting;
  String? _edgeError;

  bool get _paramsOk =>
      widget.restaurantId.isNotEmpty &&
      widget.tableId.isNotEmpty &&
      widget.token.isNotEmpty;

  String get _origin {
    final base = Uri.base;
    return '${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}';
  }

  String _guestUrl(String suffix) {
    final tok = Uri.encodeComponent(widget.token);
    return '$_origin/api/v1/public/guest/r/${widget.restaurantId}'
        '/t/${widget.tableId}/$tok$suffix';
  }

  @override
  void initState() {
    super.initState();
    if (_paramsOk) {
      _tabs = TabController(length: 3, vsync: this);
      _bootstrap();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tabs?.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _refreshSession();
    if (_edgeConn == _EdgeConn.online) {
      await _loadMenu();
      await _loadOrders();
    }
    _pollTimer ??=
        Timer.periodic(const Duration(seconds: 10), (_) => _pollTick());
  }

  Future<void> _pollTick() async {
    final wasOnline = _edgeConn == _EdgeConn.online;
    await _refreshSession();
    if (_edgeConn == _EdgeConn.online) {
      if (!wasOnline) await _loadMenu();
      await _loadOrders();
    }
  }

  Future<void> _refreshSession() async {
    try {
      final s = await http
          .get(Uri.parse(_guestUrl('/session')), headers: const {
        'Accept': 'application/json'
      }).timeout(const Duration(seconds: 8));
      if (s.statusCode == 200) {
        final sj = jsonDecode(s.body) as Map<String, dynamic>;
        final rn = sj['restaurantName'] as String? ?? '';
        final tl = sj['tableLabel'] as String? ?? '';
        if (!mounted) return;
        setState(() {
          _subtitle = '$rn · Masa $tl';
          _edgeConn = _EdgeConn.online;
          _edgeError = null;
        });
        return;
      }
      if (s.statusCode == 401 || s.statusCode == 403 || s.statusCode == 404) {
        if (!mounted) return;
        setState(() {
          _edgeConn = _EdgeConn.invalid;
          _edgeError = 'QR kodu geçersiz veya süresi dolmuş.';
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _edgeConn = _EdgeConn.offline;
        _edgeError = _shortError(s.statusCode, s.body);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _edgeConn = _EdgeConn.offline;
        _edgeError = 'İnternet bağlantısı veya restoran cihazı ulaşılamıyor.';
      });
    }
  }

  String _shortError(int statusCode, String body) {
    if (statusCode == 502 || statusCode == 503 || statusCode == 504) {
      return 'Restoran cihazı şu an çevrimdışı. Bağlantı kurulmaya çalışılıyor…';
    }
    return 'Sunucu hatası ($statusCode). Tekrar deneniyor…';
  }

  Future<void> _loadMenu() async {
    try {
      final r = await http
          .get(Uri.parse(_guestUrl('/menu')), headers: const {
        'Accept': 'application/json'
      }).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return;
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      final menus = (data['menus'] as List<dynamic>? ?? [])
          .map((e) => _GuestMenu.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() => _menus = menus);
    } catch (_) {
      // Session polling zaten offline durumunu yakalayacak.
    }
  }

  Future<void> _loadOrders() async {
    try {
      final r = await http
          .get(Uri.parse(_guestUrl('/orders/open')), headers: const {
        'Accept': 'application/json'
      }).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return;
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      _orders.clear();
      for (final o in data['orders'] as List<dynamic>? ?? []) {
        final m = o as Map<String, dynamic>;
        final id = m['orderId'] as String? ?? '';
        if (id.isEmpty) continue;
        _orders[id] = Map<String, dynamic>.from(m);
      }
      if (mounted) setState(() {});
    } catch (_) {
      // sessizce yut
    }
  }

  Future<void> _addProduct(_GuestProduct p) async {
    if (_edgeConn != _EdgeConn.online) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Restoran çevrimdışı. Bağlantı kurulduğunda ürün ekleyebilirsiniz.')),
      );
      return;
    }
    Map<String, dynamic> selected = emptySelectedOptionsJson();
    try {
      final wizRes = await http
          .get(
            Uri.parse(_guestUrl('/products/${p.id}/option-wizard')),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 8));
      if (wizRes.statusCode == 200) {
        final wiz = jsonDecode(wizRes.body) as Map<String, dynamic>;
        final groups = (wiz['groups'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
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
    } catch (_) {
      // Wizard hatası kritik değil, varsayılan boş seçim ile devam et.
    }
    if (!mounted) return;
    setState(() {
      _cart.add(_CartLine(
        productId: p.id,
        label: p.name,
        unitPrice: p.price,
        quantity: 1,
        selectedOptions: selected,
      ));
    });
    if (_tabs!.index != 1) _tabs!.animateTo(1);
  }

  Future<void> _submitOrder() async {
    if (_cart.isEmpty || _submitting) return;
    if (_edgeConn != _EdgeConn.online) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Restoran çevrimdışı. Bağlantı kurulduğunda tekrar deneyin.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final lines = _cart
          .map((c) => {
                'productId': c.productId,
                'quantity': c.quantity,
                'selectedOptions': c.selectedOptions,
              })
          .toList();
      final res = await http
          .post(
            Uri.parse(_guestUrl('/orders')),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json'
            },
            body: jsonEncode({'lines': lines}),
          )
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (res.statusCode == 502 ||
          res.statusCode == 503 ||
          res.statusCode == 504) {
        setState(() {
          _edgeConn = _EdgeConn.offline;
          _edgeError =
              'Sipariş gönderilemedi: Restoran cihazı şu an çevrimdışı.';
        });
        await _showOrderFailDialog(
            'Restoran cihazına ulaşılamadı. Lütfen biraz sonra tekrar deneyin '
            'veya garsondan yardım isteyin.');
        return;
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        await _showOrderFailDialog(
            'Sipariş gönderilemedi (kod ${res.statusCode}). '
            'Lütfen tekrar deneyin veya garsondan yardım isteyin.');
        return;
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final orderNumber = body['orderNumber']?.toString() ?? '?';
      setState(() => _cart.clear());
      await _loadOrders();
      _tabs!.animateTo(2);
      if (!mounted) return;
      await _showOrderSuccessDialog(orderNumber);
    } on TimeoutException {
      if (!mounted) return;
      await _showOrderFailDialog(
          'Sipariş zaman aşımına uğradı. İnternet bağlantınızı kontrol edin '
          've tekrar deneyin.');
    } catch (e) {
      if (!mounted) return;
      await _showOrderFailDialog('Bağlantı hatası: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showOrderSuccessDialog(String orderNumber) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 56),
        title: const Text('Siparişiniz mutfağa iletildi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Sipariş numaranız: #$orderNumber',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text(
              'Siparişinizin hazırlanma durumunu "Siparişler" sekmesinden '
              'takip edebilirsiniz.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Tamam')),
        ],
      ),
    );
  }

  Future<void> _showOrderFailDialog(String message) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.error_outline, color: Colors.red, size: 56),
        title: const Text('Sipariş gönderilemedi'),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Kapat')),
        ],
      ),
    );
  }

  Future<void> _serviceRequest(String type, String label) async {
    if (_edgeConn != _EdgeConn.online) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label gönderilemedi: Restoran çevrimdışı.')),
      );
      return;
    }
    try {
      final res = await http
          .post(
            Uri.parse(_guestUrl('/service-requests')),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'type': type}),
          )
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (res.statusCode < 200 || res.statusCode >= 300) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label gönderilemedi (${res.statusCode})')),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label iletildi')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bağlantı hatası: $e')),
      );
    }
  }

  double get _cartTotal {
    var sum = 0.0;
    for (final c in _cart) {
      sum += c.unitPrice * c.quantity;
    }
    return sum;
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
              'Geçersiz QR bağlantısı. Lütfen masadaki QR kodu tekrar okutun '
              'veya garsondan yeni bir QR isteyin.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Misafir Menüsü'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _EdgeStatusBadge(
                conn: _edgeConn, onRetry: () => _refreshSession()),
          ),
        ],
        bottom: TabBar(
          controller: _tabs!,
          tabs: [
            const Tab(text: 'Menü'),
            Tab(text: 'Sepet (${_cart.length})'),
            Tab(text: 'Siparişler (${_orders.length})'),
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
              child: Text(_subtitle,
                  style: Theme.of(context).textTheme.titleSmall),
            ),
          ),
          if (_edgeConn == _EdgeConn.offline ||
              _edgeConn == _EdgeConn.invalid)
            _OfflineBanner(
              invalid: _edgeConn == _EdgeConn.invalid,
              message: _edgeError ??
                  'Restoran çevrimdışı. Bağlantı kurulmaya çalışılıyor.',
              onRetry: () => _refreshSession(),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabs!,
              children: [
                _MenuTab(menus: _menus, onProduct: _addProduct),
                _CartTab(
                  cart: _cart,
                  total: _cartTotal,
                  submitting: _submitting,
                  onRemove: (i) => setState(() => _cart.removeAt(i)),
                  onIncrement: (i) => setState(() {
                    _cart[i] = _cart[i].copyWith(quantity: _cart[i].quantity + 1);
                  }),
                  onDecrement: (i) => setState(() {
                    if (_cart[i].quantity > 1) {
                      _cart[i] = _cart[i].copyWith(quantity: _cart[i].quantity - 1);
                    } else {
                      _cart.removeAt(i);
                    }
                  }),
                  onSubmit: _submitOrder,
                ),
                _StatusTab(
                  orders: _orders.values.toList(),
                  onRefresh: _loadOrders,
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _serviceRequest('CALL_WAITER', 'Garson çağrısı'),
                      icon: const Icon(Icons.room_service_outlined),
                      label: const Text('Garson'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _serviceRequest('REQUEST_BILL', 'Hesap isteği'),
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: const Text('Hesap'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EdgeStatusBadge extends StatelessWidget {
  const _EdgeStatusBadge({required this.conn, required this.onRetry});
  final _EdgeConn conn;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = switch (conn) {
      _EdgeConn.connecting => (
          Colors.amber.shade300,
          'Bağlanıyor…',
          Icons.sync,
        ),
      _EdgeConn.online => (
          Colors.green.shade400,
          'Çevrimiçi',
          Icons.circle,
        ),
      _EdgeConn.offline => (
          Colors.red.shade300,
          'Çevrimdışı',
          Icons.cloud_off_outlined,
        ),
      _EdgeConn.invalid => (
          Colors.red.shade400,
          'Geçersiz',
          Icons.error_outline,
        ),
    };
    return InkWell(
      onTap: onRetry,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({
    required this.invalid,
    required this.message,
    required this.onRetry,
  });
  final bool invalid;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final color = invalid ? Colors.red.shade700 : Colors.orange.shade800;
    return Material(
      color: color.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Icon(
                invalid
                    ? Icons.error_outline
                    : Icons.warning_amber_rounded,
                color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ),
            if (!invalid)
              TextButton.icon(
                onPressed: onRetry,
                icon: Icon(Icons.refresh, color: color, size: 18),
                label: Text('Yenile', style: TextStyle(color: color)),
              ),
          ],
        ),
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
  _GuestProduct({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.imageUrl,
  });
  final String id;
  final String name;
  final String? description;
  final double price;
  final String? imageUrl;

  factory _GuestProduct.fromJson(Map<String, dynamic> j) {
    return _GuestProduct(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      description: j['description'] as String?,
      price: (j['price'] as num?)?.toDouble() ?? 0,
      imageUrl: j['imageUrl'] as String?,
    );
  }
}

class _CartLine {
  _CartLine({
    required this.productId,
    required this.label,
    required this.unitPrice,
    required this.quantity,
    required this.selectedOptions,
  });
  final String productId;
  final String label;
  final double unitPrice;
  final int quantity;
  final Map<String, dynamic> selectedOptions;

  _CartLine copyWith({int? quantity}) => _CartLine(
        productId: productId,
        label: label,
        unitPrice: unitPrice,
        quantity: quantity ?? this.quantity,
        selectedOptions: selectedOptions,
      );
}

class _MenuTab extends StatelessWidget {
  const _MenuTab({required this.menus, required this.onProduct});
  final List<_GuestMenu> menus;
  final void Function(_GuestProduct p) onProduct;

  @override
  Widget build(BuildContext context) {
    if (menus.isEmpty) {
      return const Center(
          child: Text('Menü yükleniyor veya henüz hazırlanmadı.'));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final m in menus) ...[
          Text(m.name,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final p in m.products)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onProduct(p),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (p.imageUrl != null && p.imageUrl!.isNotEmpty)
                      Image.network(
                        p.imageUrl!,
                        width: 88,
                        height: 88,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox(
                          width: 88,
                          height: 88,
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            if (p.description != null &&
                                p.description!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  p.description!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              '${p.price.toStringAsFixed(2)} ₺',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
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
    required this.total,
    required this.submitting,
    required this.onRemove,
    required this.onIncrement,
    required this.onDecrement,
    required this.onSubmit,
  });
  final List<_CartLine> cart;
  final double total;
  final bool submitting;
  final void Function(int index) onRemove;
  final void Function(int index) onIncrement;
  final void Function(int index) onDecrement;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    if (cart.isEmpty) {
      return const Center(child: Text('Sepetiniz boş. Menüden ürün seçin.'));
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
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.label,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            Text(
                                '${c.unitPrice.toStringAsFixed(2)} ₺ × ${c.quantity}'),
                          ],
                        ),
                      ),
                      IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => onDecrement(i)),
                      Text('${c.quantity}'),
                      IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => onIncrement(i)),
                      IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => onRemove(i)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  const Text('Toplam:',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('${total.toStringAsFixed(2)} ₺',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: submitting ? null : onSubmit,
                  child: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Siparişi gönder'),
                ),
              ),
            ],
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
      'PREPARING' => 'Hazırlanıyor',
      'SERVED' => 'Servis edildi',
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
              ? const Center(child: Text('Açık siparişiniz yok.'))
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
                            Row(
                              children: [
                                Text(
                                  '#${o['orderNumber'] ?? '?'}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const Spacer(),
                                Chip(
                                  label: Text(o['status']?.toString() ?? ''),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                            const Divider(),
                            for (final ln in lines)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${ln['productName']} × ${ln['quantity']}',
                                      ),
                                    ),
                                    Chip(
                                      label: Text(_kLabel(
                                          ln['kitchenLineStatus'] as String?)),
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
