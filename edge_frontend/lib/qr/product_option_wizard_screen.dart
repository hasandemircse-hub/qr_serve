import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// QR müşteri akışı: her seçenek grubu bir adım, son adımda sipariş gönderimi.
class ProductOptionWizardScreen extends StatefulWidget {
  const ProductOptionWizardScreen({
    super.key,
    required this.edgeBaseUrl,
    required this.authToken,
    required this.restaurantId,
    required this.productId,
    this.tableId,
    this.quantity = 1,
  });

  final String edgeBaseUrl;
  final String authToken;
  final String restaurantId;
  final String productId;
  final String? tableId;
  final int quantity;

  @override
  State<ProductOptionWizardScreen> createState() =>
      _ProductOptionWizardScreenState();
}

class _ProductOptionWizardScreenState extends State<ProductOptionWizardScreen> {
  final PageController _pageController = PageController();

  bool _loading = true;
  String? _loadError;
  List<_WizardGroup> _groups = const [];
  final List<List<String>> _selections = [];

  int _page = 0;
  bool _submitting = false;
  String? _result;

  @override
  void initState() {
    super.initState();
    _fetchWizard();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Map<String, String> get _jsonHeaders {
    final h = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    final t = widget.authToken.trim();
    if (t.isNotEmpty) {
      h['Authorization'] = 'Bearer $t';
    }
    return h;
  }

  Future<void> _fetchWizard() async {
    final base = widget.edgeBaseUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse(
      '$base/api/v1/qr/products/${widget.productId}/option-wizard',
    );
    try {
      final res = await http.get(uri, headers: _jsonHeaders);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        setState(() {
          _loading = false;
          _loadError = 'HTTP ${res.statusCode}: ${res.body}';
        });
        return;
      }
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final rawGroups = (map['groups'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      final groups = rawGroups.map(_WizardGroup.fromJson).toList();
      setState(() {
        _groups = groups;
        _selections
          ..clear()
          ..addAll(List.generate(groups.length, (_) => <String>[]));
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _loadError = '$e';
      });
    }
  }

  bool _validateCurrentStep() {
    if (_page >= _groups.length) return true;
    final g = _groups[_page];
    final picked = _selections[_page];
    if (g.selectionType == 'SINGLE') {
      if (picked.length != 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen bir seçenek işaretleyin.')),
        );
        return false;
      }
    }
    return true;
  }

  Map<String, dynamic> _buildSelectedOptionsPayload() {
    final steps = <Map<String, dynamic>>[];
    for (var i = 0; i < _groups.length; i++) {
      final g = _groups[i];
      steps.add({
        'groupId': g.id,
        'selectionType': g.selectionType,
        'selectedOptionIds': List<String>.from(_selections[i]),
      });
    }
    return {
      'schemaVersion': 1,
      'steps': steps,
    };
  }

  Future<void> _submitOrder() async {
    setState(() {
      _submitting = true;
      _result = null;
    });
    final base = widget.edgeBaseUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/api/v1/qr/orders');
    final body = <String, dynamic>{
      'restaurantId': widget.restaurantId,
      'guestToken': null,
      'lines': [
        {
          'productId': widget.productId,
          'quantity': widget.quantity,
          'selectedOptions': _buildSelectedOptionsPayload(),
        },
      ],
    };
    if (widget.tableId != null) {
      body['tableId'] = widget.tableId;
    }
    try {
      final res = await http.post(
        uri,
        headers: _jsonHeaders,
        body: jsonEncode(body),
      );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        setState(() {
          _submitting = false;
          _result = 'Hata ${res.statusCode}: ${res.body}';
        });
        return;
      }
      final r = jsonDecode(res.body) as Map<String, dynamic>;
      setState(() {
        _submitting = false;
        _result =
            'Sipariş oluşturuldu: ${r['orderNumber']} · Toplam: ${r['grandTotal']}';
      });
    } catch (e) {
      setState(() {
        _submitting = false;
        _result = 'İstek hatası: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_loadError!, textAlign: TextAlign.center),
        ),
      );
    }
    final totalPages = _groups.isEmpty ? 1 : _groups.length + 1;
    return Column(
      children: [
        LinearProgressIndicator(
          value: totalPages == 0 ? 0 : (_page + 1) / totalPages,
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: totalPages,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, index) {
              if (_groups.isEmpty || index == _groups.length) {
                return _SummaryPage(
                  groups: _groups,
                  selections: _selections,
                  submitting: _submitting,
                  result: _result,
                  onSubmit: _submitting
                      ? null
                      : () {
                          _submitOrder();
                        },
                );
              }
              return _GroupStepPage(
                group: _groups[index],
                selectedIds: _selections[index],
                onChanged: (next) {
                  setState(() {
                    _selections[index] = next;
                  });
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (_page > 0)
                TextButton(
                  onPressed: () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    );
                  },
                  child: const Text('Geri'),
                ),
              const Spacer(),
              if (_page < totalPages - 1)
                FilledButton(
                  onPressed: () {
                    if (!_validateCurrentStep()) return;
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    );
                  },
                  child: const Text('İleri'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WizardGroup {
  _WizardGroup({
    required this.id,
    required this.name,
    required this.selectionType,
    required this.sortIndex,
    required this.options,
  });

  final String id;
  final String name;
  final String selectionType;
  final int sortIndex;
  final List<_WizardOption> options;

  factory _WizardGroup.fromJson(Map<String, dynamic> json) {
    final opts = (json['options'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(_WizardOption.fromJson)
        .toList();
    return _WizardGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      selectionType: json['selectionType'] as String,
      sortIndex: (json['sortIndex'] as num?)?.toInt() ?? 0,
      options: opts,
    );
  }
}

class _WizardOption {
  _WizardOption({
    required this.id,
    required this.label,
    required this.priceAdjustment,
  });

  final String id;
  final String label;
  final double priceAdjustment;

  factory _WizardOption.fromJson(Map<String, dynamic> json) {
    return _WizardOption(
      id: json['id'] as String,
      label: json['label'] as String,
      priceAdjustment: (json['priceAdjustment'] as num?)?.toDouble() ?? 0,
    );
  }
}

class _GroupStepPage extends StatelessWidget {
  const _GroupStepPage({
    required this.group,
    required this.selectedIds,
    required this.onChanged,
  });

  final _WizardGroup group;
  final List<String> selectedIds;
  final void Function(List<String> next) onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          group.name,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          group.selectionType == 'SINGLE'
              ? 'Tek seçim'
              : 'Birden fazla seçebilirsiniz',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const Divider(height: 32),
        if (group.selectionType == 'SINGLE')
          ...group.options.map((o) {
            final selected =
                selectedIds.isNotEmpty && selectedIds.first == o.id;
            return ListTile(
              leading: Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              title: Text(o.label),
              subtitle: o.priceAdjustment != 0
                  ? Text('+${o.priceAdjustment.toStringAsFixed(2)} ₺')
                  : null,
              onTap: () => onChanged([o.id]),
            );
          })
        else
          ...group.options.map((o) {
            final checked = selectedIds.contains(o.id);
            return CheckboxListTile(
              title: Text(o.label),
              subtitle: o.priceAdjustment != 0
                  ? Text('+${o.priceAdjustment.toStringAsFixed(2)} ₺')
                  : null,
              value: checked,
              onChanged: (v) {
                final next = List<String>.from(selectedIds);
                if (v == true) {
                  next.add(o.id);
                } else {
                  next.remove(o.id);
                }
                onChanged(next);
              },
            );
          }),
      ],
    );
  }
}

class _SummaryPage extends StatelessWidget {
  const _SummaryPage({
    required this.groups,
    required this.selections,
    required this.submitting,
    required this.result,
    required this.onSubmit,
  });

  final List<_WizardGroup> groups;
  final List<List<String>> selections;
  final bool submitting;
  final String? result;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Özet', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        for (var i = 0; i < groups.length; i++) ...[
          Text(groups[i].name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          ..._labelsForGroup(groups[i], selections[i]),
          const SizedBox(height: 12),
        ],
        if (groups.isEmpty)
          const Text('Bu ürün için tanımlı seçenek grubu yok; doğrudan sipariş verilebilir.'),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: onSubmit,
          child: submitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Siparişi gönder'),
        ),
        if (result != null) ...[
          const SizedBox(height: 16),
          Text(result!, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ],
    );
  }

  Iterable<Widget> _labelsForGroup(_WizardGroup g, List<String> ids) sync* {
    final idSet = ids.toSet();
    for (final o in g.options) {
      if (idSet.contains(o.id)) {
        yield Text('· ${o.label}');
      }
    }
    if (ids.isEmpty) {
      yield const Text('· (seçilmedi)');
    }
  }
}
