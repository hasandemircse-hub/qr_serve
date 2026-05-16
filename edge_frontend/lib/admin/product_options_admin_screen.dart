import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'edge_product_options_api.dart';

/// Restoran yöneticisi: ürün seçenek grupları ve seçenekleri CRUD.
class ProductOptionsAdminScreen extends StatefulWidget {
  const ProductOptionsAdminScreen({
    super.key,
    required this.edgeBaseUrl,
    required this.authToken,
    required this.restaurantId,
    this.initialProductId,
  });

  final String edgeBaseUrl;
  final String authToken;
  final String restaurantId;
  final String? initialProductId;

  @override
  State<ProductOptionsAdminScreen> createState() => _ProductOptionsAdminScreenState();
}

class _ProductOptionsAdminScreenState extends State<ProductOptionsAdminScreen> {
  bool _loadingProducts = true;
  String? _productsError;
  AdminMenuProductsPayload? _menus;

  String? _selectedProductId;
  bool _loadingGroups = false;
  String? _groupsError;
  AdminProductOptionGroupsPayload? _groups;

  @override
  void initState() {
    super.initState();
    _selectedProductId = widget.initialProductId;
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loadingProducts = true;
      _productsError = null;
    });
    try {
      final payload = await fetchAdminMenuProducts(
        edgeBaseUrl: widget.edgeBaseUrl,
        accessToken: widget.authToken,
        restaurantId: widget.restaurantId,
      );
      if (!mounted) return;
      final products = payload.allProducts;
      setState(() {
        _menus = payload;
        _loadingProducts = false;
        if (_selectedProductId == null && products.isNotEmpty) {
          _selectedProductId = products.first.id;
        } else if (_selectedProductId != null &&
            products.every((p) => p.id != _selectedProductId)) {
          _selectedProductId = products.isEmpty ? null : products.first.id;
        }
      });
      if (_selectedProductId != null) {
        await _loadGroups();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _productsError = '$e';
        _loadingProducts = false;
      });
    }
  }

  Future<void> _loadGroups() async {
    final pid = _selectedProductId;
    if (pid == null) return;
    setState(() {
      _loadingGroups = true;
      _groupsError = null;
    });
    try {
      final payload = await fetchAdminOptionGroups(
        edgeBaseUrl: widget.edgeBaseUrl,
        accessToken: widget.authToken,
        restaurantId: widget.restaurantId,
        productId: pid,
      );
      if (!mounted) return;
      setState(() {
        _groups = payload;
        _loadingGroups = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _groupsError = '$e';
        _loadingGroups = false;
      });
    }
  }

  Future<void> _onProductChanged(String? productId) async {
    setState(() {
      _selectedProductId = productId;
      _groups = null;
    });
    if (productId != null) {
      await _loadGroups();
    }
  }

  Future<bool> _confirmDelete(String what) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sil'),
        content: Text('$what silinsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _showGroupDialog({AdminOptionGroupDto? existing}) async {
    final nameCtl = TextEditingController(text: existing?.name ?? '');
    var selectionType = existing?.selectionType ?? 'SINGLE';
    final sortCtl = TextEditingController(text: '${existing?.sortIndex ?? ''}');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Seçenek grubu ekle' : 'Grubu düzenle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtl,
                  decoration: const InputDecoration(labelText: 'Grup adı'),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectionType,
                  decoration: const InputDecoration(labelText: 'Seçim tipi'),
                  items: const [
                    DropdownMenuItem(value: 'SINGLE', child: Text('Tek seçim (SINGLE)')),
                    DropdownMenuItem(value: 'MULTI', child: Text('Çoklu seçim (MULTI)')),
                  ],
                  onChanged: (v) => setLocal(() => selectionType = v ?? 'SINGLE'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sortCtl,
                  decoration: const InputDecoration(
                    labelText: 'Sıra (boş = sona)',
                    hintText: '0, 1, 2…',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet')),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) return;

    final sortIndex = sortCtl.text.trim().isEmpty ? null : int.tryParse(sortCtl.text.trim());
    try {
      if (existing == null) {
        await createOptionGroup(
          edgeBaseUrl: widget.edgeBaseUrl,
          accessToken: widget.authToken,
          restaurantId: widget.restaurantId,
          productId: _selectedProductId!,
          name: nameCtl.text.trim(),
          selectionType: selectionType,
          sortIndex: sortIndex,
        );
      } else {
        await updateOptionGroup(
          edgeBaseUrl: widget.edgeBaseUrl,
          accessToken: widget.authToken,
          restaurantId: widget.restaurantId,
          groupId: existing.id,
          name: nameCtl.text.trim(),
          selectionType: selectionType,
          sortIndex: sortIndex,
        );
      }
      await _loadProducts();
      await _loadGroups();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Grup kaydedildi')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _showOptionDialog({
    required String groupId,
    AdminOptionItemDto? existing,
  }) async {
    final labelCtl = TextEditingController(text: existing?.label ?? '');
    final priceCtl = TextEditingController(
      text: existing != null ? existing.priceAdjustment.toStringAsFixed(2) : '0',
    );
    final sortCtl = TextEditingController(text: '${existing?.sortIndex ?? ''}');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Seçenek ekle' : 'Seçeneği düzenle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelCtl,
                decoration: const InputDecoration(labelText: 'Etiket'),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtl,
                decoration: const InputDecoration(
                  labelText: 'Fiyat farkı (₺)',
                  hintText: '0.00',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sortCtl,
                decoration: const InputDecoration(labelText: 'Sıra (boş = sona)'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet')),
        ],
      ),
    );
    if (saved != true || !mounted) return;

    final price = double.tryParse(priceCtl.text.replaceAll(',', '.')) ?? 0;
    final sortIndex = sortCtl.text.trim().isEmpty ? null : int.tryParse(sortCtl.text.trim());
    try {
      if (existing == null) {
        await createProductOption(
          edgeBaseUrl: widget.edgeBaseUrl,
          accessToken: widget.authToken,
          restaurantId: widget.restaurantId,
          groupId: groupId,
          label: labelCtl.text.trim(),
          priceAdjustment: price,
          sortIndex: sortIndex,
        );
      } else {
        await updateProductOption(
          edgeBaseUrl: widget.edgeBaseUrl,
          accessToken: widget.authToken,
          restaurantId: widget.restaurantId,
          optionId: existing.id,
          label: labelCtl.text.trim(),
          priceAdjustment: price,
          sortIndex: sortIndex,
        );
      }
      await _loadGroups();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seçenek kaydedildi')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingProducts) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_productsError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_productsError!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _loadProducts, child: const Text('Yeniden dene')),
            ],
          ),
        ),
      );
    }

    final products = _menus?.allProducts ?? [];
    if (products.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Menüde ürün yok. Önce ürün ekleyin.'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedProductId,
                  decoration: const InputDecoration(
                    labelText: 'Ürün',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final m in _menus!.menus)
                      for (final p in m.products)
                        DropdownMenuItem(
                          value: p.id,
                          child: Text('${m.name} · ${p.name} (${p.optionGroupCount} grup)'),
                        ),
                  ],
                  onChanged: _onProductChanged,
                ),
                if (_groups != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${_groups!.productName} — ${_groups!.groups.length} seçenek grubu',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
        Expanded(child: _buildGroupsList()),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: FilledButton.icon(
              onPressed: _selectedProductId == null ? null : () => _showGroupDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Seçenek grubu ekle'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupsList() {
    if (_loadingGroups) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_groupsError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_groupsError!, textAlign: TextAlign.center),
            TextButton(onPressed: _loadGroups, child: const Text('Yeniden dene')),
          ],
        ),
      );
    }
    final groups = _groups?.groups ?? [];
    if (groups.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Bu ürün için seçenek grubu yok.\n“Seçenek grubu ekle” ile Boyut, Ekstra vb. tanımlayın.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadGroups,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
        itemCount: groups.length,
        itemBuilder: (context, i) {
          final g = groups[i];
          final typeLabel = g.selectionType == 'MULTI' ? 'Çoklu' : 'Tek seçim';
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ExpansionTile(
              initiallyExpanded: true,
              title: Text(g.name),
              subtitle: Text('$typeLabel · sıra ${g.sortIndex}'),
              trailing: PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'edit') {
                    await _showGroupDialog(existing: g);
                  } else if (v == 'delete') {
                    if (!await _confirmDelete('“${g.name}” grubu ve içindeki seçenekler')) return;
                    try {
                      await deleteOptionGroup(
                        edgeBaseUrl: widget.edgeBaseUrl,
                        accessToken: widget.authToken,
                        restaurantId: widget.restaurantId,
                        groupId: g.id,
                      );
                      await _loadProducts();
                      await _loadGroups();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                      }
                    }
                  } else if (v == 'add_option') {
                    await _showOptionDialog(groupId: g.id);
                  }
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(value: 'add_option', child: Text('Seçenek ekle')),
                  PopupMenuItem(value: 'edit', child: Text('Grubu düzenle')),
                  PopupMenuItem(value: 'delete', child: Text('Grubu sil')),
                ],
              ),
              children: [
                if (g.options.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Henüz seçenek yok.'),
                  )
                else
                  for (final o in g.options)
                    ListTile(
                      dense: true,
                      title: Text(o.label),
                      subtitle: Text(
                        o.priceAdjustment == 0
                            ? 'Fiyat farkı yok'
                            : '+${o.priceAdjustment.toStringAsFixed(2)} ₺',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed: () => _showOptionDialog(groupId: g.id, existing: o),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () async {
                              if (!await _confirmDelete('“${o.label}”')) return;
                              try {
                                await deleteProductOption(
                                  edgeBaseUrl: widget.edgeBaseUrl,
                                  accessToken: widget.authToken,
                                  restaurantId: widget.restaurantId,
                                  optionId: o.id,
                                );
                                await _loadGroups();
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(
                                    context,
                                  ).showSnackBar(SnackBar(content: Text('$e')));
                                }
                              }
                            },
                          ),
                        ],
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
