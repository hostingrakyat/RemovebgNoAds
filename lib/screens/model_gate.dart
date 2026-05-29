import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../services/segmentation_service.dart';
import 'splash_screen.dart';

/// Branded startup gate: detects / downloads the ML Kit model before the user
/// reaches the language screen, with a graceful "Continue anyway" escape so the
/// app is never stuck when offline.
class ModelGate extends StatefulWidget {
  const ModelGate({super.key});

  @override
  State<ModelGate> createState() => _ModelGateState();
}

class _ModelGateState extends State<ModelGate> {
  final SegmentationService _seg = SegmentationService();
  bool _ready = false;
  bool _showSkip = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _seg.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    await loadSavedLang();
    if (!mounted) return;
    setState(() {});
    // Reveal the "Continue anyway" escape after a few seconds.
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted && !_ready) setState(() => _showSkip = true);
    });
    // Patiently retry while the one-time model download completes.
    for (var attempt = 0; attempt < 40; attempt++) {
      final ok = await _seg.ensureReady();
      if (!mounted) return;
      if (ok) {
        setState(() => _ready = true);
        _next();
        return;
      }
      await Future.delayed(const Duration(seconds: 3));
    }
    if (mounted) setState(() => _showSkip = true);
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
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation(cs.onPrimary),
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
                  const SizedBox(height: 28),
                  AnimatedOpacity(
                    opacity: _showSkip ? 1 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: TextButton(
                      onPressed: _showSkip ? _next : null,
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
