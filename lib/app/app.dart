import 'package:flutter/material.dart';

import '../screens/home_shell.dart';
import '../screens/onboarding_screen.dart';
import 'app_scope.dart';
import 'app_state.dart';

class RodzinnaListaApp extends StatelessWidget {
  const RodzinnaListaApp({required this.appState, super.key});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      appState: appState,
      child: AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Rodzinna Lista Zakupów',
            theme: _buildTheme(),
            home: appState.hasFamily
                ? const HomeShell()
                : const OnboardingScreen(),
          );
        },
      ),
    );
  }

  ThemeData _buildTheme() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF2F7D5A),
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF2F7D5A),
          secondary: const Color(0xFFE07A5F),
          tertiary: const Color(0xFFF2CC5D),
          surface: const Color(0xFFFFFCF4),
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFFBF8EF),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: Color(0xFFFBF8EF),
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: Color(0xFFE5DDCE)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
