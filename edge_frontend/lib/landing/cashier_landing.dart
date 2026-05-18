import 'dart:convert';

import 'package:flutter/material.dart';

import '../auth/app_user_role.dart';
import '../auth/auth_session.dart';
import '../billing/edge_cashier_api.dart';
import '../widgets/staff_profile_banner.dart';

/// Kasa: `GET /api/v1/cashier/open-orders` + `BillingController` ile tahsilat.
class CashierLanding extends StatefulWidget {
  const CashierLanding({
    super.key,
    required this.auth,
    required this.edgeBaseUrl,
  });

  final AuthSession auth;
  final String edgeBaseUrl;

  @override
  State<CashierLanding> createState() => _CashierLandingState();
}

class _CashierLandingState extends State<CashierLanding> {
  final _search = TextEditingController();

  List<CashierOpenOrderDto> _orders = [];
  Object? _loadError;
  bool _loading = true;
  CashierPushConnection? _push;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _load(silent: false);
    final rid = widget.auth.restaurantId;
    if (rid != null && rid.isNotEmpty) {
      try {
        _push = CashierPushConnection.connect(
          edgeBaseUrl: widget.edgeBaseUrl,
          restaurantId: rid,
          onMessage: _onPushMessage,
        );
      } catch (_) {
        // WS isteğe bağlı; REST çalışır
      }
    }
  }

  void _onPushMessage(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final t = map['type'] as String?;
      if (t == 'NEW_ORDER' || t == 'OPEN_ORDERS_REFRESH') {
        _load(silent: true);
        if (t == 'NEW_ORDER' && mounted) {
          final table = map['tableLabel'] as String? ?? '-';
          final no = map['orderNumber'] as String? ?? '';
          _toast('Yeni adisyon: Masa $table ${no.isNotEmpty ? '($no)' : ''}');
        }
      }
    } catch (_) {
      // yut
    }
  }

  @override
  void dispose() {
    _push?.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final list = await fetchCashierOpenOrders(
        edgeBaseUrl: widget.edgeBaseUrl,
        accessToken: widget.auth.accessToken,
      );
      if (!mounted) return;
      setState(() {
        _orders = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _loading = false;
      });
    }
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  String? get _restaurantId => widget.auth.restaurantId;

  List<CashierOpenOrderDto> _filtered() {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _orders;
    return _orders
        .where(
          (o) =>
              o.tableLabel.toLowerCase().contains(q) ||
              o.orderNumber.toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> _openPaySheet(CashierOpenOrderDto order) async {
    final rid = _restaurantId;
    if (rid == null || rid.isEmpty) {
      _toast('Restoran bilgisi eksik (JWT).');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(ctx).bottom),
          child: _CashierPaySheet(
            edgeBaseUrl: widget.edgeBaseUrl,
            accessToken: widget.auth.accessToken,
            restaurantId: rid,
            order: order,
            onPaid: () {
              Navigator.of(ctx).pop();
              _load();
            },
          ),
        );
      },
    );
  }

  Future<void> _closeTable(CashierOpenOrderDto order) async {
    if (order.tableId.isEmpty) {
      _toast('Bu adisyonda masa bilgisi yok.');
      return;
    }
    try {
      final res = await closeTableSession(
        edgeBaseUrl: widget.edgeBaseUrl,
        accessToken: widget.auth.accessToken,
        tableId: order.tableId,
      );
      if (!mounted) return;
      _toast(
        res.tableReleased
            ? 'Masa ${res.tableLabel} boşaltıldı.'
            : 'Adisyonlar kapatıldı; masada başka açık hesap olabilir.',
      );
      await _load();
    } catch (e) {
      if (mounted) _toast('$e');
    }
  }

  Future<void> _forceCloseTable(
    CashierOpenOrderDto order,
    BillingSummaryDto summary,
  ) async {
    if (order.tableId.isEmpty) {
      _toast('Bu adisyonda masa bilgisi yok.');
      return;
    }
    final noteCtrl = TextEditingController();
    var reasonCode = 'MANAGER_FORCE_CLOSE';
    var balanceDisposition = 'VOID';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Bakiyeli masayı kapat'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Kalan bakiye: ${summary.remainingPrincipal.toStringAsFixed(2)} ₺',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: balanceDisposition,
                  decoration: const InputDecoration(
                    labelText: 'Kalan bakiye',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'VOID',
                      child: Text('İptal (VOID)'),
                    ),
                    DropdownMenuItem(
                      value: 'WRITE_OFF',
                      child: Text('Zarar yaz (WRITE_OFF)'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => balanceDisposition = v);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: reasonCode,
                  decoration: const InputDecoration(
                    labelText: 'Sebep',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'MANAGER_FORCE_CLOSE',
                      child: Text('Yönetici kararı'),
                    ),
                    DropdownMenuItem(
                      value: 'GUEST_LEFT',
                      child: Text('Misafir ayrıldı'),
                    ),
                    DropdownMenuItem(
                      value: 'STAFF_ERROR',
                      child: Text('Personel hatası'),
                    ),
                    DropdownMenuItem(value: 'OTHER', child: Text('Diğer')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => reasonCode = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Not',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Zorla kapat'),
            ),
          ],
        ),
      ),
    );
    final note = noteCtrl.text.trim();
    noteCtrl.dispose();
    if (confirmed != true) return;
    try {
      final res = await closeTableSession(
        edgeBaseUrl: widget.edgeBaseUrl,
        accessToken: widget.auth.accessToken,
        tableId: order.tableId,
        body: {
          'policy': 'FORCE_CLOSE_UNPAID',
          'reasonCode': reasonCode,
          'balanceDisposition': balanceDisposition,
          'note': note.isEmpty ? null : note,
        },
      );
      if (!mounted) return;
      _toast(
        res.tableReleased
            ? 'Masa ${res.tableLabel} zorla kapatıldı.'
            : 'Adisyon kapatıldı; masada başka açık hesap olabilir.',
      );
      await _load();
    } catch (e) {
      if (mounted) _toast('$e');
    }
  }

  Future<void> _openDetail(CashierOpenOrderDto order) async {
    final rid = _restaurantId;
    if (rid == null || rid.isEmpty) {
      _toast('Restoran bilgisi eksik (JWT).');
      return;
    }
    try {
      final s = await fetchBillingSummary(
        edgeBaseUrl: widget.edgeBaseUrl,
        accessToken: widget.auth.accessToken,
        restaurantId: rid,
        orderId: order.orderId,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            order.orderNumber.isNotEmpty ? order.orderNumber : order.orderId,
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Masa: ${order.tableLabel}'),
                Text('Durum: ${s.status}'),
                Text('Toplam: ${s.orderTotal.toStringAsFixed(2)} ₺'),
                Text('Ödenen: ${s.principalPaid.toStringAsFixed(2)} ₺'),
                Text('Kalan: ${s.remainingPrincipal.toStringAsFixed(2)} ₺'),
                const Divider(),
                for (final l in s.lines)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${l.productName} × ${l.quantity}'),
                    subtitle: Text(
                      'Satır ${l.lineTotal.toStringAsFixed(2)} ₺ · Kalan ${l.remainingOnLine.toStringAsFixed(2)} ₺',
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            if (order.tableId.isNotEmpty && s.remainingPrincipal <= 0.001)
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _closeTable(order);
                },
                child: const Text('Masayı kapat'),
              ),
            if (order.tableId.isNotEmpty &&
                s.remainingPrincipal > 0.001 &&
                widget.auth.role == AppUserRole.restaurantAdmin)
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _forceCloseTable(order, s);
                },
                child: const Text('Zorla kapat'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Kapat'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _openPaySheet(order);
              },
              child: const Text('Ödeme'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) _toast('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filtered = _filtered();
    final sumRemaining = filtered.fold<double>(
      0,
      (s, o) => s + o.remainingPrincipal,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasa'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _loading ? null : _load,
            icon: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Gün sonu',
            onPressed: () => _toast('Gün sonu raporu yakında.'),
            icon: const Icon(Icons.summarize_outlined),
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
            roleLabel: 'KASA',
            icon: Icons.point_of_sale_outlined,
            subtitle:
                'Açık bakiyeler Edge’den; kalan tutarı REMAINDER ile tahsil edin.',
          ),
          if (_loadError != null) ...[
            const SizedBox(height: 12),
            Card(
              color: scheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(child: Text('$_loadError')),
                    TextButton(onPressed: _load, child: const Text('Tekrar')),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          SearchBar(
            controller: _search,
            hintText: 'Masa veya adisyon no…',
            leading: const Icon(Icons.search),
            trailing: [
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _search.clear();
                  setState(() {});
                },
              ),
            ],
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Açık adisyonlar (${filtered.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                'Kalan ${sumRemaining.toStringAsFixed(2)} ₺',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: scheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_loading && filtered.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long, size: 48, color: scheme.outline),
                    const SizedBox(height: 12),
                    Text(
                      _orders.isEmpty
                          ? 'Bakiyesi olan açık adisyon yok.'
                          : 'Aramaya uygun kayıt yok.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ...filtered.map((o) {
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: scheme.secondaryContainer,
                    child: Text(
                      o.tableLabel.length > 3
                          ? o.tableLabel.substring(0, 3)
                          : o.tableLabel,
                      style: TextStyle(
                        color: scheme.onSecondaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  title: Text(
                    '${o.remainingPrincipal.toStringAsFixed(2)} ₺ kalan',
                  ),
                  subtitle: Text(
                    '${o.lineCount} kalem · ${o.orderNumber.isNotEmpty ? o.orderNumber : o.orderId} · ${o.status}',
                  ),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => _openDetail(o),
                        child: const Text('Detay'),
                      ),
                      FilledButton(
                        onPressed: () => _openPaySheet(o),
                        child: const Text('Ödeme'),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 24),
          Text('Kısayollar', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => _toast('İade / iptal — ayrı API sonrası.'),
                icon: const Icon(Icons.undo_outlined),
                label: const Text('İade'),
              ),
              FilledButton.tonalIcon(
                onPressed: () =>
                    _toast('Ödeme ekranından Nakit veya Kart seçin.'),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Nakit'),
              ),
              FilledButton.tonalIcon(
                onPressed: () =>
                    _toast('Ödeme ekranından Nakit veya Kart seçin.'),
                icon: const Icon(Icons.credit_card),
                label: const Text('Kart'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CashierPaySheet extends StatefulWidget {
  const _CashierPaySheet({
    required this.edgeBaseUrl,
    required this.accessToken,
    required this.restaurantId,
    required this.order,
    required this.onPaid,
  });

  final String edgeBaseUrl;
  final String? accessToken;
  final String restaurantId;
  final CashierOpenOrderDto order;
  final VoidCallback onPaid;

  @override
  State<_CashierPaySheet> createState() => _CashierPaySheetState();
}

class _CashierPaySheetState extends State<_CashierPaySheet> {
  late Future<BillingSummaryDto> _summaryFuture;
  final _tipCtrl = TextEditingController(text: '0');
  final _amountCtrl = TextEditingController();
  String _method = 'CASH';
  String _paymentMode = 'REMAINDER';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _summaryFuture = fetchBillingSummary(
      edgeBaseUrl: widget.edgeBaseUrl,
      accessToken: widget.accessToken,
      restaurantId: widget.restaurantId,
      orderId: widget.order.orderId,
    );
  }

  @override
  void dispose() {
    _tipCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pay(BillingSummaryDto summary) async {
    final tip = double.tryParse(_tipCtrl.text.replaceAll(',', '.')) ?? 0;
    if (tip < 0) return;
    final fixedAmount = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
    if (_paymentMode == 'FIXED_AMOUNT') {
      if (fixedAmount == null || fixedAmount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tahsil edilecek tutarı girin.')),
        );
        return;
      }
      if (fixedAmount > summary.remainingPrincipal + 0.001) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tutar kalan bakiyeyi aşamaz.')),
        );
        return;
      }
    }
    setState(() => _submitting = true);
    try {
      final body = _paymentMode == 'FIXED_AMOUNT'
          ? buildFixedAmountPaymentBody(
              method: _method,
              fixedAmount: fixedAmount!,
              tipAmount: tip,
            )
          : buildRemainderPaymentBody(method: _method, tipAmount: tip);
      final result = await postBillingPayment(
        edgeBaseUrl: widget.edgeBaseUrl,
        accessToken: widget.accessToken,
        restaurantId: widget.restaurantId,
        orderId: widget.order.orderId,
        body: body,
      );
      if (!mounted) return;
      if (result.orderStatus == 'CLOSED' &&
          widget.order.tableId.isNotEmpty &&
          result.remainingPrincipalAfter <= 0.001) {
        try {
          final closed = await closeTableSession(
            edgeBaseUrl: widget.edgeBaseUrl,
            accessToken: widget.accessToken,
            tableId: widget.order.tableId,
          );
          if (mounted && closed.tableReleased) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Masa ${closed.tableLabel} boşaltıldı.')),
            );
          }
        } catch (_) {
          // Ödeme başarılı; masa kapatma isteğe bağlı
        }
      }
      widget.onPaid();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: FutureBuilder<BillingSummaryDto>(
          future: _summaryFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError) {
              return SizedBox(
                height: 160,
                child: Center(child: Text('${snap.error}')),
              );
            }
            final s = snap.data!;
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.order.orderNumber.isNotEmpty
                        ? widget.order.orderNumber
                        : 'Adisyon',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    'Masa ${widget.order.tableLabel} · Kalan ${s.remainingPrincipal.toStringAsFixed(2)} ₺',
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'REMAINDER',
                        label: Text('Tamamı'),
                        icon: Icon(Icons.done_all_outlined),
                      ),
                      ButtonSegment(
                        value: 'FIXED_AMOUNT',
                        label: Text('Tutar'),
                        icon: Icon(Icons.payments_outlined),
                      ),
                    ],
                    selected: {_paymentMode},
                    onSelectionChanged: _submitting
                        ? null
                        : (v) => setState(() => _paymentMode = v.first),
                  ),
                  if (_paymentMode == 'FIXED_AMOUNT') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Tahsil edilecek tutar (₺)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  for (final l in s.lines)
                    if (l.remainingOnLine > 0.001)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${l.productName} × ${l.quantity}'),
                        trailing: Text(
                          '${l.remainingOnLine.toStringAsFixed(2)} ₺',
                        ),
                      ),
                  const Divider(),
                  TextField(
                    controller: _tipCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Bahşiş (₺)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'CASH',
                        label: Text('Nakit'),
                        icon: Icon(Icons.payments_outlined),
                      ),
                      ButtonSegment(
                        value: 'CARD',
                        label: Text('Kart'),
                        icon: Icon(Icons.credit_card),
                      ),
                    ],
                    selected: {_method},
                    onSelectionChanged: (v) =>
                        setState(() => _method = v.first),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: s.remainingPrincipal <= 0 || _submitting
                        ? null
                        : () => _pay(s),
                    child: _submitting
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _paymentMode == 'FIXED_AMOUNT'
                                ? 'Tutarı tahsil et'
                                : 'Kalanı tahsil et (${s.remainingPrincipal.toStringAsFixed(2)} ₺)',
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
