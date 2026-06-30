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
          seedColor: const Color(0xFF24715A),
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF24715A),
          secondary: const Color(0xFFB86B45),
          tertiary: const Color(0xFF6C7A2F),
          surface: const Color(0xFFFFFCF7),
          surfaceContainerHighest: const Color(0xFFF0ECE2),
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFFAF7EF),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: Color(0xFFFAF7EF),
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
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: Color(0xFFE5DDCE)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: scheme.primaryContainer,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: const BorderSide(color: Color(0xFFE5DDCE)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
