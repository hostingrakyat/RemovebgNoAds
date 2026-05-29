import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../services/model_installer.dart';
import 'splash_screen.dart';

/// Branded startup gate: explicitly downloads / detects the ML Kit model via the
/// native Play Services ModuleInstallClient before the language screen, with a
/// progress bar and a "Continue anyway" escape so the app is never stuck.
class ModelGate extends StatefulWidget {
  const ModelGate({super.key});

  @override
  State<ModelGate> createState() => _ModelGateState();
}

class _ModelGateState extends State<ModelGate> {
  int _progress = -1;
  bool _failed = false;
  bool _showSkip = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _failed = false;
      _showSkip = false;
      _progress = -1;
    });
    await loadSavedLang();
    if (!mounted) return;

    if (await ModelInstaller.isAvailable()) {
      _next();
      return;
    }

    Future.delayed(const Duration(seconds: 6), () {
      if (mounted && !_navigated) setState(() => _showSkip = true);
    });

    await ModelInstaller.requestInstall();

    // Poll for completion (~3 min budget).
    for (var i = 0; i < 90; i++) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      if (await ModelInstaller.isAvailable()) {
        _next();
        return;
      }
      final p = await ModelInstaller.progress();
      if (mounted) setState(() => _progress = p);
      if (await ModelInstaller.failed()) {
        if (mounted) setState(() => _failed = true);
        return;
      }
    }
    if (mounted) setState(() => _failed = true);
  }

  void _next() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [cs.primary, cs.tertiary],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _GlassIcon(color: cs.onPrimary),
                  const SizedBox(height: 24),
                  Text(
                    tr('app_name'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: cs.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 40),
                  if (!_failed) ...[
                    SizedBox(
                      width: 200,
                      child: _progress >= 0
                          ? Column(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: _progress / 100.0,
                                    minHeight: 8,
                                    backgroundColor:
                                        cs.onPrimary.withOpacity(0.2),
                                    valueColor:
                                        AlwaysStoppedAnimation(cs.onPrimary),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text('$_progress%',
                                    style: TextStyle(color: cs.onPrimary)),
                              ],
                            )
                          : SizedBox(
                              height: 28,
                              width: 28,
                              child: Center(
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor:
                                        AlwaysStoppedAnimation(cs.onPrimary),
                                  ),
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      tr('downloading_model'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: cs.onPrimary, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tr('downloading_model_sub'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: cs.onPrimary.withOpacity(0.8), fontSize: 12),
                    ),
                  ] else ...[
                    Icon(Icons.cloud_off,
                        size: 44, color: cs.onPrimary.withOpacity(0.9)),
                    const SizedBox(height: 16),
                    Text(
                      tr('model_error'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onPrimary),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.onPrimary,
                        foregroundColor: cs.primary,
                      ),
                      onPressed: _start,
                      child: Text(tr('retry')),
                    ),
                  ],
                  const SizedBox(height: 28),
                  AnimatedOpacity(
                    opacity: (_showSkip || _failed) ? 1 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: TextButton(
                      onPressed: (_showSkip || _failed) ? _next : null,
                      style: TextButton.styleFrom(foregroundColor: cs.onPrimary),
                      child: Text('${tr('continue_anyway')}  →'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassIcon extends StatelessWidget {
  const _GlassIcon({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.30), width: 1.5),
      ),
      child: Icon(Icons.auto_fix_high, size: 60, color: color),
    );
  }
}
