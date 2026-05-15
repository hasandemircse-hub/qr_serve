import 'package:flutter/material.dart';

import '../auth/cloud_auth_session.dart';
import '../auth/cloud_login_api.dart';
import '../config/app_config.dart';

class CloudLoginScreen extends StatefulWidget {
  const CloudLoginScreen({super.key, required this.auth});

  final CloudAuthSession auth;

  @override
  State<CloudLoginScreen> createState() => _CloudLoginScreenState();
}

class _CloudLoginScreenState extends State<CloudLoginScreen> {
  final _email = TextEditingController(text: 'superadmin@quickserve.local');
  final _password = TextEditingController(text: 'demo');
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final body = await loginToCloud(
        cloudBaseUrl: AppConfig.cloudBaseUrl,
        email: _email.text.trim(),
        password: _password.text,
      );
      await widget.auth.signInFromLoginJson(body);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.cloud_outlined, size: 56, color: scheme.primary),
                      const SizedBox(height: 12),
                      Text(
                        'QuickServe Cloud',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Text(
                        'Merkez yönetim',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                      Text(
                        AppConfig.cloudBaseUrl,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 24),
                      Card(
                        elevation: 0,
                        color: scheme.surfaceContainerHighest,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _email,
                                decoration: const InputDecoration(
                                  labelText: 'E-posta',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.alternate_email),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                autocorrect: false,
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _password,
                                decoration: const InputDecoration(
                                  labelText: 'Şifre',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.lock_outline),
                                ),
                                obscureText: true,
                                onSubmitted: (_) {
                                  if (!_busy) _submit();
                                },
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 12),
                                Text(_error!, style: TextStyle(color: scheme.error)),
                              ],
                              const SizedBox(height: 20),
                              FilledButton(
                                onPressed: _busy ? null : _submit,
                                child: _busy
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Text('Giriş yap'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Yerel demo: superadmin@quickserve.local / demo\n'
                        'Restoran personeli → QuickServe Edge (edge_frontend).',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
