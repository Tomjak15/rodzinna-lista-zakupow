import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/app_scope.dart';
import '../data/product_catalog.dart';
import '../models/entities.dart';
import '../utils/product_category.dart';
import '../utils/receipt_parser.dart';

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  bool _shopMode = false;

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final items = [...appState.data.activeShoppingItems]..sort(_compareItems);
    final openItems = items.where((item) => !item.isPurchased).toList();
    final purchasedItems = items.where((item) => item.isPurchased).toList();
    final visibleOpenItems = _shopMode ? openItems : openItems;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          _ShoppingToolbar(
            shopMode: _shopMode,
            onShopModeChanged: (value) => setState(() => _shopMode = value),
            onOpenFavorites: () => _openFavoritesSheet(context),
            onOpenReceipts: () => _openReceiptsSheet(context),
          ),
          if (_shopMode)
            _ShopModeBanner(
              count: openItems.length,
              onClose: () => setState(() => _shopMode = false),
            ),
          if (items.isEmpty)
            const _EmptyShoppingList()
          else if (_shopMode && openItems.isEmpty)
            const _AllDoneCard()
          else ...[
            _ShoppingSection(
              title: _shopMode ? 'Tryb sklepu' : 'Do kupienia',
              count: visibleOpenItems.length,
            ),
            ..._categoryWidgets(
              context: context,
              items: visibleOpenItems,
              shopMode: _shopMode,
              onEdit: (item) => _openProductDialog(context, item: item),
            ),
            if (!_shopMode && purchasedItems.isNotEmpty) ...[
              const SizedBox(height: 16),
              _ShoppingSection(title: 'Kupione', count: purchasedItems.length),
              ...purchasedItems.map(
                (item) => _ShoppingRow(
                  item: item,
                  shopMode: false,
                  onEdit: () => _openProductDialog(context, item: item),
                ),
              ),
            ],
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.large(
        tooltip: 'Dodaj produkt',
        onPressed: () => _openAddProductSheet(context),
        child: const Icon(Icons.add, size: 42),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  List<Widget> _categoryWidgets({
    required BuildContext context,
    required List<ShoppingItem> items,
    required bool shopMode,
    required ValueChanged<ShoppingItem> onEdit,
  }) {
    final grouped = <String, List<ShoppingItem>>{};
    for (final item in items) {
      final category = categoryForProduct(item.name);
      grouped.putIfAbsent(category, () => []).add(item);
    }

    final categories = grouped.keys.toList()..sort(_compareCategories);
    return [
      for (final category in categories) ...[
        _CategoryHeader(category: category, count: grouped[category]!.length),
        ...grouped[category]!.map(
          (item) => _ShoppingRow(
            item: item,
            shopMode: shopMode,
            onEdit: () => onEdit(item),
          ),
        ),
      ],
    ];
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

  Future<void> _openAddProductSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _AddProductSheet(),
    );
  }

  Future<void> _openFavoritesSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _FavoritesSheet(),
    );
  }

  Future<void> _openReceiptsSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _ReceiptsSheet(),
    );
  }
}

class _ShoppingToolbar extends StatelessWidget {
  const _ShoppingToolbar({
    required this.shopMode,
    required this.onShopModeChanged,
    required this.onOpenFavorites,
    required this.onOpenReceipts,
  });

  final bool shopMode;
  final ValueChanged<bool> onShopModeChanged;
  final VoidCallback onOpenFavorites;
  final VoidCallback onOpenReceipts;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilterChip(
            selected: shopMode,
            avatar: const Icon(Icons.storefront_outlined),
            label: const Text('Tryb sklepu'),
            onSelected: onShopModeChanged,
          ),
          FilledButton.tonalIcon(
            onPressed: onOpenFavorites,
            icon: const Icon(Icons.star_outline),
            label: const Text('Ulubione'),
          ),
          OutlinedButton.icon(
            onPressed: onOpenReceipts,
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Paragony'),
          ),
        ],
      ),
    );
  }
}

class _ShopModeBanner extends StatelessWidget {
  const _ShopModeBanner({required this.count, required this.onClose});

  final int count;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.shopping_cart_checkout, color: scheme.onPrimaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count do kupienia',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          TextButton(onPressed: onClose, child: const Text('Zakończ')),
        ],
      ),
    );
  }
}

class _AddProductSheet extends StatefulWidget {
  const _AddProductSheet();

