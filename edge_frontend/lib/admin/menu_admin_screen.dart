import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'edge_menu_admin_api.dart';
import 'edge_product_options_api.dart';

/// Restoran yöneticisi: menü, ürün ve seçenek gruplarını tek ekrandan yönetir.
///
/// Mimari:
/// - **Sol sidebar (koyu)**: menü/kategori listesi, drag-drop sıralama, aktif vurgulu.
/// - **Orta panel (light)**: seçili menünün ürünleri, satır bazlı liste (drag, thumb, ad, fiyat).
/// - **Sağ slide-panel**: ürün form (ad, fiyat, açıklama, SKU, KDV, durum, menü taşıma, resim) +
///   alt kısımda seçenek grupları (SINGLE/MULTI tipi + seçenek satırları).
///
/// Responsive davranış [AppBreakpoints.wide] (>=900px) için sidebar inline + slide-panel overlay;
/// dar ekranda sidebar Drawer'a, slide-panel full-screen route'a dönüşür.
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
  // Menü/ürün state
  AdminMenuTreePayload? _tree;
  List<AdminMenuDetailDto> _localMenus = [];
  Object? _loadError;
  bool _loading = true;
  String? _selectedMenuId;
  bool _busy = false;

  // Slide panel (ürün editör) state
  String? _editingProductId;
  bool _panelOpen = false;

  // Editör içindeki seçenek grupları — lazy load
  List<AdminOptionGroupDto> _editorGroups = [];
  bool _loadingGroups = false;

  // Yan menü açma için
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  // ---------- Veri yükleme ----------

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final tree = await fetchAdminMenuTree(
        edgeBaseUrl: widget.edgeBaseUrl,
        accessToken: widget.accessToken,
        restaurantId: widget.restaurantId,
      );
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

  AdminMenuDetailDto? get _selectedMenu {
    final id = _selectedMenuId;
    if (id == null) return null;
    for (final m in _localMenus) {
      if (m.id == id) return m;
    }
    return null;
  }

  AdminProductDetailDto? get _editingProduct {
    final pid = _editingProductId;
    if (pid == null) return null;
    for (final m in _localMenus) {
      for (final p in m.products) {
        if (p.id == pid) return p;
      }
    }
    return null;
  }

  String? _menuIdOfProduct(String productId) {
    for (final m in _localMenus) {
      for (final p in m.products) {
        if (p.id == productId) return m.id;
      }
    }
    return null;
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

  Future<bool> _confirmDelete(String label) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sil'),
        content: Text('$label silinsin mi? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppPalette.of(context).danger,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  // ---------- Menü CRUD ----------

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

  Future<void> _openMenuDialog({AdminMenuDetailDto? existing}) async {
    if (_busy) return;
    final nameCtl = TextEditingController(text: existing?.name ?? '');
    final descCtl = TextEditingController(text: existing?.description ?? '');
    var active = existing?.active ?? true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Kategori ekle' : 'Kategoriyi düzenle'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameCtl,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Kategori adı'),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtl,
                    decoration: const InputDecoration(
                      labelText: 'Açıklama (isteğe bağlı)',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Misafir / garson menüsünde göster'),
                    value: active,
                    onChanged: (v) => setLocal(() => active = v),
                  ),
                ],
              ),
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
      _toast('Kategori kaydedildi');
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteMenu(AdminMenuDetailDto menu) async {
    if (_busy || !await _confirmDelete('"${menu.name}" kategorisi ve ürünleri')) {
      return;
    }
    setState(() => _busy = true);
    try {
      await deleteMenu(
        edgeBaseUrl: widget.edgeBaseUrl,
        accessToken: widget.accessToken,
        restaurantId: widget.restaurantId,
        menuId: menu.id,
      );
      await _refresh();
      _toast('Kategori silindi');
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------- Ürün CRUD ----------

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

  Future<void> _deleteProduct(AdminProductDetailDto product) async {
    if (_busy || !await _confirmDelete('"${product.name}" ürünü')) return;
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

  // ---------- Editör (slide panel) açma / kapatma ----------

  Future<void> _openEditorForExisting(AdminProductDetailDto product) async {
    setState(() {
      _editingProductId = product.id;
      _panelOpen = true;
      _editorGroups = [];
    });
    await _loadEditorGroups(product.id);
  }

  Future<void> _openEditorForNew() async {
    final menu = _selectedMenu;
    if (menu == null) {
      _toast('Önce bir kategori oluşturun');
      return;
    }
    final created = await _createDraftProduct(menu.id);
    if (created == null) return;
    await _openEditorForExisting(created);
  }

  /// HTML mockup'ı "Yeni Ürün Ekle" → direkt editör paneli açar.
  /// API katmanı önce minimal ürün oluşturur (boş isim, 0 fiyat); kullanıcı kaydedince güncellenir.
  /// Yarım kalırsa kullanıcı manuel silebilir; ileride bir cleanup gerekebilir.
  Future<AdminProductDetailDto?> _createDraftProduct(String menuId) async {
    setState(() => _busy = true);
    try {
      final created = await createProduct(
        edgeBaseUrl: widget.edgeBaseUrl,
        accessToken: widget.accessToken,
        restaurantId: widget.restaurantId,
        menuId: menuId,
        name: 'Yeni ürün',
        price: 0,
      );
      await _refresh();
      return created;
    } catch (e) {
      _toast('$e');
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _closeEditor() {
    setState(() {
      _panelOpen = false;
      _editingProductId = null;
      _editorGroups = [];
    });
  }

  Future<void> _loadEditorGroups(String productId) async {
    setState(() {
      _loadingGroups = true;
      _editorGroups = [];
    });
    try {
      final payload = await fetchAdminOptionGroups(
        edgeBaseUrl: widget.edgeBaseUrl,
        accessToken: widget.accessToken,
        restaurantId: widget.restaurantId,
        productId: productId,
      );
      if (!mounted) return;
      setState(() {
        _editorGroups = List<AdminOptionGroupDto>.from(payload.groups)
          ..sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
        _loadingGroups = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingGroups = false;
      });
      _toast('$e');
    }
  }

  Future<void> _saveProductFromEditor({
    required String productId,
    required String name,
    required String description,
    required double price,
    required String sku,
    required double? taxRate,
    required String? newMenuId,
  }) async {
    setState(() => _busy = true);
    try {
      final currentMenuId = _menuIdOfProduct(productId);
      await updateProduct(
        edgeBaseUrl: widget.edgeBaseUrl,
        accessToken: widget.accessToken,
        restaurantId: widget.restaurantId,
        productId: productId,
        name: name,
        description: description,
        price: price,
        sku: sku,
        taxRate: taxRate,
        menuId: (newMenuId != null && newMenuId != currentMenuId)
            ? newMenuId
            : null,
      );
      await _refresh();
      _toast('Ürün kaydedildi');
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------- Seçenek grubu / seçenek CRUD ----------

  Future<void> _addOptionGroup({
    required String name,
    required String selectionType,
  }) async {
    final pid = _editingProductId;
    if (pid == null) return;
    try {
      await createOptionGroup(
        edgeBaseUrl: widget.edgeBaseUrl,
        accessToken: widget.accessToken,
        restaurantId: widget.restaurantId,
        productId: pid,
        name: name,
        selectionType: selectionType,
      );
      await _loadEditorGroups(pid);
    } catch (e) {
      _toast('$e');
    }
  }

  Future<void> _updateGroup({
    required AdminOptionGroupDto group,
    required String name,
    required String selectionType,
  }) async {
    try {
      await updateOptionGroup(
        edgeBaseUrl: widget.edgeBaseUrl,
        accessToken: widget.accessToken,
        restaurantId: widget.restaurantId,
        groupId: group.id,
        name: name,
        selectionType: selectionType,
        sortIndex: group.sortIndex,
      );
      final pid = _editingProductId;
      if (pid != null) await _loadEditorGroups(pid);
    } catch (e) {
      _toast('$e');
    }
  }

  Future<void> _removeGroup(AdminOptionGroupDto group) async {
    if (!await _confirmDelete('"${group.name}" grubu ve içindeki seçenekler')) {
      return;
    }
    try {
      await deleteOptionGroup(
        edgeBaseUrl: widget.edgeBaseUrl,
        accessToken: widget.accessToken,
        restaurantId: widget.restaurantId,
        groupId: group.id,
      );
      final pid = _editingProductId;
      if (pid != null) await _loadEditorGroups(pid);
    } catch (e) {
      _toast('$e');
    }
  }

  Future<void> _onReorderEditorGroup(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    setState(() {
      final item = _editorGroups.removeAt(oldIndex);
      _editorGroups.insert(newIndex, item);
    });
    final pid = _editingProductId;
    if (pid == null || _editorGroups.length < 2) return;
    try {
      await reorderOptionGroups(
        edgeBaseUrl: widget.edgeBaseUrl,
        accessToken: widget.accessToken,
        restaurantId: widget.restaurantId,
        productId: pid,
        orderedIds: _editorGroups.map((g) => g.id).toList(),
      );
    } catch (e) {
      _toast('$e');
      await _loadEditorGroups(pid);
    }
  }

  Future<void> _addOption({
    required String groupId,
    required String label,
    required double priceAdjustment,
  }) async {
    try {
      await createProductOption(
        edgeBaseUrl: widget.edgeBaseUrl,
        accessToken: widget.accessToken,
        restaurantId: widget.restaurantId,
        groupId: groupId,
        label: label,
        priceAdjustment: priceAdjustment,
      );
      final pid = _editingProductId;
      if (pid != null) await _loadEditorGroups(pid);
    } catch (e) {
      _toast('$e');
    }
  }

  Future<void> _updateOption({
    required AdminOptionItemDto option,
    required String label,
    required double priceAdjustment,
  }) async {
    try {
      await updateProductOption(
        edgeBaseUrl: widget.edgeBaseUrl,
        accessToken: widget.accessToken,
        restaurantId: widget.restaurantId,
        optionId: option.id,
        label: label,
        priceAdjustment: priceAdjustment,
        sortIndex: option.sortIndex,
      );
      final pid = _editingProductId;
      if (pid != null) await _loadEditorGroups(pid);
    } catch (e) {
      _toast('$e');
    }
  }

  Future<void> _removeOption({
    required String groupId,
    required AdminOptionItemDto option,
  }) async {
    if (!await _confirmDelete('"${option.label}" seçeneği')) return;
    try {
      await deleteProductOption(
        edgeBaseUrl: widget.edgeBaseUrl,
        accessToken: widget.accessToken,
        restaurantId: widget.restaurantId,
        optionId: option.id,
      );
      final pid = _editingProductId;
      if (pid != null) await _loadEditorGroups(pid);
    } catch (e) {
      _toast('$e');
    }
  }

  Future<void> _onReorderOption(
    String groupId,
    int oldIndex,
    int newIndex,
  ) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final gi = _editorGroups.indexWhere((g) => g.id == groupId);
    if (gi < 0) return;
    final group = _editorGroups[gi];
    if (group.options.length < 2) return;
    final options = List<AdminOptionItemDto>.from(group.options);
    final item = options.removeAt(oldIndex);
    options.insert(newIndex, item);
    setState(() {
      _editorGroups[gi] = group.copyWith(options: options);
    });
    try {
      await reorderOptions(
        edgeBaseUrl: widget.edgeBaseUrl,
        accessToken: widget.accessToken,
        restaurantId: widget.restaurantId,
        groupId: groupId,
        orderedIds: options.map((o) => o.id).toList(),
      );
    } catch (e) {
      _toast('$e');
      final pid = _editingProductId;
      if (pid != null) await _loadEditorGroups(pid);
    }
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    if (_loading && _tree == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return _ErrorState(error: '$_loadError', onRetry: _refresh);
    }

    final isWide = AppBreakpoints.isWide(context);
    return isWide ? _buildWide(context) : _buildNarrow(context);
  }

  /// Geniş ekran (>=900px): Row(sidebar, main) + Stack overlay slide-panel.
  Widget _buildWide(BuildContext context) {
    final palette = AppPalette.of(context);
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Stack(
        children: [
          Row(
            children: [
              _MenuSidebar(
                menus: _localMenus,
                selectedMenuId: _selectedMenuId,
                busy: _busy,
                onSelect: (id) => setState(() => _selectedMenuId = id),
                onAdd: () => _openMenuDialog(),
                onEdit: (m) => _openMenuDialog(existing: m),
                onDelete: _deleteMenu,
                onReorder: _onReorderMenu,
              ),
              Expanded(
                child: _ProductsPanel(
                  menu: _selectedMenu,
                  busy: _busy,
                  onAdd: _openEditorForNew,
                  onEditProduct: _openEditorForExisting,
                  onDeleteProduct: _deleteProduct,
                  onReorderProduct: _onReorderProduct,
                  onPickImage: _pickAndUploadImage,
                  onCreateFirstMenu: () => _openMenuDialog(),
                ),
              ),
            ],
          ),
          // Overlay
          if (_panelOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeEditor,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  color: Colors.black.withValues(alpha: 0.4),
                ),
              ),
            ),
          // Slide panel
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            top: 0,
            bottom: 0,
            right: _panelOpen ? 0 : -560,
            width: 540,
            child: Material(
              color: Colors.white,
              elevation: 16,
              shadowColor: Colors.black.withValues(alpha: 0.25),
              child: _editingProduct == null
                  ? const SizedBox.shrink()
                  : _ProductEditorPanel(
                      key: ValueKey(_editingProductId),
                      product: _editingProduct!,
                      allMenus: _localMenus,
                      currentMenuId: _menuIdOfProduct(_editingProductId!) ?? '',
                      busy: _busy,
                      loadingGroups: _loadingGroups,
                      groups: _editorGroups,
                      palette: palette,
                      onClose: _closeEditor,
                      onSave: _saveProductFromEditor,
                      onPickImage: () => _pickAndUploadImage(_editingProduct!),
                      onRemoveImage: () =>
                          _removeProductImage(_editingProduct!),
                      onAddGroup: _addOptionGroup,
                      onUpdateGroup: _updateGroup,
                      onRemoveGroup: _removeGroup,
                      onReorderGroup: _onReorderEditorGroup,
                      onAddOption: _addOption,
                      onUpdateOption: _updateOption,
                      onRemoveOption: _removeOption,
                      onReorderOption: _onReorderOption,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Dar ekran: Scaffold(drawer: sidebar, body: main); slide-panel → full-screen route.
  Widget _buildNarrow(BuildContext context) {
    final palette = AppPalette.of(context);

    // Slide panel açıldığında full-screen route push et — bu deyimle dar ekranda
    // klavye + form alanları için en konforlu hâl. State değiştiğinde push tetiklemek
    // için post-frame yapıyoruz.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_panelOpen && _editingProduct != null && mounted) {
        final navigator = Navigator.of(context);
        // Çift push'tan kaçınmak için içeride flag tutmuyoruz; bunun yerine
        // route'u dispatch ederken panelOpen'i hemen false yapıyoruz:
        final product = _editingProduct!;
        final currentMenuId = _menuIdOfProduct(_editingProductId!) ?? '';
        setState(() => _panelOpen = false);
        navigator
            .push<void>(
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(
                    title: const Text('Ürünü Düzenle'),
                    leading: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  body: _ProductEditorPanel(
                    product: product,
                    allMenus: _localMenus,
                    currentMenuId: currentMenuId,
                    busy: _busy,
                    loadingGroups: _loadingGroups,
                    groups: _editorGroups,
                    palette: palette,
                    embedded: true,
                    onClose: () => Navigator.of(context).pop(),
                    onSave: _saveProductFromEditor,
                    onPickImage: () => _pickAndUploadImage(product),
                    onRemoveImage: () => _removeProductImage(product),
                    onAddGroup: _addOptionGroup,
                    onUpdateGroup: _updateGroup,
                    onRemoveGroup: _removeGroup,
                    onReorderGroup: _onReorderEditorGroup,
                    onAddOption: _addOption,
                    onUpdateOption: _updateOption,
                    onRemoveOption: _removeOption,
                    onReorderOption: _onReorderOption,
                  ),
                ),
              ),
            )
            .whenComplete(() {
              if (mounted) {
                setState(() {
                  _editingProductId = null;
                  _editorGroups = [];
                });
              }
            });
      }
    });

    return Scaffold(
      key: _scaffoldKey,
      drawer: SizedBox(
        width: 280,
        child: _MenuSidebar(
          menus: _localMenus,
          selectedMenuId: _selectedMenuId,
          busy: _busy,
          onSelect: (id) {
            setState(() => _selectedMenuId = id);
            Navigator.of(context).pop();
          },
          onAdd: () {
            Navigator.of(context).pop();
            _openMenuDialog();
          },
          onEdit: (m) {
            Navigator.of(context).pop();
            _openMenuDialog(existing: m);
          },
          onDelete: (m) {
            Navigator.of(context).pop();
            _deleteMenu(m);
          },
          onReorder: _onReorderMenu,
        ),
      ),
      appBar: AppBar(
        title: const Text('Menü Yönetimi'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      body: _ProductsPanel(
        menu: _selectedMenu,
        busy: _busy,
        onAdd: _openEditorForNew,
        onEditProduct: _openEditorForExisting,
        onDeleteProduct: _deleteProduct,
        onReorderProduct: _onReorderProduct,
        onPickImage: _pickAndUploadImage,
        onCreateFirstMenu: () => _openMenuDialog(),
      ),
    );
  }
}

// ============================================================================
// SIDEBAR (koyu, sol — kategori listesi)
// ============================================================================

class _MenuSidebar extends StatelessWidget {
  const _MenuSidebar({
    required this.menus,
    required this.selectedMenuId,
    required this.busy,
    required this.onSelect,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onReorder,
  });

  final List<AdminMenuDetailDto> menus;
  final String? selectedMenuId;
  final bool busy;
  final ValueChanged<String> onSelect;
  final VoidCallback onAdd;
  final ValueChanged<AdminMenuDetailDto> onEdit;
  final ValueChanged<AdminMenuDetailDto> onDelete;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      width: 260,
      color: palette.sidebarBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            child: const Text(
              'Menü Yöneticisi',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
            child: Text(
              'AKTİF KATEGORİLER',
              style: TextStyle(
                color: const Color(0xFF565674),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          Expanded(
            child: menus.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Henüz kategori yok',
                        style: TextStyle(
                          color: palette.sidebarText,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                : Theme(
                    // ReorderableListView'in default canvas rengini sidebar
                    // ile uyumlu hâle getir.
                    data: Theme.of(context).copyWith(
                      canvasColor: Colors.transparent,
                    ),
                    child: ReorderableListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      buildDefaultDragHandles: false,
                      onReorder: busy ? (_, _) {} : onReorder,
                      itemCount: menus.length,
                      itemBuilder: (ctx, i) {
                        final m = menus[i];
                        return _SidebarCategoryTile(
                          key: ValueKey(m.id),
                          index: i,
                          menu: m,
                          selected: m.id == selectedMenuId,
                          palette: palette,
                          busy: busy,
                          onSelect: () => onSelect(m.id),
                          onEdit: () => onEdit(m),
                          onDelete: () => onDelete(m),
                        );
                      },
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
            child: _DashedButton(
              label: '+ Yeni Kategori Ekle',
              borderColor: const Color(0xFF565674),
              textColor: palette.sidebarText,
              hoverTextColor: Colors.white,
              onPressed: busy ? null : onAdd,
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarCategoryTile extends StatefulWidget {
  const _SidebarCategoryTile({
    super.key,
    required this.index,
    required this.menu,
    required this.selected,
    required this.palette,
    required this.busy,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final AdminMenuDetailDto menu;
  final bool selected;
  final AppPalette palette;
  final bool busy;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_SidebarCategoryTile> createState() => _SidebarCategoryTileState();
}

class _SidebarCategoryTileState extends State<_SidebarCategoryTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.menu;
    final selected = widget.selected;
    final bgColor = selected
        ? widget.palette.accent
        : (_hover
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.transparent);
    final textColor = selected
        ? Colors.white
        : (_hover ? Colors.white : widget.palette.sidebarText);

    return ReorderableDragStartListener(
      index: widget.index,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.busy ? null : widget.onSelect,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        m.active
                            ? Icons.restaurant_menu
                            : Icons.visibility_off_outlined,
                        size: 16,
                        color: textColor,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          m.active ? m.name : '${m.name} (pasif)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Kategori işlemleri',
                  icon: Icon(Icons.more_vert, size: 18, color: textColor),
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  position: PopupMenuPosition.under,
                  onSelected: (v) {
                    switch (v) {
                      case 'edit':
                        widget.onEdit();
                      case 'delete':
                        widget.onDelete();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                    PopupMenuItem(value: 'delete', child: Text('Sil')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedButton extends StatelessWidget {
  const _DashedButton({
    required this.label,
    required this.borderColor,
    required this.textColor,
    required this.hoverTextColor,
    this.onPressed,
  });

  final String label;
  final Color borderColor;
  final Color textColor;
  final Color hoverTextColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onPressed == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: DottedBorder(
          color: borderColor,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: onPressed == null
                      ? textColor.withValues(alpha: 0.5)
                      : textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Minimum dashed border — paket eklemeyi atlatmak için custom paint.
class DottedBorder extends StatelessWidget {
  const DottedBorder({
    super.key,
    required this.color,
    required this.child,
    this.radius = 6,
    this.dashWidth = 4,
    this.dashGap = 3,
  });

  final Color color;
  final Widget child;
  final double radius;
  final double dashWidth;
  final double dashGap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DottedBorderPainter(
        color: color,
        radius: radius,
        dashWidth: dashWidth,
        dashGap: dashGap,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: child,
      ),
    );
  }
}

class _DottedBorderPainter extends CustomPainter {
  _DottedBorderPainter({
    required this.color,
    required this.radius,
    required this.dashWidth,
    required this.dashGap,
  });

  final Color color;
  final double radius;
  final double dashWidth;
  final double dashGap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final dashedPath = Path();
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        dashedPath.addPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          Offset.zero,
        );
        distance = next + dashGap;
      }
    }
    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant _DottedBorderPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.dashWidth != dashWidth ||
      old.dashGap != dashGap;
}

// ============================================================================
// PRODUCTS PANEL (orta — seçili kategorinin ürünleri)
// ============================================================================

class _ProductsPanel extends StatelessWidget {
  const _ProductsPanel({
    required this.menu,
    required this.busy,
    required this.onAdd,
    required this.onEditProduct,
    required this.onDeleteProduct,
    required this.onReorderProduct,
    required this.onPickImage,
    required this.onCreateFirstMenu,
  });

  final AdminMenuDetailDto? menu;
  final bool busy;
  final VoidCallback onAdd;
  final ValueChanged<AdminProductDetailDto> onEditProduct;
  final ValueChanged<AdminProductDetailDto> onDeleteProduct;
  final void Function(int oldIndex, int newIndex) onReorderProduct;
  final ValueChanged<AdminProductDetailDto> onPickImage;
  final VoidCallback onCreateFirstMenu;

  @override
  Widget build(BuildContext context) {
    if (menu == null) {
      return Center(
        child: FilledButton.icon(
          onPressed: onCreateFirstMenu,
          icon: const Icon(Icons.restaurant_menu),
          label: const Text('İlk kategoriyi oluştur'),
        ),
      );
    }

    final m = menu!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Toolbar(
            title: '${m.name} Kategorisi',
            subtitle: m.active
                ? '${m.products.length} ürün'
                : '${m.products.length} ürün · PASİF (müşteri / garson menüsünde görünmez)',
            busy: busy,
            onAdd: onAdd,
          ),
          const SizedBox(height: 20),
          _ProductsList(
            products: m.products,
            busy: busy,
            onEdit: onEditProduct,
            onDelete: onDeleteProduct,
            onReorder: onReorderProduct,
            onPickImage: onPickImage,
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.title,
    required this.subtitle,
    required this.busy,
    required this.onAdd,
  });

  final String title;
  final String subtitle;
  final bool busy;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 18, 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppPalette.of(context).textMuted,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: busy ? null : onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Yeni Ürün Ekle'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductsList extends StatelessWidget {
  const _ProductsList({
    required this.products,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
    required this.onReorder,
    required this.onPickImage,
  });

  final List<AdminProductDetailDto> products;
  final bool busy;
  final ValueChanged<AdminProductDetailDto> onEdit;
  final ValueChanged<AdminProductDetailDto> onDelete;
  final void Function(int oldIndex, int newIndex) onReorder;
  final ValueChanged<AdminProductDetailDto> onPickImage;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 48,
                  color: AppPalette.of(context).textMuted,
                ),
                const SizedBox(height: 12),
                Text(
                  'Bu kategoride ürün yok',
                  style: TextStyle(
                    color: AppPalette.of(context).textMuted,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '"Yeni Ürün Ekle" ile başlayın.',
                  style: TextStyle(
                    color: AppPalette.of(context).textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _ProductListHeader(),
          Theme(
            data: Theme.of(context).copyWith(canvasColor: Colors.transparent),
            child: ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorder: busy ? (_, _) {} : onReorder,
              itemCount: products.length,
              itemBuilder: (ctx, i) {
                final p = products[i];
                return _ProductListRow(
                  key: ValueKey(p.id),
                  index: i,
                  product: p,
                  busy: busy,
                  onEdit: () => onEdit(p),
                  onDelete: () => onDelete(p),
                  onPickImage: () => onPickImage(p),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductListHeader extends StatelessWidget {
  const _ProductListHeader();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 28),
          SizedBox(
            width: 56,
            child: Text(
              'GÖRSEL',
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Text(
              'ÜRÜN ADI',
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'FİYAT',
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          SizedBox(
            width: 100,
            child: Text(
              'İŞLEMLER',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductListRow extends StatefulWidget {
  const _ProductListRow({
    super.key,
    required this.index,
    required this.product,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
    required this.onPickImage,
  });

  final int index;
  final AdminProductDetailDto product;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPickImage;

  @override
  State<_ProductListRow> createState() => _ProductListRowState();
}

class _ProductListRowState extends State<_ProductListRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final p = widget.product;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.busy ? null : widget.onEdit,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: _hover ? palette.rowHover : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: widget.index,
                child: Icon(
                  Icons.drag_indicator,
                  size: 20,
                  color: palette.textMuted,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: widget.busy ? null : widget.onPickImage,
                child: _ProductThumb(imageUrl: p.imageUrl),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (p.description != null && p.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          p.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.textMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '${p.price.toStringAsFixed(2)} ₺',
                  style: TextStyle(fontSize: 14, color: palette.textMuted),
                ),
              ),
              SizedBox(
                width: 100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _ActionIcon(
                      icon: Icons.edit_outlined,
                      tooltip: 'Düzenle',
                      hoverColor: palette.accent,
                      onPressed: widget.busy ? null : widget.onEdit,
                    ),
                    const SizedBox(width: 8),
                    _ActionIcon(
                      icon: Icons.delete_outline,
                      tooltip: 'Sil',
                      hoverColor: palette.danger,
                      onPressed: widget.busy ? null : widget.onDelete,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionIcon extends StatefulWidget {
  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.hoverColor,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Color hoverColor;
  final VoidCallback? onPressed;

  @override
  State<_ActionIcon> createState() => _ActionIconState();
}

class _ActionIconState extends State<_ActionIcon> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final bg = _hover ? widget.hoverColor : palette.inputFill;
    final fg = _hover ? Colors.white : const Color(0xFF7E8299);
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(widget.icon, size: 16, color: fg),
          ),
        ),
      ),
    );
  }
}

class _ProductThumb extends StatelessWidget {
  const _ProductThumb({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final url = imageUrl;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: palette.border,
        borderRadius: BorderRadius.circular(6),
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null && url.isNotEmpty
          ? Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _placeholder(palette),
            )
          : _placeholder(palette),
    );
  }

  Widget _placeholder(AppPalette palette) {
    return Center(
      child: Icon(
        Icons.image_outlined,
        size: 20,
        color: palette.textMuted,
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: AppPalette.of(context).danger,
            ),
            const SizedBox(height: 12),
            Text('Menü yüklenemedi: $error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Yeniden dene')),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// PRODUCT EDITOR PANEL (sağ slide-panel — ürün form + seçenek grupları)
// ============================================================================

class _ProductEditorPanel extends StatefulWidget {
  const _ProductEditorPanel({
    super.key,
    required this.product,
    required this.allMenus,
    required this.currentMenuId,
    required this.busy,
    required this.loadingGroups,
    required this.groups,
    required this.palette,
    this.embedded = false,
    required this.onClose,
    required this.onSave,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.onAddGroup,
    required this.onUpdateGroup,
    required this.onRemoveGroup,
    required this.onReorderGroup,
    required this.onAddOption,
    required this.onUpdateOption,
    required this.onRemoveOption,
    required this.onReorderOption,
  });

  final AdminProductDetailDto product;
  final List<AdminMenuDetailDto> allMenus;
  final String currentMenuId;
  final bool busy;
  final bool loadingGroups;
  final List<AdminOptionGroupDto> groups;
  final AppPalette palette;

  /// true ise üst kısımda kendi header'ı yerine Scaffold AppBar kullanılıyor demektir.
  final bool embedded;

  final VoidCallback onClose;
  final Future<void> Function({
    required String productId,
    required String name,
    required String description,
    required double price,
    required String sku,
    required double? taxRate,
    required String? newMenuId,
  })
  onSave;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;
  final Future<void> Function({
    required String name,
    required String selectionType,
  })
  onAddGroup;
  final Future<void> Function({
    required AdminOptionGroupDto group,
    required String name,
    required String selectionType,
  })
  onUpdateGroup;
  final Future<void> Function(AdminOptionGroupDto group) onRemoveGroup;
  final void Function(int oldIndex, int newIndex) onReorderGroup;
  final Future<void> Function({
    required String groupId,
    required String label,
    required double priceAdjustment,
  })
  onAddOption;
  final Future<void> Function({
    required AdminOptionItemDto option,
    required String label,
    required double priceAdjustment,
  })
  onUpdateOption;
  final Future<void> Function({
    required String groupId,
    required AdminOptionItemDto option,
  })
  onRemoveOption;
  final void Function(String groupId, int oldIndex, int newIndex) onReorderOption;

  @override
  State<_ProductEditorPanel> createState() => _ProductEditorPanelState();
}

class _ProductEditorPanelState extends State<_ProductEditorPanel> {
  late final TextEditingController _nameCtl;
  late final TextEditingController _descCtl;
  late final TextEditingController _priceCtl;
  late final TextEditingController _skuCtl;
  late final TextEditingController _taxCtl;
  late String _menuId;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtl = TextEditingController(text: p.name);
    _descCtl = TextEditingController(text: p.description ?? '');
    _priceCtl = TextEditingController(text: p.price.toStringAsFixed(2));
    _skuCtl = TextEditingController(text: p.sku ?? '');
    _taxCtl = TextEditingController(
      text: p.taxRate == null ? '' : p.taxRate.toString(),
    );
    _menuId = widget.currentMenuId;
  }

  @override
  void didUpdateWidget(_ProductEditorPanel old) {
    super.didUpdateWidget(old);
    // Aynı widget farklı ürünle yeniden çağrıldıysa (slide panel başka ürüne geçti)
    if (old.product.id != widget.product.id) {
      final p = widget.product;
      _nameCtl.text = p.name;
      _descCtl.text = p.description ?? '';
      _priceCtl.text = p.price.toStringAsFixed(2);
      _skuCtl.text = p.sku ?? '';
      _taxCtl.text = p.taxRate == null ? '' : p.taxRate.toString();
      _menuId = widget.currentMenuId;
    }
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _descCtl.dispose();
    _priceCtl.dispose();
    _skuCtl.dispose();
    _taxCtl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final name = _nameCtl.text.trim();
    if (name.isEmpty) {
      _toast('Ürün adı zorunlu');
      return;
    }
    final price = double.tryParse(_priceCtl.text.replaceAll(',', '.'));
    if (price == null || price < 0) {
      _toast('Geçerli bir fiyat girin');
      return;
    }
    double? taxRate;
    final taxRaw = _taxCtl.text.trim();
    if (taxRaw.isNotEmpty) {
      taxRate = double.tryParse(taxRaw.replaceAll(',', '.'));
      if (taxRate == null || taxRate < 0 || taxRate > 1) {
        _toast('KDV oranı 0 ile 1 arasında olmalı');
        return;
      }
    }
    await widget.onSave(
      productId: widget.product.id,
      name: name,
      description: _descCtl.text.trim(),
      price: price,
      sku: _skuCtl.text.trim(),
      taxRate: taxRate,
      newMenuId: _menuId,
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.embedded) _buildHeader(palette),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ImageUploader(
                  imageUrl: widget.product.imageUrl,
                  onPickImage: widget.onPickImage,
                  onRemoveImage: widget.onRemoveImage,
                  busy: widget.busy,
                ),
                const SizedBox(height: 20),
                _formGroup(
                  label: 'Ürün Adı',
                  child: TextField(
                    controller: _nameCtl,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _formGroup(
                        label: 'Fiyat (₺)',
                        child: TextField(
                          controller: _priceCtl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,]'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _formGroup(
                        label: 'KDV (0–1)',
                        child: TextField(
                          controller: _taxCtl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(hintText: '0.10'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _formGroup(
                  label: 'Açıklama',
                  child: TextField(controller: _descCtl, maxLines: 2),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _formGroup(
                        label: 'SKU (opsiyonel)',
                        child: TextField(controller: _skuCtl),
                      ),
                    ),
                    const SizedBox(width: 16),
                    if (widget.allMenus.length > 1)
                      Expanded(
                        child: _formGroup(
                          label: 'Kategori',
                          child: DropdownButtonFormField<String>(
                            initialValue: _menuId,
                            items: [
                              for (final m in widget.allMenus)
                                DropdownMenuItem(
                                  value: m.id,
                                  child: Text(m.name),
                                ),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _menuId = v);
                            },
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                _DashedSeparator(color: palette.border),
                const SizedBox(height: 16),
                _OptionGroupsSection(
                  groups: widget.groups,
                  loading: widget.loadingGroups,
                  palette: palette,
                  busy: widget.busy,
                  onAddGroup: widget.onAddGroup,
                  onUpdateGroup: widget.onUpdateGroup,
                  onRemoveGroup: widget.onRemoveGroup,
                  onReorderGroup: widget.onReorderGroup,
                  onAddOption: widget.onAddOption,
                  onUpdateOption: widget.onUpdateOption,
                  onRemoveOption: widget.onRemoveOption,
                  onReorderOption: widget.onReorderOption,
                ),
              ],
            ),
          ),
        ),
        _buildFooter(palette),
      ],
    );
  }

  Widget _buildHeader(AppPalette palette) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 16, 20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Ürünü Düzenle',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: palette.textMain,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: widget.onClose,
            tooltip: 'Kapat',
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(AppPalette palette) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFC),
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: widget.busy ? null : widget.onClose,
            style: TextButton.styleFrom(
              backgroundColor: palette.inputFill,
              foregroundColor: const Color(0xFF7E8299),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
            ),
            child: const Text('İptal'),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: widget.busy ? null : _handleSave,
            child: const Text('Değişiklikleri Kaydet'),
          ),
        ],
      ),
    );
  }

  Widget _formGroup({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF3F4254),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _DashedSeparator extends StatelessWidget {
  const _DashedSeparator({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) {
        final dashWidth = 6.0;
        final dashGap = 4.0;
        final count = (c.maxWidth / (dashWidth + dashGap)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => SizedBox(
              width: dashWidth,
              height: 1,
              child: DecoratedBox(decoration: BoxDecoration(color: color)),
            ),
          ),
        );
      },
    );
  }
}

class _ImageUploader extends StatelessWidget {
  const _ImageUploader({
    required this.imageUrl,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.busy,
  });

  final String? imageUrl;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFCFC),
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: palette.border,
              borderRadius: BorderRadius.circular(6),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasImage
                ? Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.broken_image_outlined,
                      color: palette.textMuted,
                    ),
                  )
                : Icon(Icons.image_outlined, color: palette.textMuted),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ürün resmi',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3F4254),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasImage
                      ? 'Karta tıklayarak değiştirin veya kaldırın.'
                      : 'Müşteri menüsünde görünecek 1:1 oranlı görsel.',
                  style: TextStyle(fontSize: 12, color: palette.textMuted),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: busy ? null : onPickImage,
                      icon: const Icon(Icons.upload_outlined, size: 16),
                      label: Text(hasImage ? 'Değiştir' : 'Yükle'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                    if (hasImage) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: busy ? null : onRemoveImage,
                        icon: Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: palette.danger,
                        ),
                        label: Text(
                          'Kaldır',
                          style: TextStyle(color: palette.danger),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          side: BorderSide(
                            color: palette.danger.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// OPTION GROUPS SECTION (slide panel içinde — seçenek grupları + seçenekler)
// ============================================================================

class _OptionGroupsSection extends StatelessWidget {
  const _OptionGroupsSection({
    required this.groups,
    required this.loading,
    required this.palette,
    required this.busy,
    required this.onAddGroup,
    required this.onUpdateGroup,
    required this.onRemoveGroup,
    required this.onReorderGroup,
    required this.onAddOption,
    required this.onUpdateOption,
    required this.onRemoveOption,
    required this.onReorderOption,
  });

  final List<AdminOptionGroupDto> groups;
  final bool loading;
  final AppPalette palette;
  final bool busy;
  final Future<void> Function({
    required String name,
    required String selectionType,
  })
  onAddGroup;
  final Future<void> Function({
    required AdminOptionGroupDto group,
    required String name,
    required String selectionType,
  })
  onUpdateGroup;
  final Future<void> Function(AdminOptionGroupDto group) onRemoveGroup;
  final void Function(int oldIndex, int newIndex) onReorderGroup;
  final Future<void> Function({
    required String groupId,
    required String label,
    required double priceAdjustment,
  })
  onAddOption;
  final Future<void> Function({
    required AdminOptionItemDto option,
    required String label,
    required double priceAdjustment,
  })
  onUpdateOption;
  final Future<void> Function({
    required String groupId,
    required AdminOptionItemDto option,
  })
  onRemoveOption;
  final void Function(String groupId, int oldIndex, int newIndex) onReorderOption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Text(
                'SEÇENEK GRUPLARI',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: palette.textMuted,
                ),
              ),
              const Spacer(),
              if (loading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        if (!loading && groups.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Henüz seçenek grubu yok. "Boyut", "Ekstra" gibi gruplar ekleyin.',
              style: TextStyle(fontSize: 13, color: palette.textMuted),
            ),
          ),
        if (groups.isNotEmpty)
          Theme(
            data: Theme.of(context).copyWith(canvasColor: Colors.transparent),
            child: ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorder: busy ? (_, _) {} : onReorderGroup,
              itemCount: groups.length,
              itemBuilder: (ctx, i) {
                final g = groups[i];
                return _OptionGroupCard(
                  key: ValueKey(g.id),
                  index: i,
                  group: g,
                  palette: palette,
                  busy: busy,
                  onEditGroup: () => _editGroupDialog(context, group: g),
                  onRemoveGroup: () => onRemoveGroup(g),
                  onAddOption: () => _addOptionDialog(context, groupId: g.id),
                  onEditOption: (o) =>
                      _editOptionDialog(context, group: g, option: o),
                  onRemoveOption: (o) =>
                      onRemoveOption(groupId: g.id, option: o),
                  onReorderOption: (oi, ni) =>
                      onReorderOption(g.id, oi, ni),
                );
              },
            ),
          ),
        const SizedBox(height: 12),
        DottedBorder(
          color: palette.border,
          radius: 8,
          dashWidth: 5,
          dashGap: 4,
          child: SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: busy ? null : () => _addGroupDialog(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                foregroundColor: palette.textMuted,
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('+ Yeni Seçenek Grubu Ekle (Boyut, Ekstra, …)'),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _addGroupDialog(BuildContext context) async {
    final result = await _GroupDialog.show(context: context);
    if (result == null) return;
    await onAddGroup(name: result.name, selectionType: result.selectionType);
  }

  Future<void> _editGroupDialog(
    BuildContext context, {
    required AdminOptionGroupDto group,
  }) async {
    final result = await _GroupDialog.show(context: context, existing: group);
    if (result == null) return;
    await onUpdateGroup(
      group: group,
      name: result.name,
      selectionType: result.selectionType,
    );
  }

  Future<void> _addOptionDialog(
    BuildContext context, {
    required String groupId,
  }) async {
    final result = await _OptionDialog.show(context: context);
    if (result == null) return;
    await onAddOption(
      groupId: groupId,
      label: result.label,
      priceAdjustment: result.priceAdjustment,
    );
  }

  Future<void> _editOptionDialog(
    BuildContext context, {
    required AdminOptionGroupDto group,
    required AdminOptionItemDto option,
  }) async {
    final result = await _OptionDialog.show(context: context, existing: option);
    if (result == null) return;
    await onUpdateOption(
      option: option,
      label: result.label,
      priceAdjustment: result.priceAdjustment,
    );
  }
}

class _OptionGroupCard extends StatelessWidget {
  const _OptionGroupCard({
    super.key,
    required this.index,
    required this.group,
    required this.palette,
    required this.busy,
    required this.onEditGroup,
    required this.onRemoveGroup,
    required this.onAddOption,
    required this.onEditOption,
    required this.onRemoveOption,
    required this.onReorderOption,
  });

  final int index;
  final AdminOptionGroupDto group;
  final AppPalette palette;
  final bool busy;
  final VoidCallback onEditGroup;
  final VoidCallback onRemoveGroup;
  final VoidCallback onAddOption;
  final ValueChanged<AdminOptionItemDto> onEditOption;
  final ValueChanged<AdminOptionItemDto> onRemoveOption;
  final void Function(int oldIndex, int newIndex) onReorderOption;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFCFC),
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: Icon(
                  Icons.drag_indicator,
                  size: 18,
                  color: palette.textMuted,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  group.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: group.selectionType == 'MULTI'
                      ? palette.accent.withValues(alpha: 0.1)
                      : palette.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  group.selectionType == 'MULTI' ? 'ÇOKLU' : 'TEKLİ',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: group.selectionType == 'MULTI'
                        ? palette.accent
                        : const Color(0xFF1F6B3D),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                tooltip: 'Grup işlemleri',
                icon: Icon(
                  Icons.more_vert,
                  size: 18,
                  color: palette.textMuted,
                ),
                padding: EdgeInsets.zero,
                onSelected: (v) {
                  switch (v) {
                    case 'edit':
                      onEditGroup();
                    case 'delete':
                      onRemoveGroup();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Grubu düzenle')),
                  PopupMenuItem(value: 'delete', child: Text('Grubu sil')),
                ],
              ),
            ],
          ),
          if (group.options.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Henüz seçenek yok.',
                style: TextStyle(fontSize: 12, color: palette.textMuted),
              ),
            )
          else ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 6,
                    child: Text(
                      'SEÇENEK ADI',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: palette.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'EK FİYAT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: palette.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 72),
                ],
              ),
            ),
            Theme(
              data: Theme.of(context).copyWith(canvasColor: Colors.transparent),
              child: ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorder: busy ? (_, _) {} : onReorderOption,
                itemCount: group.options.length,
                itemBuilder: (ctx, i) {
                  final o = group.options[i];
                  return _OptionRow(
                    key: ValueKey(o.id),
                    index: i,
                    option: o,
                    palette: palette,
                    busy: busy,
                    onEdit: () => onEditOption(o),
                    onRemove: () => onRemoveOption(o),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: busy ? null : onAddOption,
              icon: Icon(Icons.add, size: 16, color: palette.success),
              label: Text(
                'Seçenek Ekle',
                style: TextStyle(color: palette.success),
              ),
              style: TextButton.styleFrom(
                backgroundColor: palette.success.withValues(alpha: 0.1),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    super.key,
    required this.index,
    required this.option,
    required this.palette,
    required this.busy,
    required this.onEdit,
    required this.onRemove,
  });

  final int index;
  final AdminOptionItemDto option;
  final AppPalette palette;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.border.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Icon(
              Icons.drag_indicator,
              size: 16,
              color: palette.textMuted,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: Text(
              option.label,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              option.priceAdjustment == 0
                  ? '—'
                  : '+${option.priceAdjustment.toStringAsFixed(2)} ₺',
              style: TextStyle(
                fontSize: 13,
                color: option.priceAdjustment == 0
                    ? palette.textMuted
                    : palette.textMain,
                fontWeight: option.priceAdjustment == 0
                    ? FontWeight.normal
                    : FontWeight.w500,
              ),
            ),
          ),
          _ActionIcon(
            icon: Icons.edit_outlined,
            tooltip: 'Düzenle',
            hoverColor: palette.accent,
            onPressed: busy ? null : onEdit,
          ),
          const SizedBox(width: 6),
          _ActionIcon(
            icon: Icons.delete_outline,
            tooltip: 'Sil',
            hoverColor: palette.danger,
            onPressed: busy ? null : onRemove,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// DIALOG'LAR (grup + seçenek için)
// ============================================================================

class _GroupDialogResult {
  _GroupDialogResult({required this.name, required this.selectionType});
  final String name;
  final String selectionType;
}

class _GroupDialog extends StatefulWidget {
  const _GroupDialog({this.existing});
  final AdminOptionGroupDto? existing;

  static Future<_GroupDialogResult?> show({
    required BuildContext context,
    AdminOptionGroupDto? existing,
  }) {
    return showDialog<_GroupDialogResult>(
      context: context,
      builder: (_) => _GroupDialog(existing: existing),
    );
  }

  @override
  State<_GroupDialog> createState() => _GroupDialogState();
}

class _GroupDialogState extends State<_GroupDialog> {
  late final TextEditingController _nameCtl;
  late String _selectionType;

  @override
  void initState() {
    super.initState();
    _nameCtl = TextEditingController(text: widget.existing?.name ?? '');
    _selectionType = widget.existing?.selectionType ?? 'SINGLE';
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Seçenek grubu ekle' : 'Grubu düzenle',
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameCtl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Grup adı (örn. Boyut)',
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectionType,
              decoration: const InputDecoration(labelText: 'Seçim tipi'),
              items: const [
                DropdownMenuItem(
                  value: 'SINGLE',
                  child: Text('Tekli seçim (zorunlu)'),
                ),
                DropdownMenuItem(
                  value: 'MULTI',
                  child: Text('Çoklu seçim (isteğe bağlı)'),
                ),
              ],
              onChanged: (v) => setState(() => _selectionType = v ?? 'SINGLE'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: () {
            if (_nameCtl.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              _GroupDialogResult(
                name: _nameCtl.text.trim(),
                selectionType: _selectionType,
              ),
            );
          },
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}

class _OptionDialogResult {
  _OptionDialogResult({required this.label, required this.priceAdjustment});
  final String label;
  final double priceAdjustment;
}

class _OptionDialog extends StatefulWidget {
  const _OptionDialog({this.existing});
  final AdminOptionItemDto? existing;

  static Future<_OptionDialogResult?> show({
    required BuildContext context,
    AdminOptionItemDto? existing,
  }) {
    return showDialog<_OptionDialogResult>(
      context: context,
      builder: (_) => _OptionDialog(existing: existing),
    );
  }

  @override
  State<_OptionDialog> createState() => _OptionDialogState();
}

class _OptionDialogState extends State<_OptionDialog> {
  late final TextEditingController _labelCtl;
  late final TextEditingController _priceCtl;

  @override
  void initState() {
    super.initState();
    _labelCtl = TextEditingController(text: widget.existing?.label ?? '');
    _priceCtl = TextEditingController(
      text: widget.existing != null
          ? widget.existing!.priceAdjustment.toStringAsFixed(2)
          : '0',
    );
  }

  @override
  void dispose() {
    _labelCtl.dispose();
    _priceCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Seçenek ekle' : 'Seçeneği düzenle',
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _labelCtl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Seçenek adı (örn. Cheddar)',
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceCtl,
              decoration: const InputDecoration(
                labelText: 'Ek fiyat (₺)',
                hintText: '0.00',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,-]')),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: () {
            final label = _labelCtl.text.trim();
            if (label.isEmpty) return;
            final price =
                double.tryParse(_priceCtl.text.replaceAll(',', '.')) ?? 0;
            Navigator.pop(
              context,
              _OptionDialogResult(label: label, priceAdjustment: price),
            );
          },
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}
