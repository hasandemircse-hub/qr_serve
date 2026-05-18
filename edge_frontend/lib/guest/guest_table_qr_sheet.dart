import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Masaya özel telefon QR — aynı WiFi'den okutulur.
Future<void> showGuestTableQrSheet(
  BuildContext context, {
  required String tableLabel,
  required String phoneScanUrl,
  required String restaurantId,
  required String qrTableId,
  required String token,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + MediaQuery.paddingOf(ctx).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Masa $tableLabel — telefonla okut',
            style: Theme.of(ctx).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Telefon aynı WiFi\'de olsun. Uzun URL yerine bu QR yeterli.',
            style: Theme.of(ctx).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: QrImageView(
                data: phoneScanUrl,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(
            phoneScanUrl,
            style: Theme.of(ctx).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: phoneScanUrl));
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Link kopyalandı')),
                    );
                  },
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Kopyala'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    final r = Uri.encodeQueryComponent(restaurantId);
                    final t = Uri.encodeQueryComponent(qrTableId);
                    final k = Uri.encodeQueryComponent(token);
                    context.push('/guest/qr?r=$r&t=$t&k=$k&via=cloud');
                  },
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('PC\'de aç'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
