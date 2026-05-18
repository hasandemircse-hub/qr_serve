import 'package:flutter/material.dart';

import 'edge_cashier_api.dart';

/// Ertelenen bakiyeler ve zorla / bakiye bırakarak kapanış audit kayıtları.
class ClosureBalanceReportScreen extends StatefulWidget {
  const ClosureBalanceReportScreen({
    super.key,
    required this.edgeBaseUrl,
    required this.accessToken,
  });

  final String edgeBaseUrl;
  final String? accessToken;

  @override
  State<ClosureBalanceReportScreen> createState() =>
      _ClosureBalanceReportScreenState();
}

class _ClosureBalanceReportScreenState extends State<ClosureBalanceReportScreen> {
  late Future<ClosureBalanceReportDto> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = fetchClosureBalanceReport(
        edgeBaseUrl: widget.edgeBaseUrl,
        accessToken: widget.accessToken,
      );
    });
  }

  static String _policyLabel(String policy) {
    return switch (policy) {
      'DEFER_BALANCE' => 'Bakiye bırakıldı',
      'FORCE_CLOSE_UNPAID' => 'Zorla kapatıldı',
      'STANDARD' => 'Standart',
      _ => policy,
    };
  }

  static String _dispositionLabel(String? d) {
    if (d == null || d.isEmpty) return '';
    return switch (d) {
      'VOID' => 'İptal',
      'WRITE_OFF' => 'Zayi',
      _ => d,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bakiye raporu'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<ClosureBalanceReportDto>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${snap.error}'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _reload,
                      child: const Text('Tekrar dene'),
                    ),
                  ],
                ),
              ),
            );
          }
          final r = snap.data!;
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ertelenen toplam',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${r.totalDeferredRemaining.toStringAsFixed(2)} ₺',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${r.deferredOrders.length} adisyon · '
                          '${r.exceptionClosures.length} özel kapanış kaydı',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Tahsil bekleyen (DEFERRED)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (r.deferredOrders.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Ertelenmiş açık bakiye yok.'),
                    ),
                  )
                else
                  ...r.deferredOrders.map(
                    (o) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          o.orderNumber.isNotEmpty ? o.orderNumber : o.orderId,
                        ),
                        subtitle: Text(
                          'Masa ${o.tableLabel} · ${o.remainingPrincipal.toStringAsFixed(2)} ₺',
                        ),
                        trailing: const Icon(Icons.schedule_outlined),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Text(
                  'Özel kapanışlar (audit)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (r.exceptionClosures.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Kayıt yok.'),
                    ),
                  )
                else
                  ...r.exceptionClosures.map(
                    (a) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(_policyLabel(a.policy)),
                        subtitle: Text(
                          '${a.orderNumber.isNotEmpty ? a.orderNumber : a.orderId} · '
                          'Masa ${a.tableLabel}\n'
                          'Kalan ${a.remainingPrincipal.toStringAsFixed(2)} ₺'
                          '${_dispositionLabel(a.balanceDisposition).isNotEmpty ? ' · ${_dispositionLabel(a.balanceDisposition)}' : ''}'
                          '${a.note != null && a.note!.isNotEmpty ? '\n${a.note}' : ''}',
                        ),
                        isThreeLine: true,
                        trailing: Text(
                          a.closedAt.length > 16
                              ? a.closedAt.substring(0, 16)
                              : a.closedAt,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