  @override
  State<_AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends State<_AddProductSheet> {
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
    final query = _nameController.text.trim();
    final suggestions = _visibleSuggestions(AppScope.of(context).data, query);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Dodaj produkt',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Zamknij',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _nameController,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Produkt',
                      prefixIcon: Icon(Icons.search),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Wpisz produkt'
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 82,
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
                  width: 78,
                  child: TextFormField(
                    controller: _unitController,
                    decoration: const InputDecoration(labelText: 'Jedn.'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Dodaj',
                  onPressed: _addFromFields,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            if (query.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                suggestions.isEmpty
                    ? 'Brak podpowiedzi'
                    : '${suggestions.length} podpowiedzi',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: suggestions
                        .map(
                          (suggestion) => ActionChip(
                            avatar: Icon(
                              iconForCategory(
                                categoryForProduct(suggestion.name),
                              ),
                              size: 16,
                            ),
                            label: Text(suggestion.name),
                            onPressed: () => _addSuggestion(suggestion),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<ProductSuggestion> _visibleSuggestions(AppData data, String query) {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) {
      return [];
    }
    return _allSuggestions(
      data,
    ).where((item) => item.name.toLowerCase().contains(cleanQuery)).toList();
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
    for (final product in data.activeFavoriteProducts) {
      add(ProductSuggestion(product.name, product.quantity, product.unit));
    }
    for (final receipt in data.activeReceipts) {
      for (final item in receipt.items) {
        add(ProductSuggestion(item.name, item.quantity, item.unit));
      }
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

  Future<void> _addFromFields() async {
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
    _clearForNextProduct();
  }

  Future<void> _addSuggestion(ProductSuggestion suggestion) async {
    await AppScope.of(context).addShoppingItem(
      name: suggestion.name,
      quantity: suggestion.quantity,
      unit: suggestion.unit,
    );
    _clearForNextProduct();
  }

  void _clearForNextProduct() {
    _nameController.clear();
    _quantityController.text = '1';
    _unitController.text = 'szt.';
  }

  void _refreshSuggestions() {
    setState(() {});
  }

  double _parseQuantity(String value) {
    return double.tryParse(value.replaceAll(',', '.')) ?? 0;
  }
}

class _FavoritesSheet extends StatelessWidget {
  const _FavoritesSheet();

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final favorites = [...appState.data.activeFavoriteProducts]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Ulubione produkty',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Zamknij',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (favorites.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Brak ulubionych produktów'),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: favorites.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final product = favorites[index];
                    final category = categoryForProduct(product.name);
                    return ListTile(
                      leading: Icon(iconForCategory(category)),
                      title: Text(product.name),
                      subtitle: Text(
                        '${formatQuantity(product.quantity)} ${product.unit} • $category',
                      ),
                      trailing: Wrap(
                        spacing: 2,
                        children: [
                          IconButton(
                            tooltip: 'Dodaj do listy',
                            icon: const Icon(Icons.add_shopping_cart),
                            onPressed: () => appState
                                .addFavoriteProductToShoppingList(product),
                          ),
                          IconButton(
                            tooltip: 'Usuń z ulubionych',
                            icon: const Icon(Icons.star),
                            onPressed: () => appState.toggleFavoriteProduct(
                              name: product.name,
                              quantity: product.quantity,
                              unit: product.unit,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptsSheet extends StatelessWidget {
  const _ReceiptsSheet();

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final receipts = [...appState.data.activeReceipts]
      ..sort((a, b) => b.purchasedAt.compareTo(a.purchasedAt));
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Paragony',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Zamknij',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: () => _openReceiptScanSheet(context),
                icon: const Icon(Icons.document_scanner_outlined),
                label: const Text('Skanuj / wklej'),
              ),
            ),
            const SizedBox(height: 8),
            if (receipts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Brak zapisanych paragonów'),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: receipts.length,
                  itemBuilder: (context, index) {
                    final receipt = receipts[index];
                    return _ReceiptTile(receipt: receipt);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openReceiptScanSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _ReceiptScanSheet(),
    );
  }
}

class _ReceiptTile extends StatelessWidget {
  const _ReceiptTile({required this.receipt});

  final Receipt receipt;

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        leading: const Icon(Icons.receipt_long_outlined),
        title: Text(receipt.storeName.isEmpty ? 'Paragon' : receipt.storeName),
        subtitle: Text(
          '${DateFormat('dd.MM.yyyy, HH:mm').format(receipt.purchasedAt.toLocal())} • '
          '${receipt.items.length} produktów • ${_formatMoney(receipt.total)}',
        ),
        children: [
          if (receipt.items.isEmpty)
            const ListTile(title: Text('Brak odczytanych produktów'))
          else
            ...receipt.items
                .take(8)
                .map(
                  (item) => ListTile(
                    dense: true,
                    title: Text(item.name),
                    subtitle: Text(
                      '${formatQuantity(item.quantity)} ${item.unit} • ${_formatMoney(item.price)}',
                    ),
                  ),
                ),
          if (receipt.items.length > 8)
            ListTile(
              dense: true,
              title: Text('+${receipt.items.length - 8} więcej'),
            ),
          OverflowBar(
            children: [
              TextButton.icon(
                onPressed: receipt.items.isEmpty
                    ? null
                    : () => appState.addReceiptItemsToShoppingList(receipt),
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Do listy'),
              ),
              TextButton.icon(
                onPressed: () => appState.deleteReceipt(receipt),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Usuń'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReceiptScanSheet extends StatefulWidget {
  const _ReceiptScanSheet();

  @override
  State<_ReceiptScanSheet> createState() => _ReceiptScanSheetState();
}

class _ReceiptScanSheetState extends State<_ReceiptScanSheet> {
  final _formKey = GlobalKey<FormState>();
  final _storeController = TextEditingController(text: 'Sklep');
  final _rawController = TextEditingController();
  ParsedReceipt _parsed = const ParsedReceipt(items: [], total: 0);

  @override
  void initState() {
    super.initState();
    _rawController.addListener(_refreshParsed);
  }

  @override
  void dispose() {
    _rawController.removeListener(_refreshParsed);
    _storeController.dispose();
    _rawController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Skanuj / wklej paragon',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Zamknij',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _storeController,
                decoration: const InputDecoration(
                  labelText: 'Sklep',
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _rawController,
                minLines: 7,
                maxLines: 12,
                decoration: const InputDecoration(
                  labelText: 'Tekst paragonu',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.receipt_long_outlined),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Wklej tekst paragonu'
                    : null,
              ),
              const SizedBox(height: 12),
              _ParsedReceiptPreview(parsed: _parsed),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Zapisz paragon'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    await AppScope.of(context).addReceipt(
      storeName: _storeController.text,
      purchasedAt: DateTime.now(),
      total: _parsed.total,
      rawText: _rawController.text,
      items: _parsed.items,
    );
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _refreshParsed() {
    setState(() {
      _parsed = parseReceiptText(_rawController.text);
    });
  }
}

class _ParsedReceiptPreview extends StatelessWidget {
  const _ParsedReceiptPreview({required this.parsed});

  final ParsedReceipt parsed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${parsed.items.length} produktów • ${_formatMoney(parsed.total)}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (parsed.items.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...parsed.items
                .take(5)
                .map(
                  (item) => Text(
                    '${item.name} • ${formatQuantity(item.quantity)} ${item.unit}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
          ],
        ],
      ),
    );
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

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.category, required this.count});

  final String category;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
      child: Row(
        children: [
          Icon(iconForCategory(category), size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              category,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          Text('$count', style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _ShoppingRow extends StatelessWidget {
  const _ShoppingRow({
    required this.item,
    required this.shopMode,
    required this.onEdit,
  });

  final ShoppingItem item;
  final bool shopMode;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final category = categoryForProduct(item.name);
    final favorite = appState.isFavoriteProduct(item.name, item.unit);
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
        minVerticalPadding: shopMode ? 12 : 4,
        leading: Transform.scale(
          scale: shopMode ? 1.25 : 1,
          child: Checkbox(
            value: item.isPurchased,
            onChanged: (_) => appState.toggleShoppingItem(item),
          ),
        ),
        title: Text(item.name, style: textStyle),
        subtitle: Text(
          shopMode
              ? category
              : '${formatQuantity(item.quantity)} ${item.unit} • $category • '
                    '${item.authorName} • '
                    '${DateFormat('dd.MM, HH:mm').format(item.createdAt.toLocal())}',
          style: item.isPurchased
              ? TextStyle(color: scheme.onSurfaceVariant)
              : null,
        ),
        trailing: shopMode
            ? Text(
                '${formatQuantity(item.quantity)} ${item.unit}',
                style: Theme.of(context).textTheme.titleSmall,
              )
            : Wrap(
                spacing: 2,
                children: [
                  _SyncIcon(status: item.syncStatus),
                  IconButton(
                    tooltip: favorite
                        ? 'Usuń z ulubionych'
                        : 'Dodaj do ulubionych',
                    icon: Icon(favorite ? Icons.star : Icons.star_border),
                    onPressed: () => appState.toggleFavoriteProduct(
                      name: item.name,
                      quantity: item.quantity,
                      unit: item.unit,
                    ),
                  ),
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

class _AllDoneCard extends StatelessWidget {
  const _AllDoneCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.done_all, size: 64, color: scheme.primary),
          const SizedBox(height: 12),
          Text(
            'Wszystko kupione',
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

int _compareItems(ShoppingItem a, ShoppingItem b) {
  if (a.isPurchased != b.isPurchased) {
    return a.isPurchased ? 1 : -1;
  }
  final categoryCompare = _compareCategories(
    categoryForProduct(a.name),
    categoryForProduct(b.name),
  );
  if (categoryCompare != 0) {
    return categoryCompare;
  }
  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

int _compareCategories(String a, String b) {
  final order = [...productCategories.map((category) => category.name), 'Inne'];
  final first = order.indexOf(a);
  final second = order.indexOf(b);
  return (first == -1 ? order.length : first).compareTo(
    second == -1 ? order.length : second,
  );
}

String _formatMoney(double value) {
  return NumberFormat.currency(locale: 'pl_PL', symbol: 'zł').format(value);
}
