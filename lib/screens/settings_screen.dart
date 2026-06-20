import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/app_scope.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final lastSync = appState.lastSyncAt == null
        ? 'Jeszcze nie synchronizowano'
        : DateFormat('dd.MM.yyyy, HH:mm').format(appState.lastSyncAt!);

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      children: [
        Card(
          child: Column(
            children: [
              SwitchListTile(
                value: appState.online,
                onChanged: null,
                secondary: Icon(appState.online ? Icons.wifi : Icons.wifi_off),
                title: const Text('Internet'),
                subtitle: Text(appState.online ? 'Dostępny' : 'Offline'),
              ),
              const Divider(height: 1),
              SwitchListTile(
                value: appState.backendConfigured,
                onChanged: null,
                secondary: const Icon(Icons.dns_outlined),
                title: const Text('Serwer synchronizacji'),
                subtitle: Text(
                  appState.backendConfigured
                      ? 'Skonfigurowany'
                      : 'Nieskonfigurowany',
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Adres serwera'),
                subtitle: Text(
                  appState.serverUrl.isEmpty ? 'Brak' : appState.serverUrl,
                ),
                trailing: IconButton(
                  tooltip: 'Zmień adres',
                  onPressed: () => _editServerUrl(context),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ),
            ],
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Synchronizacja',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.schedule_outlined,
                  label: 'Oczekujące zmiany',
                  value: appState.pendingCount.toString(),
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.history,
                  label: 'Ostatnio',
                  value: lastSync,
                ),
                if (appState.lastSyncError != null) ...[
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.error_outline,
                    label: 'Błąd',
                    value: appState.lastSyncError!,
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: appState.syncing ? null : appState.syncNow,
                  icon: const Icon(Icons.sync),
                  label: const Text('Synchronizuj teraz'),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Urządzenie',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _confirmReset(context),
                  icon: const Icon(Icons.logout),
                  label: const Text('Wyczyść dane lokalne'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wyczyścić dane lokalne?'),
        content: const Text(
          'Aplikacja wróci do ekranu startowego na tym urządzeniu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Wyczyść'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await AppScope.of(context).resetLocalData();
    }
  }

  Future<void> _editServerUrl(BuildContext context) async {
    final appState = AppScope.of(context);
    final controller = TextEditingController(text: appState.serverUrl);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adres serwera'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'SERVER_URL',
            hintText: 'https://twoj-serwer.replit.app',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Wyczyść'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !context.mounted) {
      return;
    }
    await appState.updateServerUrl(value);
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              Text(value),
            ],
          ),
        ),
      ],
    );
  }
}
