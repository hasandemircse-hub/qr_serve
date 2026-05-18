import 'package:flutter/material.dart';

import 'edge_staff_admin_api.dart';

class StaffAdminScreen extends StatefulWidget {
  const StaffAdminScreen({
    super.key,
    required this.edgeBaseUrl,
    required this.accessToken,
    required this.restaurantId,
  });

  final String edgeBaseUrl;
  final String? accessToken;
  final String restaurantId;

  @override
  State<StaffAdminScreen> createState() => _StaffAdminScreenState();
}

class _StaffAdminScreenState extends State<StaffAdminScreen> {
  late Future<StaffListPayload> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<StaffListPayload> _load() {
    return fetchStaffMembers(
      edgeBaseUrl: widget.edgeBaseUrl,
      accessToken: widget.accessToken,
      restaurantId: widget.restaurantId,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openStaffDialog({StaffMemberDto? staff}) async {
    if (_busy) return;
    final emailCtrl = TextEditingController(text: staff?.email ?? '');
    final nameCtrl = TextEditingController(text: staff?.displayName ?? '');
    final passwordCtrl = TextEditingController();
    var role = staff?.role ?? 'WAITER';
    final result = await showDialog<_StaffFormResult>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(staff == null ? 'Personel ekle' : 'Personeli düzenle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: emailCtrl,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'E-posta',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Görünen ad',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(
                    labelText: 'Rol',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'RESTAURANT_ADMIN',
                      child: Text('RESTORAN YÖNETİCİSİ'),
                    ),
                    DropdownMenuItem(value: 'WAITER', child: Text('GARSON')),
                    DropdownMenuItem(value: 'KITCHEN', child: Text('MUTFAK')),
                    DropdownMenuItem(value: 'CASHIER', child: Text('KASA')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => role = v);
                  },
                ),
                if (staff == null) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'İlk şifre',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
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
                final email = emailCtrl.text.trim();
                final password = passwordCtrl.text;
                if (email.isEmpty || !email.contains('@')) return;
                if (staff == null && password.length < 4) return;
                Navigator.pop(
                  ctx,
                  _StaffFormResult(
                    email: email,
                    displayName: nameCtrl.text.trim(),
                    role: role,
                    password: password,
                  ),
                );
              },
              child: Text(staff == null ? 'Ekle' : 'Kaydet'),
            ),
          ],
        ),
      ),
    );
    emailCtrl.dispose();
    nameCtrl.dispose();
    passwordCtrl.dispose();
    if (result == null) return;
    setState(() => _busy = true);
    try {
      if (staff == null) {
        await createStaffMember(
          edgeBaseUrl: widget.edgeBaseUrl,
          accessToken: widget.accessToken,
          restaurantId: widget.restaurantId,
          email: result.email,
          displayName: result.displayName,
          role: result.role,
          password: result.password,
        );
        if (mounted) _toast('Personel eklendi');
      } else {
        await updateStaffMember(
          edgeBaseUrl: widget.edgeBaseUrl,
          accessToken: widget.accessToken,
          restaurantId: widget.restaurantId,
          staffId: staff.id,
          email: result.email,
          displayName: result.displayName,
          role: result.role,
        );
        if (mounted) _toast('Personel güncellendi');
      }
      await _refresh();
    } catch (e) {
      if (mounted) _toast('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword(StaffMemberDto staff) async {
    if (_busy) return;
    final ctrl = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${staff.label} şifre'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Yeni şifre',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () {
              if (ctrl.text.length < 4) return;
              Navigator.pop(ctx, ctrl.text);
            },
            child: const Text('Güncelle'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (password == null) return;
    setState(() => _busy = true);
    try {
      await resetStaffPassword(
        edgeBaseUrl: widget.edgeBaseUrl,
        accessToken: widget.accessToken,
        restaurantId: widget.restaurantId,
        staffId: staff.id,
        password: password,
      );
      if (mounted) _toast('Şifre güncellendi');
    } catch (e) {
      if (mounted) _toast('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteStaff(StaffMemberDto staff) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Personeli sil'),
        content: Text('${staff.label} pasifleştirilecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await deleteStaffMember(
        edgeBaseUrl: widget.edgeBaseUrl,
        accessToken: widget.accessToken,
        restaurantId: widget.restaurantId,
        staffId: staff.id,
      );
      if (mounted) _toast('Personel silindi');
      await _refresh();
    } catch (e) {
      if (mounted) _toast('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Color _roleColor(ColorScheme scheme, String role) {
    return switch (role) {
      'RESTAURANT_ADMIN' => scheme.primary,
      'CASHIER' => Colors.teal.shade700,
      'WAITER' => Colors.indigo.shade700,
      'KITCHEN' => Colors.deepOrange.shade700,
      _ => scheme.outline,
    };
  }

  IconData _roleIcon(String role) {
    return switch (role) {
      'RESTAURANT_ADMIN' => Icons.admin_panel_settings_outlined,
      'CASHIER' => Icons.point_of_sale_outlined,
      'WAITER' => Icons.room_service_outlined,
      'KITCHEN' => Icons.soup_kitchen_outlined,
      _ => Icons.badge_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<StaffListPayload>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: scheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '${snap.error}',
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: _refresh,
                  child: const Text('Tekrar dene'),
                ),
              ],
            );
          }
          final staff = snap.data?.staff ?? [];
          if (staff.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : () => _openStaffDialog(),
                    icon: const Icon(Icons.person_add_alt_outlined),
                    label: const Text('Personel ekle'),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Kayıtlı personel yok.'),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: staff.length + 1,
            separatorBuilder: (_, index) => index == 0
                ? const SizedBox(height: 12)
                : const SizedBox(height: 8),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${staff.length} personel',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _openStaffDialog(),
                      icon: const Icon(Icons.person_add_alt_outlined),
                      label: const Text('Personel ekle'),
                    ),
                  ],
                );
              }
              final s = staff[i - 1];
              final color = _roleColor(scheme, s.role);
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.12),
                    child: Icon(_roleIcon(s.role), color: color),
                  ),
                  title: Text(s.label),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.email),
                      if (s.updatedAt != null)
                        Text('Güncelleme: ${s.updatedAt}'),
                    ],
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Chip(
                        label: Text(s.role),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: color.withValues(alpha: 0.12),
                        labelStyle: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      PopupMenuButton<String>(
                        enabled: !_busy,
                        onSelected: (v) {
                          switch (v) {
                            case 'edit':
                              _openStaffDialog(staff: s);
                            case 'password':
                              _resetPassword(s);
                            case 'delete':
                              _deleteStaff(s);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                          PopupMenuItem(
                            value: 'password',
                            child: Text('Şifre sıfırla'),
                          ),
                          PopupMenuItem(value: 'delete', child: Text('Sil')),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _StaffFormResult {
  const _StaffFormResult({
    required this.email,
    required this.displayName,
    required this.role,
    required this.password,
  });

  final String email;
  final String displayName;
  final String role;
  final String password;
}
