import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/app_scope.dart';
import 'family_screen.dart';
import 'meals_screen.dart';
import 'settings_screen.dart';
import 'shopping_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _titles = ['Lista zakupów', 'Obiady', 'Rodzina', 'Ustawienia'];

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          IconButton(
            tooltip: 'Synchronizuj',
            onPressed: appState.syncing ? null : appState.syncNow,
            icon: appState.syncing
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
        ],
      ),
      body: Column(
        children: [
          const _SyncBanner(),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: const [
                ShoppingScreen(),
                MealsScreen(),
                FamilyScreen(),
                SettingsScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: 'Lista zakupów',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu),
            label: 'Obiady',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Rodzina',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Ustawienia',
          ),
        ],
      ),
    );
  }
}

class _SyncBanner extends StatelessWidget {
  const _SyncBanner();

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    IconData icon;
    String text;
    Color color;

    if (!appState.backendConfigured) {
      icon = Icons.cloud_off_outlined;
      text =
          'Tryb lokalny - skonfiguruj SERVER_URL, aby włączyć synchronizację.';
      color = scheme.tertiaryContainer;
    } else if (!appState.online) {
      icon = Icons.wifi_off_outlined;
      text = 'Offline - zmiany oczekują na synchronizację.';
      color = scheme.errorContainer;
    } else if (appState.syncing) {
      icon = Icons.sync;
      text = 'Synchronizacja...';
      color = scheme.secondaryContainer;
    } else if (appState.pendingCount > 0) {
      icon = Icons.schedule_outlined;
      text = '${appState.pendingCount} zmian oczekuje na synchronizację.';
      color = scheme.tertiaryContainer;
    } else {
      final lastSync = appState.lastSyncAt == null
          ? 'gotowe'
          : DateFormat('dd.MM, HH:mm').format(appState.lastSyncAt!);
      icon = Icons.cloud_done_outlined;
      text = 'Połączono z serwerem - ostatnia aktualizacja: $lastSync';
      color = scheme.primaryContainer;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: color,
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
