import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import 'calendar_screen.dart';
import 'family_screen.dart';
import 'health_screen.dart';
import 'meals_screen.dart';
import 'receipts_screen.dart';
import 'settings_screen.dart';
import 'shopping_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = [
    _ShellPage(
      title: 'Lista zakupów',
      icon: Icons.shopping_cart_outlined,
      selectedIcon: Icons.shopping_cart,
      child: ShoppingScreen(),
    ),
    _ShellPage(
      title: 'Przepisy',
      icon: Icons.restaurant_menu_outlined,
      selectedIcon: Icons.restaurant_menu,
      child: MealsScreen(),
    ),
    _ShellPage(
      title: 'Kalendarz',
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month,
      child: CalendarScreen(),
    ),
    _ShellPage(
      title: 'Zdrowie',
      icon: Icons.favorite_outline,
      selectedIcon: Icons.favorite,
      child: HealthScreen(),
    ),
    _ShellPage(
      title: 'Paragony',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
      child: ReceiptsScreen(),
    ),
    _ShellPage(
      title: 'Rodzina',
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups,
      child: FamilyScreen(),
    ),
    _ShellPage(
      title: 'Ustawienia',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      child: SettingsScreen(),
    ),
  ];

  static const _mainIndexes = [0, 1, 2, 3];
  static const _moreIndexes = [4, 5, 6];

  int get _navigationIndex {
    final mainIndex = _mainIndexes.indexOf(_index);
    return mainIndex == -1 ? _mainIndexes.length : mainIndex;
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final familyName = appState.data.family?.name ?? 'Rodzina';
    final page = _pages[_index];
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(page.title),
            Text(
              familyName,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton.filledTonal(
            tooltip: 'Synchronizuj',
            onPressed: appState.syncing ? null : appState.syncNow,
            icon: appState.syncing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: _pages.map((page) => page.child).toList(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navigationIndex,
        onDestinationSelected: _selectDestination,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: 'Lista',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu),
            label: 'Przepisy',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Plan',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: 'Zdrowie',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.apps),
            label: 'Więcej',
          ),
        ],
      ),
    );
  }

  void _selectDestination(int value) {
    if (value < _mainIndexes.length) {
      setState(() => _index = _mainIndexes[value]);
      return;
    }
    _openMoreSheet();
  }

  Future<void> _openMoreSheet() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Więcej',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 8),
                for (final index in _moreIndexes)
                  ListTile(
                    leading: Icon(
                      _index == index
                          ? _pages[index].selectedIcon
                          : _pages[index].icon,
                    ),
                    title: Text(_pages[index].title),
                    trailing: _index == index
                        ? const Icon(Icons.check_circle)
                        : const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(context, index),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null && mounted) {
      setState(() => _index = selected);
    }
  }
}

class _ShellPage {
  const _ShellPage({
    required this.title,
    required this.icon,
    required this.selectedIcon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final IconData selectedIcon;
  final Widget child;
}
