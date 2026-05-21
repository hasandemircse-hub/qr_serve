import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../api/restaurants_api.dart';
import '../api/users_api.dart';
import '../auth/cloud_auth_session.dart';
import '../config/app_config.dart';

/// Süperadmin için tek restoran detayı: Genel | Kullanıcılar | Edge
class RestaurantDetailPage extends StatefulWidget {
  const RestaurantDetailPage({
    super.key,
    required this.auth,
    required this.restaurantId,
  });

  final CloudAuthSession auth;
  final String restaurantId;

  @override
  State<RestaurantDetailPage> createState() => _RestaurantDetailPageState();
}

class _RestaurantDetailPageState extends State<RestaurantDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  bool _loadingOverview = true;
  String? _overviewError;
  RestaurantSummary? _overview;

  bool _loadingUsers = false;
  String? _usersError;
  List<AdminUser> _users = const [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _refreshOverview();
    _refreshUsers();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _refreshOverview() async {
    setState(() {
      _loadingOverview = true;
      _overviewError = null;
    });
    try {
      final list = await fetchRestaurants(
        cloudBaseUrl: AppConfig.cloudBaseUrl,
        accessToken: widget.auth.accessToken!,
      );
      final me = list.firstWhere(
        (r) => r.id == widget.restaurantId,
        orElse: () => throw Exception('Restoran bulunamadı'),
      );
      if (!mounted) return;
      setState(() {
        _overview = me;
        _loadingOverview = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _overviewError = '$e';
        _loadingOverview = false;
      });
    }
  }

  Future<void> _refreshUsers() async {
    setState(() {
      _loadingUsers = true;
      _usersError = null;
    });
    try {
      final list = await fetchUsers(
        cloudBaseUrl: AppConfig.cloudBaseUrl,
        accessToken: widget.auth.accessToken!,
        restaurantId: widget.restaurantId,
      );
      if (!mounted) return;
      setState(() {
        _users = list;
        _loadingUsers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _usersError = '$e';
        _loadingUsers = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _overview?.name ?? 'Restoran';
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: () {
              _refreshOverview();
              _refreshUsers();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(icon: Icon(Icons.info_outline), text: 'Genel'),
            Tab(icon: Icon(Icons.people_outline), text: 'Kullanıcılar'),
            Tab(icon: Icon(Icons.hub_outlined), text: 'Edge'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _OverviewTab(
            loading: _loadingOverview,
            error: _overviewError,
            overview: _overview,
            onSubscriptionChange: _changeSubscription,
          ),
          _UsersTab(
            loading: _loadingUsers,
            error: _usersError,
            users: _users,
            onCreate: _createUser,
            onUpdate: _updateUser,
            onDelete: _deleteUser,
          ),
          _EdgeTab(overview: _overview, onRefresh: _refreshOverview),
        ],
      ),
    );
  }

  Future<void> _changeSubscription(String newStatus) async {
    try {
      await patchRestaurantSubscription(
        cloudBaseUrl: AppConfig.cloudBaseUrl,
        accessToken: widget.auth.accessToken!,
        restaurantId: widget.restaurantId,
        subscriptionStatus: newStatus,
      );
      await _refreshOverview();
    } catch (e) {
      _showSnack('Abonelik güncellenemedi: $e');
    }
  }

  Future<void> _createUser({
    required String email,
    required String password,
    required String role,
    required String? displayName,
  }) async {
    try {
      await createUser(
        cloudBaseUrl: AppConfig.cloudBaseUrl,
        accessToken: widget.auth.accessToken!,
        restaurantId: widget.restaurantId,
        email: email,
        password: password,
        role: role,
        displayName: displayName,
      );
      _showSnack('Kullanıcı oluşturuldu');
      await _refreshUsers();
    } catch (e) {
      _showSnack('Oluşturulamadı: $e');
    }
  }

  Future<void> _updateUser(
    String userId, {
    String? displayName,
    String? role,
    String? password,
  }) async {
    try {
      await updateUser(
        cloudBaseUrl: AppConfig.cloudBaseUrl,
        accessToken: widget.auth.accessToken!,
        userId: userId,
        displayName: displayName,
        role: role,
        password: password,
      );
      _showSnack('Kaydedildi');
      await _refreshUsers();
    } catch (e) {
      _showSnack('Güncellenemedi: $e');
    }
  }

  Future<void> _deleteUser(String userId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kullanıcıyı sil'),
        content: const Text('Bu işlem geri alınamaz. Devam edilsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await deleteUser(
        cloudBaseUrl: AppConfig.cloudBaseUrl,
        accessToken: widget.auth.accessToken!,
        userId: userId,
      );
      _showSnack('Silindi');
      await _refreshUsers();
    } catch (e) {
      _showSnack('Silinemedi: $e');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ===========================================================================
// Genel sekmesi
// ===========================================================================

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.loading,
    required this.error,
    required this.overview,
    required this.onSubscriptionChange,
  });

  final bool loading;
  final String? error;
  final RestaurantSummary? overview;
  final Future<void> Function(String) onSubscriptionChange;

  static const _statuses = ['DEMO', 'TRIAL', 'ACTIVE', 'FROZEN', 'CANCELED'];

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return _ErrorPanel(message: error!);
    }
    final r = overview!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kimlik', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                _kv(context, 'Restoran adı', r.name),
                _kv(context, 'Restoran ID', r.id, copyable: true),
                _kv(context, 'Abonelik', r.subscriptionStatus),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Abonelik durumu',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(
                  'Şu an: ${r.subscriptionStatus}. Değiştirmek için bir seçenek tıkla.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in _statuses)
                      if (s != r.subscriptionStatus)
                        OutlinedButton(
                          onPressed: () => onSubscriptionChange(s),
                          child: Text(s),
                        ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Widget _kv(BuildContext context, String k, String v, {bool copyable = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            k,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            v.isEmpty ? '-' : v,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        if (copyable && v.isNotEmpty)
          IconButton(
            tooltip: 'Kopyala',
            icon: const Icon(Icons.copy, size: 16),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: v));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Kopyalandı')),
              );
            },
          ),
      ],
    ),
  );
}

