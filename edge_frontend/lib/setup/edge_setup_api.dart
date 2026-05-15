import 'dart:convert';

import 'package:http/http.dart' as http;

class EdgeSetupStatus {
  EdgeSetupStatus({
    required this.needsWizard,
    required this.currentStep,
    required this.cloudReachable,
    required this.edgeId,
    required this.restaurantId,
    required this.cloudMock,
    required this.mode,
  });

  final bool needsWizard;
  final String? currentStep;
  final bool cloudReachable;
  final String? edgeId;
  final String? restaurantId;
  final bool cloudMock;
  final String mode;

  factory EdgeSetupStatus.fromJson(Map<String, dynamic> json) {
    return EdgeSetupStatus(
      needsWizard: json['needsWizard'] as bool? ?? false,
      currentStep: json['currentStep'] as String?,
      cloudReachable: json['cloudReachable'] as bool? ?? false,
      edgeId: json['edgeId'] as String?,
      restaurantId: json['restaurantId'] as String?,
      cloudMock: json['cloudMock'] as bool? ?? false,
      mode: json['mode'] as String? ?? 'FULL_STACK',
    );
  }
}

Future<EdgeSetupStatus> fetchEdgeSetupStatus(String edgeBaseUrl) async {
  final uri = Uri.parse(edgeBaseUrl).replace(path: '/api/v1/setup/status');
  final res = await http.get(uri);
  if (res.statusCode != 200) {
    throw Exception('Setup status ${res.statusCode}: ${res.body}');
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return EdgeSetupStatus.fromJson(map);
}

Future<void> postWizardStep(String edgeBaseUrl, String step) async {
  final uri = Uri.parse(edgeBaseUrl).replace(path: '/api/v1/setup/wizard/step');
  final res = await http.post(
    uri,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'step': step}),
  );
  if (res.statusCode != 204) {
    throw Exception('Wizard step ${res.statusCode}: ${res.body}');
  }
}

Future<void> postWizardComplete(String edgeBaseUrl) async {
  final uri = Uri.parse(edgeBaseUrl).replace(path: '/api/v1/setup/wizard/complete');
  final res = await http.post(uri);
  if (res.statusCode != 204) {
    throw Exception('Wizard complete ${res.statusCode}: ${res.body}');
  }
}
