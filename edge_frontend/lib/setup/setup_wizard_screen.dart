import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'edge_setup_api.dart';

/// İlk kurulum için basit adım sihirbazı (Edge `/api/v1/setup` ile konuşur).
class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key, required this.edgeBaseUrl});

  final String edgeBaseUrl;

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  int _page = 0;
  EdgeSetupStatus? _status;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await fetchEdgeSetupStatus(widget.edgeBaseUrl);
      if (!mounted) return;
      setState(() {
        _status = s;
        _loading = false;
      });
      if (!s.needsWizard && mounted) {
        context.go('/admin');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _persistStep(String step) async {
    await postWizardStep(widget.edgeBaseUrl, step);
  }

  Future<void> _finish() async {
    await postWizardComplete(widget.edgeBaseUrl);
    if (!mounted) return;
    context.go('/admin');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kurulum')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _reload, child: const Text('Yeniden dene')),
              ],
            ),
          ),
        ),
      );
    }

    final s = _status!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('İlk kurulum'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/admin'),
        ),
      ),
      body: Stepper(
        currentStep: _page,
        onStepContinue: () async {
          if (_page == 0) {
            await _persistStep('CLOUD_CHECK');
            setState(() => _page = 1);
          } else if (_page == 1) {
            await _persistStep('PRINTERS');
            setState(() => _page = 2);
          } else {
            await _finish();
          }
        },
        onStepCancel: () {
          if (_page > 0) {
            setState(() => _page -= 1);
          } else {
            context.go('/admin');
          }
        },
        steps: [
          Step(
            title: const Text('Hoş geldiniz'),
            content: const Text(
              'Bu sihirbaz Edge üzerindeki temel ayarları doğrular. '
              'Yazıcı IP ve Cloud adresi `config/quickserve-config.yaml` içindedir.',
            ),
            isActive: _page >= 0,
            state: _page > 0 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('Cloud bağlantısı'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mod: ${s.mode}'),
                const SizedBox(height: 8),
                Text('Cloud mock: ${s.cloudMock ? "evet (yerel geliştirme)" : "hayır"}'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      s.cloudReachable ? Icons.check_circle : Icons.error_outline,
                      color: s.cloudReachable ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.cloudReachable
                            ? 'Edge, Cloud uç noktasına ulaşabildi (veya mock aktif).'
                            : 'Cloud şu an ulaşılamıyor; ONLY_EDGE veya mock ile devam edebilirsiniz.',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            isActive: _page >= 1,
            state: _page > 1 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('Tamamla'),
            content: const Text(
              'Kurulumu bitirdiğinizde bu sihirbaz bir daha gösterilmez '
              '(Edge tarafında `setup_wizard_completed` işaretlenir).',
            ),
            isActive: _page >= 2,
            state: StepState.indexed,
          ),
        ],
      ),
    );
  }
}
