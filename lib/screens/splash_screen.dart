import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../widgets/credits_bar.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    loadSavedLang().then((_) {
      if (mounted) setState(() => _loaded = true);
    });
  }

  void _go() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
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
          child: Column(
            children: [
              const Spacer(),
              Icon(Icons.auto_fix_high,
                  size: 88, color: cs.onPrimary),
              const SizedBox(height: 12),
              Text(
                tr('app_name'),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: cs.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  tr('tagline'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: cs.onPrimary.withOpacity(0.9)),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.onPrimary.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  tr('badge'),
                  style: TextStyle(
                      color: cs.onPrimary, fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(tr('choose_language'),
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      if (_loaded)
                        ValueListenableBuilder<AppLang>(
                          valueListenable: appLang,
                          builder: (context, lang, _) {
                            return Column(
                              children: [
                                RadioListTile<AppLang>(
                                  value: AppLang.en,
                                  groupValue: lang,
                                  onChanged: (v) => setLang(v!),
                                  title: Text(tr('english')),
                                ),
                                RadioListTile<AppLang>(
                                  value: AppLang.id,
                                  groupValue: lang,
                                  onChanged: (v) => setLang(v!),
                                  title: Text(tr('indonesian')),
                                ),
                              ],
                            );
                          },
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _loaded ? _go : null,
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(tr('continue')),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const CreditsBar(),
            ],
          ),
        ),
      ),
    );
  }
}
