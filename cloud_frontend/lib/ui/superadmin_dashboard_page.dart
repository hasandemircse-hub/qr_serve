import 'package:flutter/material.dart';

import '../api/restaurants_api.dart';
import '../auth/cloud_auth_session.dart';
import '../config/app_config.dart';

class SuperadminDashboardPage extends StatefulWidget {
  const SuperadminDashboardPage({super.key, required this.auth});

  final CloudAuthSession auth;

  @override
  State<SuperadminDashboardPage> createState() => _SuperadminDashboardPageState();
}

class _SuperadminDashboardPageState extends State<SuperadminDashboardPage> {
  List<RestaurantSummary>? _rows;
  String? _loadError;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = widget.auth.accessToken;
    if (token == null) return;
    setState(() {
      _loadError = null;
      _rows = null;
    });
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${r.name}: $status')),
        );
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
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
          IconButton(onPressed: widget.auth.signOut, icon: const Icon(Icons.logout)),
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
                      child: Icon(Icons.person, color: scheme.onPrimaryContainer),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.auth.displayName ?? 'Süper yönetici',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          Text(
                            widget.auth.email ?? '',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
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
            Text('Restoranlar', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (_loadError != null)
              Card(
                color: scheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hata', style: TextStyle(color: scheme.onErrorContainer, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(_loadError!, style: TextStyle(color: scheme.onErrorContainer)),
                      FilledButton(onPressed: _load, child: const Text('Tekrar dene')),
                    ],
                  ),
                ),
              )
            else if (_rows == null)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            else if (_rows!.isEmpty)
              const Text('Kayıtlı restoran yok.')
            else
              ..._rows!.map((r) => _RestaurantCard(
                    r: r,
                    busy: _busyId == r.id,
                    onStatus: (s) => _setStatus(r, s),
                  )),
          ],
        ),
      ),
    );
  }
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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        r.id,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Chip(label: Text(r.subscriptionStatus), visualDensity: VisualDensity.compact),
              ],
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
