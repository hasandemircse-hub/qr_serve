import 'package:flutter/material.dart';

import '../api/restaurants_api.dart';
import '../auth/cloud_auth_session.dart';
import '../config/app_config.dart';

class SuperadminDashboardPage extends StatefulWidget {
  const SuperadminDashboardPage({super.key, required this.auth});

  final CloudAuthSession auth;

  @override
  State<SuperadminDashboardPage> createState() =>
      _SuperadminDashboardPageState();
}

class _SuperadminDashboardPageState extends State<SuperadminDashboardPage> {
  List<RestaurantSummary>? _rows;
  String? _loadError;
  String? _busyId;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _load();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    Future<void> tick() async {
      await Future<void>.delayed(const Duration(seconds: 30));
      if (!mounted) return;
      await _load(silent: true);
      tick();
    }

    tick();
  }

  Future<void> _load({bool silent = false}) async {
    final token = widget.auth.accessToken;
    if (token == null) return;
    if (!silent) {
      setState(() {
        _loadError = null;
        _rows = null;
      });
    }
    try {
      final list = await fetchRestaurants(
        cloudBaseUrl: AppConfig.cloudBaseUrl,
        accessToken: token,
      );
      if (mounted) setState(() => _rows = list);
    } catch (e) {
      if (mounted) setState(() => _loadError = '$e');
    }
  }

  Future<void> _setStatus(RestaurantSummary r, String status) async {
    final token = widget.auth.accessToken;
    if (token == null) return;
    setState(() => _busyId = r.id);
    try {
      await patchRestaurantSubscription(
        cloudBaseUrl: AppConfig.cloudBaseUrl,
        accessToken: token,
        restaurantId: r.id,
        subscriptionStatus: status,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${r.name}: $status')));
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _openCreateDialog() async {
    final token = widget.auth.accessToken;
    if (token == null || _creating) return;
    final nameCtrl = TextEditingController();
    final legalCtrl = TextEditingController();
    final taxCtrl = TextEditingController();
    var status = 'DEMO';
    final body = await showDialog<_CreateRestaurantBody>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Restoran ekle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Restoran adı',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: legalCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Ticari unvan',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: taxCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Vergi no',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(
                    labelText: 'Abonelik',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'DEMO', child: Text('DEMO')),
                    DropdownMenuItem(value: 'ACTIVE', child: Text('ACTIVE')),
                    DropdownMenuItem(value: 'FROZEN', child: Text('FROZEN')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => status = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(
                  ctx,
                  _CreateRestaurantBody(
                    name: name,
                    legalName: _blankToNull(legalCtrl.text),
                    taxId: _blankToNull(taxCtrl.text),
                    subscriptionStatus: status,
                  ),
                );
              },
              child: const Text('Oluştur'),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
    legalCtrl.dispose();
    taxCtrl.dispose();
    if (body == null) return;
    setState(() => _creating = true);
    try {
      final created = await createRestaurant(
        cloudBaseUrl: AppConfig.cloudBaseUrl,
        accessToken: token,
        name: body.name,
        legalName: body.legalName,
        taxId: body.taxId,
        subscriptionStatus: body.subscriptionStatus,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${created.name} oluşturuldu')));
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Süper yönetici'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          IconButton(
            onPressed: widget.auth.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Card(
              color: scheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: scheme.primaryContainer,
                      child: Icon(
                        Icons.person,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.auth.displayName ?? 'Süper yönetici',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            widget.auth.email ?? '',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'API: ${AppConfig.cloudBaseUrl}',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Restoranlar & Edge',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Otomatik yenileme: 30 sn',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _creating ? null : _openCreateDialog,
                      icon: _creating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_business_outlined),
                      label: const Text('Restoran ekle'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loadError != null)
              Card(
                color: scheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hata',
                        style: TextStyle(
                          color: scheme.onErrorContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _loadError!,
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                      FilledButton(
                        onPressed: _load,
                        child: const Text('Tekrar dene'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_rows == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_rows!.isEmpty)
              const Text('Kayıtlı restoran yok.')
            else
              ..._rows!.map(
                (r) => _RestaurantCard(
                  r: r,
                  busy: _busyId == r.id,
                  onStatus: (s) => _setStatus(r, s),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CreateRestaurantBody {
  const _CreateRestaurantBody({
    required this.name,
    required this.legalName,
    required this.taxId,
    required this.subscriptionStatus,
  });

  final String name;
  final String? legalName;
  final String? taxId;
  final String subscriptionStatus;
}

String? _blankToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

class _RestaurantCard extends StatelessWidget {
  const _RestaurantCard({
    required this.r,
    required this.busy,
    required this.onStatus,
  });

  final RestaurantSummary r;
  final bool busy;
  final void Function(String status) onStatus;

  static const _statuses = ['DEMO', 'ACTIVE', 'FROZEN'];

  Color _edgeStatusColor(ColorScheme scheme) {
    return switch (r.edgeStatus) {
      'ONLINE' => Colors.green.shade700,
      'OFFLINE' => scheme.error,
      _ => scheme.outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Text(r.name.isNotEmpty ? r.name[0] : '?'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        r.id,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(r.subscriptionStatus),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.hub_outlined,
                  size: 18,
                  color: _edgeStatusColor(scheme),
                ),
                const SizedBox(width: 6),
                Chip(
                  label: Text('Edge: ${r.edgeStatusLabel}'),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: _edgeStatusColor(
                    scheme,
                  ).withValues(alpha: 0.12),
                  labelStyle: TextStyle(
                    color: _edgeStatusColor(scheme),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (r.edgeId != null) ...[
              const SizedBox(height: 6),
              Text(
                'Edge ID: ${r.edgeId}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (r.publicEdgeUrl != null && r.publicEdgeUrl!.isNotEmpty) ...[
              Text(
                'URL: ${r.publicEdgeUrl}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (r.lastHelloAt != null)
              Text(
                'Son sinyal: ${r.lastHelloAt}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (r.lastAcknowledgedUpdatedAt != null)
              Text(
                'Son sync ack: ${r.lastAcknowledgedUpdatedAt}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 12),
            Text('Abonelik', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            if (busy)
              const LinearProgressIndicator()
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in _statuses)
                    if (s != r.subscriptionStatus)
                      OutlinedButton(
                        onPressed: () => onStatus(s),
                        child: Text(s),
                      ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
