import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/app_scope.dart';
import '../models/entities.dart';

class ShoppingScreen extends StatelessWidget {
  const ShoppingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final items = [...appState.data.activeShoppingItems]
      ..sort((a, b) {
        if (a.isPurchased != b.isPurchased) {
          return a.isPurchased ? 1 : -1;
        }
        return b.updatedAt.compareTo(a.updatedAt);
      });

    return Scaffold(
      body: items.isEmpty
          ? const _EmptyShoppingList()
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 96),
              itemCount: items.length,
              itemBuilder: (context, index) {
                return _ShoppingItemTile(item: items[index]);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openProductDialog(context),
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('Dodaj'),
      ),
    );
  }

  Future<void> _openProductDialog(
    BuildContext context, {
    ShoppingItem? item,
  }) async {
    final draft = await showDialog<_ProductDraft>(
      context: context,
      builder: (_) => _ProductDialog(item: item),
    );
    if (draft == null || !context.mounted) {
      return;
    }
    final appState = AppScope.of(context);
    if (item == null) {
      await appState.addShoppingItem(
        name: draft.name,
        quantity: draft.quantity,
        unit: draft.unit,
      );
    } else {
      await appState.updateShoppingItem(
        item: item,
        name: draft.name,
        quantity: draft.quantity,
        unit: draft.unit,
      );
    }
  }
}

class _ShoppingItemTile extends StatelessWidget {
  const _ShoppingItemTile({required this.item});

  final ShoppingItem item;

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final textStyle = item.isPurchased
        ? const TextStyle(
            decoration: TextDecoration.lineThrough,
            color: Colors.black45,
          )
        : null;

    return Card(
      child: ListTile(
        leading: Checkbox(
          value: item.isPurchased,
          onChanged: (_) => appState.toggleShoppingItem(item),
        ),
        title: Text(item.name, style: textStyle),
        subtitle: Text(
          '${formatQuantity(item.quantity)} ${item.unit} • ${item.authorName} • ${DateFormat('dd.MM, HH:mm').format(item.createdAt.toLocal())}',
          style: item.isPurchased
              ? const TextStyle(color: Colors.black45)
              : null,
        ),
        trailing: Wrap(
          spacing: 2,
          children: [
            _SyncIcon(status: item.syncStatus),
            IconButton(
              tooltip: 'Edytuj',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                final screen = context
                    .findAncestorWidgetOfExactType<ShoppingScreen>();
                if (screen != null) {
                  screen._openProductDialog(context, item: item);
                }
              },
            ),
            IconButton(
              tooltip: 'Usuń',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => appState.deleteShoppingItem(item),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncIcon extends StatelessWidget {
  const _SyncIcon({required this.status});

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
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Icon(
          status == SyncStatus.failed
              ? Icons.cloud_off_outlined
              : Icons.schedule_outlined,
          size: 20,
          color: status == SyncStatus.failed
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.secondary,
        ),
      ),
    );
  }
}

class _EmptyShoppingList extends StatelessWidget {
  const _EmptyShoppingList();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Lista jest pusta',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductDraft {
  const _ProductDraft({
    required this.name,
    required this.quantity,
    required this.unit,
  });

  final String name;
  final double quantity;
  final String unit;
}

class _ProductDialog extends StatefulWidget {
  const _ProductDialog({this.item});

  final ShoppingItem? item;

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _unitController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?.name ?? '');
    _quantityController = TextEditingController(
      text: widget.item == null ? '1' : formatQuantity(widget.item!.quantity),
    );
    _unitController = TextEditingController(text: widget.item?.unit ?? 'szt.');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? 'Dodaj produkt' : 'Edytuj produkt'),
      content: Form(
        key: _formKey,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Nazwa'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Wpisz nazwę'
                    : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Ilość'),
                      validator: (value) {
                        final parsed = _parseQuantity(value ?? '');
                        return parsed <= 0 ? 'Podaj ilość' : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _unitController,
                      decoration: const InputDecoration(labelText: 'Jednostka'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Anuluj'),
        ),
        FilledButton(onPressed: _save, child: const Text('Zapisz')),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.pop(
      context,
      _ProductDraft(
        name: _nameController.text.trim(),
        quantity: _parseQuantity(_quantityController.text),
        unit: _unitController.text.trim(),
      ),
    );
  }

  double _parseQuantity(String value) {
    return double.tryParse(value.replaceAll(',', '.')) ?? 0;
  }
}
