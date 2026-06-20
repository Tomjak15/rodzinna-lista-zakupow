import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/app_scope.dart';
import '../models/entities.dart';
import '../services/receipt_scanner.dart';
import '../utils/receipt_parser.dart';

class ReceiptsScreen extends StatefulWidget {
  const ReceiptsScreen({super.key});

  @override
  State<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen> {
  bool _scanning = false;

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final receipts = [...appState.data.activeReceipts]
      ..sort((a, b) => b.purchasedAt.compareTo(a.purchasedAt));

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          _ReceiptActions(
            scanning: _scanning,
            scannerSupported: receiptCameraScannerSupported,
            onScan: _scanReceipt,
            onManualAdd: () => _openReceiptEditor(context),
          ),
          const SizedBox(height: 12),
          if (receipts.isEmpty)
            const _EmptyReceipts()
          else
            ...receipts.map((receipt) => _ReceiptTile(receipt: receipt)),
        ],
      ),
      floatingActionButton: receiptCameraScannerSupported
          ? FloatingActionButton.extended(
              onPressed: _scanning ? null : _scanReceipt,
              icon: _scanning
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.document_scanner_outlined),
              label: const Text('Skanuj'),
            )
          : FloatingActionButton.extended(
              onPressed: () => _openReceiptEditor(context),
              icon: const Icon(Icons.add),
              label: const Text('Dodaj'),
            ),
    );
  }

  Future<void> _scanReceipt() async {
    if (!receiptCameraScannerSupported || _scanning) {
      return;
    }
    setState(() => _scanning = true);
    try {
      final result = await scanReceiptFromCamera();
      if (!mounted || result == null) {
        return;
      }
      final parsed = parseReceiptText(result.text);
      await _openReceiptEditor(
        context,
        initialItems: parsed.items,
        initialTotal: parsed.total,
        imageData: result.imageData,
        imageMimeType: result.imageMimeType,
      );
    } on ReceiptScanException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _scanning = false);
      }
    }
  }

  Future<void> _openReceiptEditor(
    BuildContext context, {
    List<ReceiptItem> initialItems = const [],
    double initialTotal = 0,
    String? imageData,
    String? imageMimeType,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ReceiptEditorSheet(
        initialItems: initialItems,
        initialTotal: initialTotal,
        imageData: imageData,
        imageMimeType: imageMimeType,
      ),
    );
  }
}

class _ReceiptActions extends StatelessWidget {
  const _ReceiptActions({
    required this.scanning,
    required this.scannerSupported,
    required this.onScan,
    required this.onManualAdd,
  });

  final bool scanning;
  final bool scannerSupported;
  final VoidCallback onScan;
  final VoidCallback onManualAdd;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: scannerSupported && !scanning ? onScan : null,
          icon: scanning
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.document_scanner_outlined),
          label: const Text('Skanuj paragon'),
        ),
        OutlinedButton.icon(
          onPressed: onManualAdd,
          icon: const Icon(Icons.add),
          label: const Text('Dodaj ręcznie'),
        ),
      ],
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
        leading: _ReceiptThumbnail(receipt: receipt),
        title: Text(receipt.storeName.isEmpty ? 'Sklep' : receipt.storeName),
        subtitle: Text(
          '${_formatMoney(receipt.total)} • '
          '${DateFormat('dd.MM.yyyy, HH:mm').format(receipt.purchasedAt.toLocal())}',
        ),
        children: [
          if (receipt.imageData != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _ReceiptPhotoPreview(imageData: receipt.imageData),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Produkty',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ),
          if (receipt.items.isEmpty)
            const ListTile(title: Text('Brak zapisanych produktów'))
          else
            ...receipt.items.map(
              (item) => ListTile(
                dense: true,
                title: Text(item.name),
                subtitle: Text(
                  '${formatQuantity(item.quantity)} ${item.unit} • '
                  '${_formatMoney(item.price)}',
                ),
              ),
            ),
          OverflowBar(
            children: [
              TextButton.icon(
                onPressed: receipt.items.isEmpty
                    ? null
                    : () async {
                        await appState.addReceiptItemsToShoppingList(receipt);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Dodano produkty do listy.'),
                            ),
                          );
                        }
                      },
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

class _ReceiptThumbnail extends StatelessWidget {
  const _ReceiptThumbnail({required this.receipt});

  final Receipt receipt;

  @override
  Widget build(BuildContext context) {
    final bytes = _decodeReceiptImage(receipt.imageData);
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 52,
        height: 52,
        color: scheme.surfaceContainerHighest,
        child: bytes == null
            ? Icon(Icons.receipt_long_outlined, color: scheme.onSurfaceVariant)
            : Image.memory(
                bytes,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.receipt_long_outlined,
                  color: scheme.onSurfaceVariant,
                ),
              ),
      ),
    );
  }
}

