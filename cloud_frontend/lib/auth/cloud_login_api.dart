import 'dart:convert';

import 'package:http/http.dart' as http;

Future<String> loginToCloud({
  required String cloudBaseUrl,
  required String email,
  required String password,
}) async {
  final root = cloudBaseUrl.endsWith('/') ? cloudBaseUrl.substring(0, cloudBaseUrl.length - 1) : cloudBaseUrl;
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
