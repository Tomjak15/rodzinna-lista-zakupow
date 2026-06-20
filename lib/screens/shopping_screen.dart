import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/app_scope.dart';
import '../data/product_catalog.dart';
import '../models/entities.dart';

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _unitController = TextEditingController(text: 'szt.');

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_refreshSuggestions);
  }

  @override
  void dispose() {
    _nameController.removeListener(_refreshSuggestions);
    _nameController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final items = [...appState.data.activeShoppingItems]
      ..sort((a, b) {
        if (a.isPurchased != b.isPurchased) {
          return a.isPurchased ? 1 : -1;
        }
        return a.name.compareTo(b.name);
      });
    final openItems = items.where((item) => !item.isPurchased).toList();
    final purchasedItems = items.where((item) => item.isPurchased).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        _buildQuickAdd(context),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const _EmptyShoppingList()
        else ...[
          _ShoppingSection(title: 'Do kupienia', count: openItems.length),
          ...openItems.map(
            (item) => _ShoppingRow(
              item: item,
              onEdit: () => _openProductDialog(context, item: item),
            ),
          ),
          if (purchasedItems.isNotEmpty) ...[
            const SizedBox(height: 16),
            _ShoppingSection(title: 'Kupione', count: purchasedItems.length),
            ...purchasedItems.map(
              (item) => _ShoppingRow(
                item: item,
                onEdit: () => _openProductDialog(context, item: item),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildQuickAdd(BuildContext context) {
    final appData = AppScope.of(context).data;
    final visibleSuggestions = _visibleSuggestions(appData);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Produkt',
                        prefixIcon: Icon(Icons.search),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Wpisz produkt'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 86,
                    child: TextFormField(
                      controller: _quantityController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Ilość'),
                      validator: (value) =>
                          _parseQuantity(value ?? '') <= 0 ? 'Ilość' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 86,
                    child: TextFormField(
                      controller: _unitController,
                      decoration: const InputDecoration(labelText: 'Jedn.'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Dodaj',
                    onPressed: () => _addFromFields(context),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${visibleSuggestions.length} podpowiedzi',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: visibleSuggestions
                        .map(
                          (suggestion) => ActionChip(
                            avatar: const Icon(Icons.add, size: 16),
                            label: Text(suggestion.name),
                            onPressed: () =>
                                _addSuggestion(context, suggestion),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<ProductSuggestion> _visibleSuggestions(AppData data) {
    final query = _nameController.text.trim().toLowerCase();
    final suggestions = _allSuggestions(data);
    if (query.isEmpty) {
      return suggestions;
    }
    return suggestions
        .where((item) => item.name.toLowerCase().contains(query))
        .toList();
  }

  List<ProductSuggestion> _allSuggestions(AppData data) {
    final byName = <String, ProductSuggestion>{};

    void add(ProductSuggestion suggestion) {
      final name = suggestion.name.trim();
      if (name.isEmpty) {
        return;
      }
      final key = name.toLowerCase();
      byName.putIfAbsent(
        key,
        () => ProductSuggestion(
          name,
          suggestion.quantity <= 0 ? 1 : suggestion.quantity,
          suggestion.unit.trim().isEmpty ? 'szt.' : suggestion.unit.trim(),
        ),
      );
    }

    for (final suggestion in productCatalog) {
      add(suggestion);
    }
    for (final item in data.activeShoppingItems) {
      add(ProductSuggestion(item.name, item.quantity, item.unit));
    }
    for (final ingredient in data.activeRecipeIngredients) {
      add(
        ProductSuggestion(
          ingredient.name,
          ingredient.quantity,
          ingredient.unit,
        ),
      );
    }

    final result = byName.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  Future<void> _addFromFields(BuildContext context) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    await AppScope.of(context).addShoppingItem(
      name: _nameController.text.trim(),
      quantity: _parseQuantity(_quantityController.text),
      unit: _unitController.text.trim().isEmpty
          ? 'szt.'
          : _unitController.text.trim(),
    );
    _nameController.clear();
    _quantityController.text = '1';
    _unitController.text = 'szt.';
  }

  Future<void> _addSuggestion(
    BuildContext context,
    ProductSuggestion suggestion,
  ) async {
    await AppScope.of(context).addShoppingItem(
      name: suggestion.name,
      quantity: suggestion.quantity,
      unit: suggestion.unit,
    );
  }

  Future<void> _openProductDialog(
    BuildContext context, {
    required ShoppingItem item,
  }) async {
    final draft = await showDialog<_ProductDraft>(
      context: context,
      builder: (_) => _ProductDialog(item: item),
    );
    if (draft == null || !context.mounted) {
      return;
    }
    final appState = AppScope.of(context);
    await appState.updateShoppingItem(
      item: item,
      name: draft.name,
      quantity: draft.quantity,
      unit: draft.unit,
    );
  }

  void _refreshSuggestions() {
    setState(() {});
  }

  double _parseQuantity(String value) {
    return double.tryParse(value.replaceAll(',', '.')) ?? 0;
  }
}

class _ShoppingSection extends StatelessWidget {
  const _ShoppingSection({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
      child: Row(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShoppingRow extends StatelessWidget {
  const _ShoppingRow({required this.item, required this.onEdit});

  final ShoppingItem item;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textStyle = item.isPurchased
        ? TextStyle(
            decoration: TextDecoration.lineThrough,
            color: scheme.onSurfaceVariant,
          )
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: item.isPurchased ? scheme.surfaceContainerHighest : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5DDCE)),
      ),
      child: ListTile(
        dense: true,
        leading: Checkbox(
          value: item.isPurchased,
          onChanged: (_) => appState.toggleShoppingItem(item),
        ),
        title: Text(item.name, style: textStyle),
        subtitle: Text(
          '${formatQuantity(item.quantity)} ${item.unit} • ${item.authorName} • ${DateFormat('dd.MM, HH:mm').format(item.createdAt.toLocal())}',
          style: item.isPurchased
              ? TextStyle(color: scheme.onSurfaceVariant)
              : null,
        ),
        trailing: Wrap(
          spacing: 2,
          children: [
            _SyncIcon(status: item.syncStatus),
            IconButton(
              tooltip: 'Edytuj',
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
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
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.playlist_add_check_outlined,
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
  const _ProductDialog({required this.item});

  final ShoppingItem item;

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
    _nameController = TextEditingController(text: widget.item.name);
    _quantityController = TextEditingController(
      text: formatQuantity(widget.item.quantity),
    );
    _unitController = TextEditingController(text: widget.item.unit);
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
      title: const Text('Edytuj produkt'),
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