// ===========================================================================
// Kullanıcılar sekmesi
// ===========================================================================

class _UsersTab extends StatelessWidget {
  const _UsersTab({
    required this.loading,
    required this.error,
    required this.users,
    required this.onCreate,
    required this.onUpdate,
    required this.onDelete,
  });

  final bool loading;
  final String? error;
  final List<AdminUser> users;
  final Future<void> Function({
    required String email,
    required String password,
    required String role,
    required String? displayName,
  }) onCreate;
  final Future<void> Function(
    String userId, {
    String? displayName,
    String? role,
    String? password,
  }) onUpdate;
  final Future<void> Function(String userId) onDelete;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return _ErrorPanel(message: error!);
    return Stack(
      children: [
        if (users.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Bu restoran için henüz kullanıcı yok.\nSağ alttan + ile ekleyebilirsin.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: users.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final u = users[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      (u.displayName?.isNotEmpty ?? false)
                          ? u.displayName![0].toUpperCase()
                          : u.email[0].toUpperCase(),
                    ),
                  ),
                  title: Text(u.displayName ?? u.email),
                  subtitle: Text('${u.email} • ${u.roleLabel}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Düzenle',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _openEdit(context, u),
                      ),
                      IconButton(
                        tooltip: 'Sil',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => onDelete(u.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: () => _openCreate(context),
            icon: const Icon(Icons.person_add_alt),
            label: const Text('Kullanıcı Ekle'),
          ),
        ),
      ],
    );
  }

  void _openCreate(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _UserFormDialog(
        title: 'Yeni kullanıcı',
        onSave: (email, password, role, displayName) async {
          await onCreate(
            email: email,
            password: password!,
            role: role,
            displayName: displayName,
          );
          if (ctx.mounted) Navigator.of(ctx).pop();
        },
      ),
    );
  }

  void _openEdit(BuildContext context, AdminUser u) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _UserFormDialog(
        title: 'Kullanıcıyı düzenle',
        initial: u,
        onSave: (email, password, role, displayName) async {
          await onUpdate(
            u.id,
            displayName: displayName,
            role: role,
            password: (password?.isEmpty ?? true) ? null : password,
          );
          if (ctx.mounted) Navigator.of(ctx).pop();
        },
      ),
    );
  }
}

class _UserFormDialog extends StatefulWidget {
  const _UserFormDialog({
    required this.title,
    required this.onSave,
    this.initial,
  });

