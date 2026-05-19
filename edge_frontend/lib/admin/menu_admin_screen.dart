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
  AdminMenuTreePayload? _tree;
  List<AdminMenuDetailDto> _localMenus = [];
  Object? _loadError;
  bool _loading = true;
  String? _selectedMenuId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<AdminMenuTreePayload> _load() {
    return fetchAdminMenuTree(
      edgeBaseUrl: widget.edgeBaseUrl,
      accessToken: widget.accessToken,
      restaurantId: widget.restaurantId,
    );
  }

  void _applyTree(AdminMenuTreePayload tree) {
    final menus = List<AdminMenuDetailDto>.from(tree.menus)
      ..sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
    _tree = tree;
    _localMenus = menus;
    if (_selectedMenuId != null &&
        menus.every((m) => m.id != _selectedMenuId)) {
      _selectedMenuId = menus.isEmpty ? null : menus.first.id;
    } else if (_selectedMenuId == null && menus.isNotEmpty) {
      _selectedMenuId = menus.first.id;
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final tree = await _load();
      if (!mounted) return;
      setState(() {
        _applyTree(tree);
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

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  AdminMenuDetailDto? get _selectedMenu {
    final id = _selectedMenuId;
    if (id == null) return null;
    for (final m in _localMenus) {
      if (m.id == id) return m;
    }
    return null;
  }

  Future<void> _persistMenuOrder() async {
    if (_localMenus.length < 2) return;
    try {
      await reorderMenus(
        edgeBaseUrl: widget.edgeBaseUrl,
        accessToken: widget.accessToken,
        restaurantId: widget.restaurantId,
        orderedIds: _localMenus.map((m) => m.id).toList(),
      );
    } catch (e) {
      _toast('$e');
      await _refresh();
    }
  }

  Future<void> _onReorderMenu(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    setState(() {
      final item = _localMenus.removeAt(oldIndex);
      _localMenus.insert(newIndex, item);
    });
    await _persistMenuOrder();
  }

  Future<void> _onReorderProduct(int oldIndex, int newIndex) async {
    final menu = _selectedMenu;
    if (menu == null || menu.products.length < 2) return;
    if (newIndex > oldIndex) newIndex -= 1;
    final products = List<AdminProductDetailDto>.from(menu.products);
    final item = products.removeAt(oldIndex);
    products.insert(newIndex, item);
    final menuIdx = _localMenus.indexWhere((m) => m.id == menu.id);
    if (menuIdx < 0) return;
    setState(() {
      _localMenus[menuIdx] = menu.copyWith(products: products);
    });
    try {
      await reorderProducts(
        edgeBaseUrl: widget.edgeBaseUrl,
        accessToken: widget.accessToken,
        restaurantId: widget.restaurantId,
        menuId: menu.id,
        orderedIds: products.map((p) => p.id).toList(),
      );
    } catch (e) {
      _toast('$e');
      await _refresh();
    }
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

  void _updateLocalProduct(AdminProductDetailDto updated) {
    final menuIdx = _localMenus.indexWhere(
      (m) => m.products.any((p) => p.id == updated.id),
    );
    if (menuIdx < 0) return;
    final menu = _localMenus[menuIdx];
    final products = menu.products
        .map((p) => p.id == updated.id ? updated : p)
        .toList();
    setState(() {
      _localMenus[menuIdx] = menu.copyWith(products: products);
    });
  }

  Future<void> _pickAndUploadImage(AdminProductDetailDto product) async {
    if (_busy) return;
    final file = await pickProductImageFile();
    if (file == null || file.bytes == null) return;
    setState(() => _busy = true);
    try {
      final updated = await uploadProductImage(
        edgeBaseUrl: widget.edgeBaseUrl,
        accessToken: widget.accessToken,
        restaurantId: widget.restaurantId,
        productId: product.id,
        bytes: file.bytes!,
        filename: file.name,
      );
      if (!mounted) return;
      _updateLocalProduct(updated);
      _toast('Ürün resmi yüklendi');
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeProductImage(AdminProductDetailDto product) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await deleteProductImage(
        edgeBaseUrl: widget.edgeBaseUrl,
        accessToken: widget.accessToken,
        restaurantId: widget.restaurantId,
        productId: product.id,
      );
      if (!mounted) return;
      _updateLocalProduct(product.copyWith(imageUrl: null));
      _toast('Ürün resmi kaldırıldı');
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
    if (_loading && _tree == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Menü yüklenemedi: $_loadError'),
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

    final menu = _selectedMenu;
    final allMenus = _tree?.menus ?? _localMenus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Menüler',
                  style: Theme.of(context).textTheme.titleMedium,
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
        if (_localMenus.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Henüz menü yok — ilk menüyü oluşturun.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Sürükleyerek menü sırasını değiştirin; dokunarak seçin.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          SizedBox(
            height: (_localMenus.length * 52.0).clamp(52, 180),
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              buildDefaultDragHandles: false,
              itemCount: _localMenus.length,
              onReorder: _busy ? (_, __) {} : _onReorderMenu,
              itemBuilder: (ctx, i) {
                final m = _localMenus[i];
                final selected = m.id == _selectedMenuId;
                return Material(
                  key: ValueKey(m.id),
                  color: selected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  child: ListTile(
                    dense: true,
                    leading: ReorderableDragStartListener(
                      index: i,
                      child: const Icon(Icons.drag_handle),
                    ),
                    title: Text(m.active ? m.name : '${m.name} (pasif)'),
                    subtitle: Text('${m.products.length} ürün'),
                    selected: selected,
                    onTap: _busy
                        ? null
                        : () => setState(() => _selectedMenuId = m.id),
                  ),
                );
              },
            ),
          ),
        ],
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
        if (menu != null && menu.products.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Ürünler — sürükleyerek sıralayın',
              style: Theme.of(context).textTheme.titleSmall,
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
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.all(16),
                          buildDefaultDragHandles: false,
                          itemCount: menu.products.length,
                          onReorder: _busy ? (_, __) {} : _onReorderProduct,
                          itemBuilder: (ctx, i) {
                            final p = menu.products[i];
                            return Card(
                              key: ValueKey(p.id),
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ReorderableDragStartListener(
                                      index: i,
                                      child: const Icon(Icons.drag_handle),
                                    ),
                                    const SizedBox(width: 4),
                                    _ProductThumb(imageUrl: p.imageUrl),
                                  ],
                                ),
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
                                          allMenus: allMenus,
                                        );
                                      case 'image':
                                        _pickAndUploadImage(p);
                                      case 'remove_image':
                                        _removeProductImage(p);
                                      case 'options':
                                        _openProductOptions(p.id);
                                      case 'delete':
                                        _deleteProduct(p);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Düzenle'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'image',
                                      child: Text('Resim yükle'),
                                    ),
                                    if (p.imageUrl != null &&
                                        p.imageUrl!.isNotEmpty)
                                      const PopupMenuItem(
                                        value: 'remove_image',
                                        child: Text('Resmi kaldır'),
                                      ),
                                    const PopupMenuItem(
                                      value: 'options',
                                      child: Text('Seçenekler'),
                                    ),
                                    const PopupMenuItem(
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
                        allMenus: allMenus,
                      ),
                icon: const Icon(Icons.add),
                label: const Text('Ürün ekle'),
              ),
            ),
          ),
      ],
    );
  }
}

class _ProductThumb extends StatelessWidget {
  const _ProductThumb({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const _PlaceholderThumb(),
        ),
      );
    }
    return const _PlaceholderThumb();
  }
}

class _PlaceholderThumb extends StatelessWidget {
  const _PlaceholderThumb();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.fastfood_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
