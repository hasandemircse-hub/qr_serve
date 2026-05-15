import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'guest_lab_api.dart';

/// Yerel test: restorandaki tüm masaları listeler; tıklanınca Flutter misafir QR akışına gider.
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
  List<GuestLabTableRow> _tables = const [];

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
      final rows = await fetchGuestLabTables(
        edgeBaseUrl: widget.edgeBaseUrl,
        restaurantId: widget.restaurantId,
      );
      if (!mounted) return;
      setState(() {
        _tables = rows;
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

  void _openTable(GuestLabTableRow row) {
    final r = Uri.encodeQueryComponent(widget.restaurantId);
    final t = Uri.encodeQueryComponent(row.qrTableId);
    final k = Uri.encodeQueryComponent(row.token);
    context.push('/guest/qr?r=$r&t=$t&k=$k');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Misafir lab (test)'),
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
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _load, child: const Text('Yeniden dene')),
                      ],
                    ),
                  ),
                )
              : _tables.isEmpty
                  ? const Center(child: Text('Masa bulunamadı.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _tables.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final row = _tables[i];
                        return Card(
                          elevation: 0,
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                row.label.isNotEmpty ? row.label.substring(0, 1) : '?',
                              ),
                            ),
                            title: Text(row.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              [
                                if (row.zone != null && row.zone!.isNotEmpty) 'Bölge: ${row.zone}',
                                if (row.seatCount != null) 'Koltuk: ${row.seatCount}',
                                'QR masa id: ${row.qrTableId}',
                              ].join(' · '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.qr_code_2),
                            onTap: () => _openTable(row),
                          ),
                        );
                      },
                    ),
    );
  }
}