  final String title;
  final AdminUser? initial;
  final Future<void> Function(
    String email,
    String? password,
    String role,
    String? displayName,
  ) onSave;

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email;
  late final TextEditingController _password;
  late final TextEditingController _name;
  String _role = 'WAITER';
  bool _busy = false;
  String? _err;

  static const _roleOptions = [
    'RESTAURANT_ADMIN',
    'WAITER',
    'KITCHEN',
    'CASHIER',
  ];

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initial?.email ?? '');
    _password = TextEditingController();
    _name = TextEditingController(text: widget.initial?.displayName ?? '');
    _role = widget.initial?.role ?? 'WAITER';
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _email,
                enabled: !isEdit,
                decoration: const InputDecoration(
                  labelText: 'E-posta',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                validator: (v) => (v == null || !v.contains('@'))
                    ? 'Geçerli e-posta gir'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Görünen ad (opsiyonel)',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(
                  labelText: 'Rol',
                  prefixIcon: Icon(Icons.shield_outlined),
                ),
                items: [
                  for (final r in _roleOptions)
                    DropdownMenuItem(value: r, child: Text(_roleLabel(r))),
                ],
                onChanged: (v) => setState(() => _role = v ?? 'WAITER'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: isEdit
                      ? 'Yeni şifre (boş bırak = değiştirme)'
                      : 'Şifre',
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
                validator: (v) {
                  if (isEdit) {
                    if (v == null || v.isEmpty) return null;
                    if (v.length < 6) return 'En az 6 karakter';
                    return null;
                  }
                  if (v == null || v.length < 6) return 'En az 6 karakter';
                  return null;
                },
              ),
              if (_err != null) ...[
                const SizedBox(height: 8),
                Text(
                  _err!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  if (!(_formKey.currentState?.validate() ?? false)) return;
                  setState(() {
                    _busy = true;
                    _err = null;
                  });
                  try {
                    await widget.onSave(
                      _email.text.trim(),
                      _password.text,
                      _role,
                      _name.text.trim(),
                    );
                  } catch (e) {
                    if (mounted) {
                      setState(() {
                        _err = '$e';
                        _busy = false;
                      });
                    }
                  }
                },
          child: _busy
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(isEdit ? 'Kaydet' : 'Oluştur'),
        ),
      ],
    );
  }

  static String _roleLabel(String r) => switch (r) {
    'RESTAURANT_ADMIN' => 'Restoran Yöneticisi',
    'WAITER' => 'Garson',
    'KITCHEN' => 'Mutfak',
    'CASHIER' => 'Kasiyer',
    _ => r,
  };
}

// ===========================================================================
// Edge sekmesi
// ===========================================================================

class _EdgeTab extends StatelessWidget {
  const _EdgeTab({required this.overview, required this.onRefresh});

  final RestaurantSummary? overview;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (overview == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final r = overview!;
    final scheme = Theme.of(context).colorScheme;
    final color = switch (r.edgeStatus) {
      'ONLINE' => Colors.green.shade600,
      'OFFLINE' => Colors.orange.shade700,
      _ => Colors.grey.shade600,
    };
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: color.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.hub, color: color, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.edgeStatusLabel.toUpperCase(),
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(color: color, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        r.lastHelloAt == null
                            ? 'Edge bu restoran için hiç bağlanmadı.'
                            : 'Son sinyal: ${r.lastHelloAt}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Yenile',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edge bilgileri',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                _kv(context, 'Edge ID', r.edgeId ?? '-', copyable: r.edgeId != null),
                _kv(context, 'Tunnel URL', r.publicEdgeUrl ?? '-',
                    copyable: r.publicEdgeUrl != null),
                _kv(context, 'Yazılım sürümü', r.softwareVersion ?? '-'),
                _kv(context, 'Son sinyal', r.lastHelloAt ?? '-'),
                _kv(
                  context,
                  'Son sync ack',
                  r.lastAcknowledgedUpdatedAt ?? '-',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: scheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.construction_outlined, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Uzaktan komutlar',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Ping, Restart ve OTA güncelleme uzaktan komutları bir sonraki sürümle gelecek (V2 / V3).',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.network_ping),
                      label: const Text('Ping'),
                    ),
                    OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Yeniden başlat'),
                    ),
                    OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.system_update),
                      label: const Text('Güncelle'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                color: Theme.of(context).colorScheme.error, size: 36),
            const SizedBox(height: 12),
            SelectableText(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
