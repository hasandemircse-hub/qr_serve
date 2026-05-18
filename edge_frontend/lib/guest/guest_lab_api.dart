import 'dart:convert';

import 'package:http/http.dart' as http;

class GuestLabPayload {
  GuestLabPayload({
    required this.tables,
    required this.lanHost,
    required this.phoneScanBaseUrl,
    this.suggestedGuestWebBaseUrl,
    required this.setupHint,
  });

  final List<GuestLabTableRow> tables;
  final String lanHost;
  final String phoneScanBaseUrl;
  final String? suggestedGuestWebBaseUrl;
  final String setupHint;
}

class GuestLabTableRow {
  GuestLabTableRow({
    required this.physicalTableId,
    required this.label,
    this.zone,
    this.seatCount,
    required this.qrTableId,
    required this.token,
    required this.edgeGuestPath,
    required this.edgeGuestUrl,
    required this.cloudGuestUrl,
    required this.phoneScanUrl,
  });

  final String physicalTableId;
  final String label;
  final String? zone;
  final int? seatCount;
  final String qrTableId;
  final String token;
  final String edgeGuestPath;
  final String edgeGuestUrl;
  final String cloudGuestUrl;
  final String phoneScanUrl;

  factory GuestLabTableRow.fromJson(Map<String, dynamic> j) {
    return GuestLabTableRow(
      physicalTableId: j['physicalTableId']?.toString() ?? '',
      label: j['label'] as String? ?? '',
      zone: j['zone'] as String?,
      seatCount: (j['seatCount'] as num?)?.toInt(),
      qrTableId: j['qrTableId']?.toString() ?? '',
      token: j['token'] as String? ?? '',
      edgeGuestPath: j['edgeGuestPath'] as String? ?? '',
      edgeGuestUrl: j['edgeGuestUrl'] as String? ?? '',
      cloudGuestUrl: j['cloudGuestUrl'] as String? ?? '',
      phoneScanUrl: j['phoneScanUrl'] as String? ?? j['cloudGuestUrl'] as String? ?? '',
    );
  }
}

Future<GuestLabPayload> fetchGuestLabTables({
  required String edgeBaseUrl,
  required String restaurantId,
}) async {
  final base = edgeBaseUrl.replaceAll(RegExp(r'/+$'), '');
  final uri = Uri.parse('$base/api/v1/guest/lab/restaurants/$restaurantId/tables');
  final res = await http.get(uri, headers: const {'Accept': 'application/json'});
  if (res.statusCode != 200) {
    throw Exception('Misafir lab ${res.statusCode}: ${res.body}');
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  final list = map['tables'] as List<dynamic>? ?? [];
  return GuestLabPayload(
    tables: list.map((e) => GuestLabTableRow.fromJson(e as Map<String, dynamic>)).toList(),
    lanHost: map['lanHost'] as String? ?? '',
    phoneScanBaseUrl: map['phoneScanBaseUrl'] as String? ?? '',
    suggestedGuestWebBaseUrl: map['suggestedGuestWebBaseUrl'] as String?,
    setupHint: map['setupHint'] as String? ?? '',
  );
}
