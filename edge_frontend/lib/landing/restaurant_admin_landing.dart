import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_session.dart';
import '../setup/edge_setup_api.dart';
import '../widgets/staff_profile_banner.dart';
import '../layout/floor_design_editor_screen.dart';
import '../layout/floor_layout_terminal_screen.dart';
import '../qr/product_option_wizard_screen.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOpenSetupWizard());
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
      0 => 'Salon düzeni (terminal)',
      1 => 'Tasarım editörü',
      _ => 'QR ürün sihirbazı',
    };
  }

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
          IconButton(icon: const Icon(Icons.logout), onPressed: widget.auth.signOut),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  widget.auth.displayName ?? 'Yönetici',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: StaffProfileBanner(
                auth: widget.auth,
                roleLabel: 'RESTORAN YÖNETİCİSİ',
                icon: Icons.admin_panel_settings_outlined,
                subtitle: 'Salon, kat planı ve ürün seçenekleri bu cihazdaki Edge ile yönetilir.',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.table_restaurant),
              title: const Text('Salon düzeni'),
              selected: _tab == 0,
              onTap: () {
                setState(() => _tab = 0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.design_services_outlined),
              title: const Text('Tasarım editörü'),
              selected: _tab == 1,
              onTap: () {
                setState(() => _tab = 1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_2),
              title: const Text('QR ürün seçenekleri'),
              selected: _tab == 2,
              onTap: () {
                setState(() => _tab = 2);
                Navigator.pop(context);
              },
            ),
          ],
        ),
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
          ProductOptionWizardScreen(
            edgeBaseUrl: widget.edgeBaseUrl,
            authToken: widget.auth.accessToken ?? '',
            restaurantId: _effectiveRestaurantId,
            productId: widget.demoProductId,
          ),
        ],
      ),
    );
  }
}
