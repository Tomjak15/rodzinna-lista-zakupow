import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_scope.dart';
import '../models/entities.dart';

class FamilyScreen extends StatelessWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final family = appState.data.family;
    final currentMember = appState.data.currentMember;
    final members = appState.data.activeMembers
      ..sort((a, b) => a.name.compareTo(b.name));

    if (family == null) {
      return const SizedBox.shrink();
    }

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.home_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        family.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    _FamilySyncIcon(status: family.syncStatus),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Kod rodziny',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        family.code,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Kopiuj kod',
                      onPressed: () => _copyCode(context, family.code),
                      icon: const Icon(Icons.copy),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _confirmLeaveFamily(context),
                  icon: const Icon(Icons.logout),
                  label: const Text('Opuść rodzinę'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
          child: Text(
            'Członkowie',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ...members.map(
          (member) => _MemberTile(
            member: member,
            canRemove:
                appState.isFamilyCreator && member.id != currentMember?.id,
            onRemove: () => _confirmRemoveMember(context, member),
          ),
        ),
      ],
    );
  }

  Future<void> _copyCode(BuildContext context, String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Kod rodziny skopiowany')));
    }
  }

  Future<void> _confirmLeaveFamily(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Opuścić rodzinę?'),
        content: const Text(
          'Po opuszczeniu rodziny wrócisz do ekranu startowego. Dane rodziny znikną z tego urządzenia.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Opuść'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      await AppScope.of(context).leaveFamily();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _confirmRemoveMember(BuildContext context, Member member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wyrzucić osobę?'),
        content: Text(
          '${member.name} straci dostęp do tej rodziny po następnej synchronizacji.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Wyrzuć'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      await AppScope.of(context).removeFamilyMember(member);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.canRemove,
    required this.onRemove,
  });

  final Member member;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final details = [
      if (member.email != null) member.email!,
      if (member.phone != null) member.phone!,
    ].join(' • ');
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(_avatarText(member))),
        title: Text(member.name),
        subtitle: details.isEmpty ? null : Text(details),
        trailing: Wrap(
          spacing: 2,
          children: [
            _FamilySyncIcon(status: member.syncStatus),
            if (canRemove)
              IconButton(
                tooltip: 'Wyrzuć z rodziny',
                onPressed: onRemove,
                icon: const Icon(Icons.person_remove_outlined),
              ),
          ],
        ),
      ),
    );
  }

  String _avatarText(Member member) {
    final source = member.avatar?.trim().isNotEmpty == true
        ? member.avatar!.trim()
        : member.name.trim();
    return source.isEmpty ? '?' : source.characters.first.toUpperCase();
  }
}

class _FamilySyncIcon extends StatelessWidget {
  const _FamilySyncIcon({required this.status});

  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    if (status == SyncStatus.synced) {
      return const SizedBox.shrink();
    }
    return Tooltip(
      message: status == SyncStatus.failed
          ? 'Nie udało się zsynchronizować'
          : 'Oczekuje na synchronizację',
      child: Icon(
        status == SyncStatus.failed
            ? Icons.cloud_off_outlined
            : Icons.schedule_outlined,
        color: status == SyncStatus.failed
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.secondary,
      ),
    );
  }
}
