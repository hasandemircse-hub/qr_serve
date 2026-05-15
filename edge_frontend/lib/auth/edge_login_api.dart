import 'dart:convert';

import 'package:http/http.dart' as http;

Future<String> loginToEdge({
  required String edgeBaseUrl,
  required String email,
  required String password,
}) async {
  final root = edgeBaseUrl.endsWith('/') ? edgeBaseUrl.substring(0, edgeBaseUrl.length - 1) : edgeBaseUrl;
  final uri = Uri.parse('$root/api/v1/auth/login');
  final res = await http.post(
    uri,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'password': password}),
  );
  if (res.statusCode != 200) {
    throw Exception('Giriş başarısız (${res.statusCode})');
  }
  return res.body;
}
