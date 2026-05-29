import 'package:flutter/material.dart';

import 'l10n/strings.dart';
import 'screens/splash_screen.dart';

const Color kSeed = Color(0xFF6C4DF6);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadSavedLang();
  runApp(const RemovebgApp());
}

class RemovebgApp extends StatelessWidget {
  const RemovebgApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLang>(
      valueListenable: appLang,
      builder: (context, _, __) {
        return MaterialApp(
          title: 'Removebg No Ads',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: kSeed),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: kSeed,
              brightness: Brightness.dark,
            ),
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}
