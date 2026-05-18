import 'package:flutter/material.dart';

import 'guest_lab_api.dart';
import 'guest_table_qr_sheet.dart';

/// Yerel test: masalar + telefon için QR (aynı WiFi).
class GuestLabScreen extends StatefulWidget {
  const GuestLabScreen({
    super.key,
    required this.edgeBaseUrl,
    required this.restaurantId,
  });

  final String edgeBaseUrl;
  final String restaurantId;

  @override
  State<GuestLabScreen> createState() => _GuestLabScreenState();
}

class _GuestLabScreenState extends State<GuestLabScreen> {
  bool _loading = true;
  String? _error;
  GuestLabPayload? _payload;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payload = await fetchGuestLabTables(
        edgeBaseUrl: widget.edgeBaseUrl,
        restaurantId: widget.restaurantId,
      );
      if (!mounted) return;
      setState(() {
        _payload = payload;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _showQr(GuestLabTableRow row) {
    final url = row.phoneScanUrl.isNotEmpty ? row.phoneScanUrl : row.cloudGuestUrl;
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR linki yok — Edge yeniden başlatıldı mı?')),
      );
      return;
    }
    showGuestTableQrSheet(
      context,
      tableLabel: row.label,
      phoneScanUrl: url,
      restaurantId: widget.restaurantId,
      qrTableId: row.qrTableId,
      token: row.token,
    );
  }

  @override
  Widget build(BuildContext context) {
    final payload = _payload;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Misafir lab (telefon QR)'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _load, child: const Text('Tekrar dene')),
                      ],
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (payload != null && payload.lanHost.isNotEmpty)
                      Material(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Telefon WiFi: ${payload.lanHost}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                              ),
                              if (payload.setupHint.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  payload.setupHint,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    Expanded(child: _tableList(payload?.tables ?? [])),
                  ],
                ),
    );
  }

  Widget _tableList(List<GuestLabTableRow> tables) {
    if (tables.isEmpty) {
      return const Center(child: Text('Masa bulunamadı.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: tables.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final row = tables[i];
        return Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: ListTile(
            leading: CircleAvatar(
              child: Text(row.label.isNotEmpty ? row.label.substring(0, 1) : '?'),
            ),
            title: Text(row.label, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              [
                if (row.zone != null && row.zone!.isNotEmpty) 'Bölge: ${row.zone}',
                if (row.seatCount != null) 'Koltuk: ${row.seatCount}',
                'Telefon QR için dokun',
              ].join(' · '),
            ),
            trailing: const Icon(Icons.qr_code_scanner),
            onTap: () => _showQr(row),
          ),
        );
      },
    );
  }
}
