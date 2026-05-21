import 'package:flutter/material.dart';

/// Ürün seçenek grupları (SINGLE / MULTI) — misafir sepeti için.
Future<Map<String, dynamic>?> showProductOptionPickerDialog(
  BuildContext context, {
  required String productName,
  required List<Map<String, dynamic>> groups,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => ProductOptionPickerDialog(
      productName: productName,
      groups: groups,
    ),
  );
}

class ProductOptionPickerDialog extends StatefulWidget {
  const ProductOptionPickerDialog({
    super.key,
    required this.productName,
    required this.groups,
  });

  final String productName;
  final List<Map<String, dynamic>> groups;

  @override
  State<ProductOptionPickerDialog> createState() =>
      _ProductOptionPickerDialogState();
}

class _ProductOptionPickerDialogState extends State<ProductOptionPickerDialog> {
  final Map<String, List<String>> _picked = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.productName),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final g in widget.groups) ...[
                Text(g['name'] as String? ?? '',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                ..._buildGroupTiles(g),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal')),
        FilledButton(onPressed: _confirm, child: const Text('Tamam')),
      ],
    );
  }

  void _confirm() {
    for (final g in widget.groups) {
      final gid = g['id'] as String? ?? '';
      final st = (g['selectionType'] as String? ?? 'SINGLE').toUpperCase();
      final picked = _picked[gid] ?? [];
      if (st == 'SINGLE' && picked.length != 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '“${g['name'] ?? 'Seçenek'}” için bir seçim yapın.')),
        );
        return;
      }
    }
    final steps = <Map<String, dynamic>>[];
    for (final g in widget.groups) {
      final gid = g['id'] as String? ?? '';
      final st = (g['selectionType'] as String? ?? 'SINGLE').toUpperCase();
      steps.add({
        'groupId': gid,
        'selectionType': st,
        'selectedOptionIds': List<String>.from(_picked[gid] ?? []),
      });
    }
    Navigator.pop(context, {'schemaVersion': 1, 'steps': steps});
  }

  Iterable<Widget> _buildGroupTiles(Map<String, dynamic> g) {
    final gid = g['id'] as String? ?? '';
    final st = (g['selectionType'] as String? ?? 'SINGLE').toUpperCase();
    final opts =
        (g['options'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    return opts.map((o) {
      final oid = o['id'] as String? ?? '';
      final label = o['label'] as String? ?? '';
      final adj = (o['priceAdjustment'] as num?)?.toDouble() ?? 0;
      final extra = adj != 0 ? ' (+${adj.toStringAsFixed(2)} ₺)' : '';
      if (st == 'MULTI') {
        final cur = _picked[gid] ?? [];
        final checked = cur.contains(oid);
        return CheckboxListTile(
          dense: true,
          title: Text('$label$extra'),
          value: checked,
          onChanged: (v) {
            setState(() {
              final next = List<String>.from(_picked[gid] ?? []);
              if (v == true) {
                next.add(oid);
              } else {
                next.remove(oid);
              }
              _picked[gid] = next;
            });
          },
        );
      }
      return RadioListTile<String>(
        dense: true,
        title: Text('$label$extra'),
        value: oid,
        groupValue:
            (_picked[gid] ?? []).isNotEmpty ? _picked[gid]!.first : null,
        onChanged: (v) {
          setState(() {
            if (v != null) _picked[gid] = [v];
          });
        },
      );
    });
  }
}

Map<String, dynamic> emptySelectedOptionsJson() => {
      'schemaVersion': 1,
      'steps': <dynamic>[],
    };
