import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'edge_menu_admin_api.dart';
import 'product_options_admin_screen.dart';

/// Restoran yöneticisi: menü ve ürün CRUD.
class MenuAdminScreen extends StatefulWidget {
  const MenuAdminScreen({
    super.key,
    required this.edgeBaseUrl,
    required this.accessToken,
    required this.restaurantId,
  });

  final String edgeBaseUrl;
  final String? accessToken;
  final String restaurantId;

  @override
  State<MenuAdminScreen> createState() => _MenuAdminScreenState();
}

class _MenuAdminScreenState extends State<MenuAdminScreen> {
  late Future<AdminMenuTreePayload> _future;
  String? _selectedMenuId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<AdminMenuTreePayload> _load() {
    return fetchAdminMenuTree(
      edgeBaseUrl: widget.edgeBaseUrl,
      accessToken: widget.accessToken,
      restaurantId: widget.restaurantId,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    final tree = await _future;
    if (!mounted) return;
    if (_selectedMenuId != null &&
        tree.menus.every((m) => m.id != _selectedMenuId)) {
      setState(() {
        _selectedMenuId = tree.menus.isEmpty ? null : tree.menus.first.id;
      });
    } else if (_selectedMenuId == null && tree.menus.isNotEmpty) {
      setState(() => _selectedMenuId = tree.menus.first.id);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  AdminMenuDetailDto? _menu(AdminMenuTreePayload tree) {
    final id = _selectedMenuId;
    if (id == null) return null;
    for (final m in tree.menus) {
      if (m.id == id) return m;
    }
    return null;
  }

  Future<bool> _confirmDelete(String label) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sil'),
        content: Text('$label silinsin mi? Ürün seçenekleri de kaldırılır.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _openMenuDialog({AdminMenuDetailDto? existing}) async {
    if (_busy) return;
    final nameCtl = TextEditingController(text: existing?.name ?? '');
    final descCtl = TextEditingController(text: existing?.description ?? '');
    var active = existing?.active ?? true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Menü ekle' : 'Menüyü düzenle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Menü adı',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtl,
                  decoration: const InputDecoration(
                    labelText: 'Açıklama (isteğe bağlı)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Misafir/garson menüsünde göster'),
                  value: active,
                  onChanged: (v) => setLocal(() => active = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || nameCtl.text.trim().isEmpty) return;

    setState(() => _busy = true);
    try {
      if (existing == null) {
        await createMenu(
          edgeBaseUrl: widget.edgeBaseUrl,
          accessToken: widget.accessToken,
          restaurantId: widget.restaurantId,
          name: nameCtl.text.trim(),
          description: descCtl.text.trim(),
          active: active,
        );
      } else {
        await updateMenu(
          edgeBaseUrl: widget.edgeBaseUrl,
          accessToken: widget.accessToken,
          restaurantId: widget.restaurantId,
          menuId: existing.id,
          name: nameCtl.text.trim(),
          description: descCtl.text.trim(),
          active: active,
        );
      }
      await _refresh();
      _toast('Menü kaydedildi');
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openProductDialog({
    required String menuId,
    required List<AdminMenuDetailDto> allMenus,
    AdminProductDetailDto? existing,
  }) async {
    if (_busy) return;
    final nameCtl = TextEditingController(text: existing?.name ?? '');
    final descCtl = TextEditingController(text: existing?.description ?? '');
    final priceCtl = TextEditingController(
      text: existing != null ? existing.price.toStringAsFixed(2) : '',
    );
    final skuCtl = TextEditingController(text: existing?.sku ?? '');
    final taxCtl = TextEditingController(
      text: existing?.taxRate != null ? existing!.taxRate.toString() : '',
    );
    var targetMenuId = existing != null ? menuId : menuId;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Ürün ekle' : 'Ürünü düzenle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (allMenus.length > 1)
                  DropdownButtonFormField<String>(
                    initialValue: targetMenuId,
                    decoration: const InputDecoration(
                      labelText: 'Menü',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final m in allMenus)
                        DropdownMenuItem(value: m.id, child: Text(m.name)),
                    ],
                    onChanged: (v) {
                      if (v != null) setLocal(() => targetMenuId = v);
                    },
                  ),
                if (allMenus.length > 1) const SizedBox(height: 12),
                TextField(
                  controller: nameCtl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Ürün adı',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Fiyat (₺)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtl,
                  decoration: const InputDecoration(
                    labelText: 'Açıklama',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: skuCtl,
                  decoration: const InputDecoration(
                    labelText: 'SKU (isteğe bağlı)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: taxCtl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'KDV oranı (0–1, örn. 0.10)',
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
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || nameCtl.text.trim().isEmpty) return;

    final price = double.tryParse(priceCtl.text.replaceAll(',', '.'));
    if (price == null || price < 0) {
      _toast('Geçerli bir fiyat girin');
      return;
    }
    final taxRaw = taxCtl.text.trim();
    double? taxRate;
    if (taxRaw.isNotEmpty) {
      taxRate = double.tryParse(taxRaw.replaceAll(',', '.'));
      if (taxRate == null || taxRate < 0 || taxRate > 1) {
        _toast('KDV oranı 0 ile 1 arasında olmalı');
        return;
      }
    }

    setState(() => _busy = true);
    try {
      if (existing == null) {
        await createProduct(
          edgeBaseUrl: widget.edgeBaseUrl,
          accessToken: widget.accessToken,
          restaurantId: widget.restaurantId,
          menuId: targetMenuId,
          name: nameCtl.text.trim(),
          description: descCtl.text.trim(),
          price: price,
          sku: skuCtl.text.trim(),
          taxRate: taxRate,
        );
      } else {
        await updateProduct(
          edgeBaseUrl: widget.edgeBaseUrl,
          accessToken: widget.accessToken,
          restaurantId: widget.restaurantId,
          productId: existing.id,
          name: nameCtl.text.trim(),
          description: descCtl.text.trim(),
          price: price,
          sku: skuCtl.text.trim(),
          taxRate: taxRate,
          menuId: targetMenuId != menuId ? targetMenuId : null,
        );
      }
      await _refresh();
      _toast('Ürün kaydedildi');
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteMenu(AdminMenuDetailDto menu) async {
    if (_busy || !await _confirmDelete('“${menu.name}” menüsü')) return;
    setState(() => _busy = true);
    try {
      await deleteMenu(
        edgeBaseUrl: widget.edgeBaseUrl,
        accessToken: widget.accessToken,
        restaurantId: widget.restaurantId,
        menuId: menu.id,
      );
      await _refresh();
      _toast('Menü silindi');
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteProduct(AdminProductDetailDto product) async {
    if (_busy || !await _confirmDelete('“${product.name}” ürünü')) return;
    setState(() => _busy = true);
    try {
      await deleteProduct(
        edgeBaseUrl: widget.edgeBaseUrl,
        accessToken: widget.accessToken,
        restaurantId: widget.restaurantId,
        productId: product.id,
      );
      await _refresh();
      _toast('Ürün silindi');
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openProductOptions(String productId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductOptionsAdminScreen(
          edgeBaseUrl: widget.edgeBaseUrl,
          authToken: widget.accessToken ?? '',
          restaurantId: widget.restaurantId,
          initialProductId: productId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminMenuTreePayload>(
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
                  Text('Menü yüklenemedi: ${snap.error}'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _refresh,
                    child: const Text('Yeniden dene'),
                  ),
                ],
              ),
            ),
          );
        }
        final tree = snap.data!;
        if (_selectedMenuId == null && tree.menus.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedMenuId = tree.menus.first.id);
          });
        }
        final menu = _menu(tree);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: tree.menus.isEmpty
                        ? Text(
                            'Henüz menü yok',
                            style: Theme.of(context).textTheme.titleMedium,
                          )
                        : DropdownButtonFormField<String>(
                            initialValue: _selectedMenuId,
                            decoration: const InputDecoration(
                              labelText: 'Menü',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: [
                              for (final m in tree.menus)
                                DropdownMenuItem(
                                  value: m.id,
                                  child: Text(
                                    m.active ? m.name : '${m.name} (pasif)',
                                  ),
                                ),
                            ],
                            onChanged: _busy
                                ? null
                                : (v) => setState(() => _selectedMenuId = v),
                          ),
                  ),
                  IconButton(
                    tooltip: 'Menü ekle',
                    onPressed: _busy ? null : () => _openMenuDialog(),
                    icon: const Icon(Icons.add_box_outlined),
                  ),
                  if (menu != null)
                    IconButton(
                      tooltip: 'Menüyü düzenle',
                      onPressed: _busy ? null : () => _openMenuDialog(existing: menu),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  if (menu != null)
                    IconButton(
                      tooltip: 'Menüyü sil',
                      onPressed: _busy ? null : () => _deleteMenu(menu),
                      icon: const Icon(Icons.delete_outline),
                    ),
                ],
              ),
            ),
            if (menu != null && !menu.active)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  'Bu menü pasif — misafir ve garson menüsünde görünmez.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            Expanded(
              child: menu == null
                  ? Center(
                      child: FilledButton.icon(
                        onPressed: _busy ? null : () => _openMenuDialog(),
                        icon: const Icon(Icons.restaurant_menu),
                        label: const Text('İlk menüyü oluştur'),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: menu.products.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: const [
                                SizedBox(height: 48),
                                Center(child: Text('Bu menüde ürün yok')),
                              ],
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(16),
                              itemCount: menu.products.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (ctx, i) {
                                final p = menu.products[i];
                                return Card(
                                  child: ListTile(
                                    title: Text(p.name),
                                    subtitle: Text(
                                      '${p.price.toStringAsFixed(2)} ₺'
                                      '${p.description != null && p.description!.isNotEmpty ? ' · ${p.description}' : ''}',
                                    ),
                                    isThreeLine: p.description != null &&
                                        p.description!.length > 40,
                                    trailing: PopupMenuButton<String>(
                                      onSelected: (action) {
                                        switch (action) {
                                          case 'edit':
                                            _openProductDialog(
                                              menuId: menu.id,
                                              existing: p,
                                              allMenus: tree.menus,
                                            );
                                          case 'options':
                                            _openProductOptions(p.id);
                                          case 'delete':
                                            _deleteProduct(p);
                                        }
                                      },
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Text('Düzenle'),
                                        ),
                                        PopupMenuItem(
                                          value: 'options',
                                          child: Text('Seçenekler'),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Sil'),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
            ),
            if (menu != null)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _openProductDialog(
                            menuId: menu.id,
                            allMenus: tree.menus,
                          ),
                    icon: const Icon(Icons.add),
                    label: const Text('Ürün ekle'),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