class _ReceiptEditorSheet extends StatefulWidget {
  const _ReceiptEditorSheet({
    required this.initialItems,
    required this.initialTotal,
    required this.imageData,
    required this.imageMimeType,
  });

  final List<ReceiptItem> initialItems;
  final double initialTotal;
  final String? imageData;
  final String? imageMimeType;

  @override
  State<_ReceiptEditorSheet> createState() => _ReceiptEditorSheetState();
}

class _ReceiptEditorSheetState extends State<_ReceiptEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _storeController = TextEditingController(text: 'Sklep');
  late final TextEditingController _totalController;
  late final TextEditingController _productsController;
  late ParsedReceipt _parsedProducts;

  @override
  void initState() {
    super.initState();
    _totalController = TextEditingController(
      text: widget.initialTotal > 0
          ? _formatPlainMoney(widget.initialTotal)
          : '',
    );
    _productsController = TextEditingController(
      text: widget.initialItems.map(_receiptItemToLine).join('\n'),
    );
    _parsedProducts = parseReceiptText(_productsController.text);
    _productsController.addListener(_refreshProducts);
  }

  @override
  void dispose() {
    _productsController.removeListener(_refreshProducts);
    _storeController.dispose();
    _totalController.dispose();
    _productsController.dispose();
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
                      'Zapisz paragon',
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
              if (widget.imageData != null) ...[
                const SizedBox(height: 8),
                _ReceiptPhotoPreview(imageData: widget.imageData),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _storeController,
                decoration: const InputDecoration(
                  labelText: 'Sklep',
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _totalController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Kwota',
                  prefixIcon: Icon(Icons.payments_outlined),
                  suffixText: 'zł',
                ),
                validator: (value) {
                  final amount = _parseMoney(value ?? '');
                  return amount <= 0 ? 'Wpisz kwotę' : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _productsController,
                minLines: 3,
                maxLines: 7,
                decoration: const InputDecoration(
                  labelText: 'Produkty',
                  hintText: 'Chleb 1 szt. 4,99',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.list_alt_outlined),
                ),
              ),
              const SizedBox(height: 12),
              _ParsedReceiptPreview(parsed: _parsedProducts),
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
      total: _parseMoney(_totalController.text),
      items: _parsedProducts.items,
      rawText: '',
      imageData: widget.imageData,
      imageMimeType: widget.imageMimeType,
    );
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _refreshProducts() {
    setState(() {
      _parsedProducts = parseReceiptText(_productsController.text);
    });
  }
}

class _ReceiptPhotoPreview extends StatelessWidget {
  const _ReceiptPhotoPreview({required this.imageData});

  final String? imageData;

  @override
  Widget build(BuildContext context) {
    final bytes = _decodeReceiptImage(imageData);
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 260),
        color: scheme.surfaceContainerHighest,
        child: bytes == null
            ? const SizedBox(
                height: 160,
                child: Center(child: Icon(Icons.receipt_long_outlined)),
              )
            : Image.memory(
                bytes,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox(
                  height: 160,
                  child: Center(child: Icon(Icons.broken_image_outlined)),
                ),
              ),
      ),
    );
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
            '${parsed.items.length} produktów • '
            '${_formatMoney(parsed.total)}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (parsed.items.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...parsed.items
                .take(6)
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

class _EmptyReceipts extends StatelessWidget {
  const _EmptyReceipts();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.document_scanner_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text('Brak paragonów', style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

Uint8List? _decodeReceiptImage(String? imageData) {
  final normalized = imageData?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  try {
    return base64Decode(normalized);
  } on FormatException {
    return null;
  }
}

String _receiptItemToLine(ReceiptItem item) {
  return '${item.name} ${formatQuantity(item.quantity)} ${item.unit} '
      '${_formatPlainMoney(item.price)}';
}

String _formatMoney(double value) {
  return NumberFormat.currency(locale: 'pl_PL', symbol: 'zł').format(value);
}

String _formatPlainMoney(double value) {
  return value.toStringAsFixed(2).replaceAll('.', ',');
}

double _parseMoney(String value) {
  final normalized = value
      .toLowerCase()
      .replaceAll('zł', '')
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll(',', '.');
  return double.tryParse(normalized) ?? 0;
}
