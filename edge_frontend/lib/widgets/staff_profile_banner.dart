import 'package:flutter/material.dart';

import '../auth/auth_session.dart';

/// Rol ekranlarında kullanıcı ve bağlam özeti.
class StaffProfileBanner extends StatelessWidget {
  const StaffProfileBanner({
    super.key,
    required this.auth,
    required this.roleLabel,
    required this.icon,
    this.subtitle,
  });

  final AuthSession auth;
  final String roleLabel;
  final IconData icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: scheme.primaryContainer,
              child: Icon(icon, color: scheme.onPrimaryContainer, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    auth.displayName ?? 'Kullanıcı',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    auth.email ?? '—',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  if (auth.restaurantId != null) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Chip(
                          visualDensity: VisualDensity.compact,
                          avatar: Icon(Icons.storefront_outlined, size: 18, color: scheme.primary),
                          label: Text(
                            'Restoran ${auth.restaurantId!.substring(0, 8)}…',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(roleLabel, style: const TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        roleLabel,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
