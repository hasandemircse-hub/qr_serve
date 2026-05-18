import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_session.dart';
import '../setup/edge_setup_api.dart';
import '../widgets/staff_profile_banner.dart';
import '../layout/floor_design_editor_screen.dart';
import '../layout/floor_layout_terminal_screen.dart';
import '../admin/menu_admin_screen.dart';
import '../admin/product_options_admin_screen.dart';
import '../admin/staff_admin_screen.dart';
import '../billing/closure_balance_report_screen.dart';

/// Restoran yöneticisi: menü / personel / masa düzeni — LAN Edge + isteğe bağlı Cloud.
class RestaurantAdminLanding extends StatefulWidget {
  const RestaurantAdminLanding({
    super.key,
    required this.auth,
    required this.edgeBaseUrl,
    required this.demoRestaurantId,
    required this.demoProductId,
  });

  final AuthSession auth;
  final String edgeBaseUrl;
  final String demoRestaurantId;
  final String demoProductId;

  @override
  State<RestaurantAdminLanding> createState() => _RestaurantAdminLandingState();
}

class _RestaurantAdminLandingState extends State<RestaurantAdminLanding> {
  int _tab = 0;
  bool _wizardCheckDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _maybeOpenSetupWizard(),
    );
  }

  Future<void> _maybeOpenSetupWizard() async {
    if (_wizardCheckDone || !mounted) return;
    _wizardCheckDone = true;
    try {
      final status = await fetchEdgeSetupStatus(widget.edgeBaseUrl);
      if (!mounted || !status.needsWizard) return;
      context.go('/admin/setup');
    } catch (_) {
      // Edge kapalı veya eski sürüm: sessizce ana ekranda kal
    }
  }

  String get _effectiveRestaurantId =>
      widget.auth.restaurantId ?? widget.demoRestaurantId;

  String _appBarTitle() {
    return switch (_tab) {
      0 => 'Salon düzeni',
      1 => 'Kat planı editörü',
      2 => 'Menü yönetimi',
      3 => 'Ürün seçenekleri',
      _ => 'Personel',
    };
  }

  static const _navLabels = [
    'Salon',
    'Kat planı',
    'Menü',
    'Seçenekler',
    'Personel',
  ];

  static String _wsHostPort(String edgeBaseUrl) {
    final u = Uri.parse(edgeBaseUrl);
    final port = u.hasPort ? u.port : 8081;
    return '${u.host}:$port';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text(_appBarTitle()),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: widget.auth.signOut,
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  widget.auth.displayName ?? 'Yönetici',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: StaffProfileBanner(
                auth: widget.auth,
                roleLabel: 'RESTORAN YÖNETİCİSİ',
                icon: Icons.admin_panel_settings_outlined,
                subtitle:
                    'Salon, Kat planı, Menü, Seçenekler veya Personel sekmesine geçin.',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.summarize_outlined),
              title: const Text('Bakiye raporu'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ClosureBalanceReportScreen(
                      edgeBaseUrl: widget.edgeBaseUrl,
                      accessToken: widget.auth.accessToken,
                    ),
                  ),
                );
              },
            ),
            for (var i = 0; i < _navLabels.length; i++)
              ListTile(
                leading: Icon(switch (i) {
                  0 => Icons.table_restaurant,
                  1 => Icons.design_services_outlined,
                  2 => Icons.restaurant_menu_outlined,
                  3 => Icons.tune_outlined,
                  _ => Icons.groups_outlined,
                }),
                title: Text(_navLabels[i]),
                selected: _tab == i,
                onTap: () {
                  setState(() => _tab = i);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.table_restaurant_outlined),
            selectedIcon: Icon(Icons.table_restaurant),
            label: 'Salon',
          ),
          NavigationDestination(
            icon: Icon(Icons.design_services_outlined),
            selectedIcon: Icon(Icons.design_services),
            label: 'Kat planı',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu),
            label: 'Menü',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: 'Seçenekler',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Personel',
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          FloorLayoutTerminalScreen(
            restaurantId: _effectiveRestaurantId,
            wsHost: _wsHostPort(widget.edgeBaseUrl),
          ),
          FloorDesignEditorScreen(
            edgeBaseUrl: widget.edgeBaseUrl,
            restaurantId: _effectiveRestaurantId,
            authToken: widget.auth.accessToken ?? '',
          ),
          MenuAdminScreen(
            edgeBaseUrl: widget.edgeBaseUrl,
            accessToken: widget.auth.accessToken,
            restaurantId: _effectiveRestaurantId,
          ),
          ProductOptionsAdminScreen(
            edgeBaseUrl: widget.edgeBaseUrl,
            authToken: widget.auth.accessToken ?? '',
            restaurantId: _effectiveRestaurantId,
            initialProductId: widget.demoProductId,
          ),
          StaffAdminScreen(
            edgeBaseUrl: widget.edgeBaseUrl,
            accessToken: widget.auth.accessToken,
            restaurantId: _effectiveRestaurantId,
          ),
        ],
      ),
    );
  }
}
