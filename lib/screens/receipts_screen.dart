import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/app_scope.dart';
import '../models/entities.dart';
import '../services/receipt_ai_service.dart';
import '../services/receipt_scanner.dart';
import '../utils/receipt_parser.dart';
import '../utils/scan_hints.dart';

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
      final appState = AppScope.of(context);
      final result = await scanReceiptFromCamera();
      if (!mounted || result == null) {
        return;
      }
      final localParsed = parseReceiptText(result.text);
      var parsed = localParsed;
      String? scanNotice;

      if (appState.backendConfigured) {
        final service = ReceiptAiService(appState.serverUrl);
        try {
          final serverParsed = await service.scanReceipt(
            text: result.text,
            imageData: result.imageData,
            imageMimeType: result.imageMimeType,
            hints: buildProductScanHints(appState.data),
          );
          if (_receiptParseScore(localParsed) >
              _receiptParseScore(serverParsed)) {
            parsed = localParsed;
            scanNotice ??=
                'Serwer zwrócił słabszy odczyt niż lokalny OCR. Sprawdź dane przed zapisem.';
          } else {
            parsed = serverParsed;
          }
        } on ReceiptAiException catch (error) {
          scanNotice =
              'Serwer nie odczytał paragonu automatycznie. Używam lokalnego OCR: ${error.message}';
        } finally {
          service.dispose();
        }
      }

      if (parsed.items.isEmpty && parsed.total <= 0) {
        scanNotice ??=
            'Nie rozpoznano produktów ani kwoty. Zdjęcie zostanie zapisane, popraw dane ręcznie.';
      } else if (parsed.items.isEmpty) {
        scanNotice ??=
            'Nie rozpoznano produktów. Kwotę i sklep możesz zostawić, produkty dopisz ręcznie.';
      } else if (parsed.total <= 0) {
        scanNotice ??=
            'Nie rozpoznano kwoty. Produkty są wczytane, wpisz kwotę.';
      }

      if (!mounted) {
        return;
      }
      await _openReceiptEditor(
        context,
        initialStoreName: parsed.storeName,
        initialItems: parsed.items,
        initialTotal: parsed.total,
        imageData: result.imageData,
        imageMimeType: result.imageMimeType,
        scanNotice: scanNotice,
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
    String? initialStoreName,
    List<ReceiptItem> initialItems = const [],
    double initialTotal = 0,
    String? imageData,
    String? imageMimeType,
    String? scanNotice,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ReceiptEditorSheet(
        initialStoreName: initialStoreName,
        initialItems: initialItems,
        initialTotal: initialTotal,
        imageData: imageData,
        imageMimeType: imageMimeType,
        scanNotice: scanNotice,
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
    final hasPhoto = _decodeReceiptImage(receipt.imageData) != null;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          ListTile(
            leading: _ReceiptThumbnail(receipt: receipt),
            title: Text(
              receipt.storeName.isEmpty ? 'Sklep' : receipt.storeName,
            ),
            subtitle: Text(
              '${_formatMoney(receipt.total)} - '
              '${DateFormat('dd.MM.yyyy, HH:mm').format(receipt.purchasedAt.toLocal())}',
            ),
            onTap: hasPhoto ? () => _showReceiptPhoto(context, receipt) : null,
            trailing: hasPhoto
                ? const Icon(Icons.zoom_out_map_outlined)
                : IconButton(
                    tooltip: 'Usuń',
                    onPressed: () => appState.deleteReceipt(receipt),
                    icon: const Icon(Icons.delete_outline),
                  ),
          ),
          ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            title: Text('Produkty (${receipt.items.length})'),
            subtitle: hasPhoto
                ? const Text('Dotknij paragonu wyżej, żeby zobaczyć zdjęcie')
                : null,
            children: [
              if (receipt.items.isEmpty)
                const ListTile(title: Text('Brak zapisanych produktów'))
              else
                ...receipt.items.map(
                  (item) => ListTile(
                    dense: true,
                    title: Text(item.name),
                    subtitle: Text(
                      '${formatQuantity(item.quantity)} ${item.unit} - '
                      '${_formatMoney(item.price)}',
                    ),
                  ),
                ),
              OverflowBar(
                children: [
                  TextButton.icon(
                    onPressed: hasPhoto
                        ? () => _showReceiptPhoto(context, receipt)
                        : null,
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Zdjęcie'),
                  ),
                  TextButton.icon(
                    onPressed: receipt.items.isEmpty
                        ? null
                        : () async {
                            final excludedIndexes =
                                await _openReceiptShoppingSelection(
                                  context,
                                  receipt,
                                );
                            if (excludedIndexes == null || !context.mounted) {
                              return;
                            }
                            final addedCount = await appState
                                .addReceiptItemsToShoppingList(
                                  receipt,
                                  excludedIndexes: excludedIndexes,
                                );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Dodano $addedCount produktów do listy.',
                                  ),
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
        ],
      ),
    );
  }
}

Future<Set<int>?> _openReceiptShoppingSelection(
  BuildContext context,
  Receipt receipt,
) {
  return showDialog<Set<int>>(
    context: context,
    builder: (_) => _ReceiptShoppingSelectionDialog(receipt: receipt),
  );
}

class _ReceiptShoppingSelectionDialog extends StatefulWidget {
  const _ReceiptShoppingSelectionDialog({required this.receipt});

  final Receipt receipt;

  @override
  State<_ReceiptShoppingSelectionDialog> createState() =>
      _ReceiptShoppingSelectionDialogState();
}

class _ReceiptShoppingSelectionDialogState
    extends State<_ReceiptShoppingSelectionDialog> {
  final Set<int> _excludedIndexes = {};

  @override
  Widget build(BuildContext context) {
    final items = widget.receipt.items;
    final includedCount = items.length - _excludedIndexes.length;
    return AlertDialog(
      title: const Text('Dodaj produkty'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Zaznacz produkty, których nie chcesz dodawać.'),
              const SizedBox(height: 8),
              ...List.generate(items.length, (index) {
                final item = items[index];
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _excludedIndexes.contains(index),
                  onChanged: (value) {
                    setState(() {
                      if (value ?? false) {
                        _excludedIndexes.add(index);
                      } else {
                        _excludedIndexes.remove(index);
                      }
                    });
                  },
                  title: Text(item.name),
                  subtitle: Text(
                    '${formatQuantity(item.quantity)} ${item.unit} - ${_formatMoney(item.price)}',
                  ),
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Anuluj'),
        ),
        FilledButton(
          onPressed: includedCount <= 0
              ? null
              : () => Navigator.pop(context, _excludedIndexes),
          child: Text('Dodaj $includedCount'),
        ),
      ],
    );
  }
}

void _showReceiptPhoto(BuildContext context, Receipt receipt) {
  _showReceiptPhotoData(
    context,
    imageData: receipt.imageData,
    title: receipt.storeName.isEmpty ? 'Paragon' : receipt.storeName,
    subtitle: _formatMoney(receipt.total),
  );
}

void _showReceiptPhotoData(
  BuildContext context, {
  required String? imageData,
  required String title,
  String? subtitle,
}) {
  final bytes = _decodeReceiptImage(imageData);
  if (bytes == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nie udało się otworzyć zdjęcia paragonu.')),
    );
    return;
  }
  showDialog<void>(
    context: context,
    builder: (context) => Dialog.fullscreen(
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              title: Text(title),
              subtitle: subtitle == null ? null : Text(subtitle),
              trailing: IconButton(
                tooltip: 'Zamknij',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
            Expanded(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5,
                child: Center(
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
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
    required this.initialStoreName,
    required this.initialItems,
    required this.initialTotal,
    required this.imageData,
    required this.imageMimeType,
    required this.scanNotice,
  });

  final String? initialStoreName;
  final List<ReceiptItem> initialItems;
  final double initialTotal;
  final String? imageData;
  final String? imageMimeType;
  final String? scanNotice;

  @override
  State<_ReceiptEditorSheet> createState() => _ReceiptEditorSheetState();
}

class _ReceiptEditorSheetState extends State<_ReceiptEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _storeController;
  late final TextEditingController _totalController;
  late final List<_ReceiptItemController> _itemLines;

  @override
  void initState() {
    super.initState();
    _storeController = TextEditingController(
      text: widget.initialStoreName?.trim().isNotEmpty == true
          ? widget.initialStoreName!.trim()
          : 'Sklep',
    );
    _totalController = TextEditingController(
      text: widget.initialTotal > 0
          ? _formatPlainMoney(widget.initialTotal)
          : '',
    );
    _itemLines = widget.initialItems
        .map((item) => _ReceiptItemController.from(item))
        .toList();
  }

  @override
  void dispose() {
    _storeController.dispose();
    _totalController.dispose();
    for (final line in _itemLines) {
      line.dispose();
    }
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
                _ReceiptPhotoPreview(
                  imageData: widget.imageData,
                  onTap: () => _showReceiptPhotoData(
                    context,
                    imageData: widget.imageData,
                    title: _storeController.text.trim().isEmpty
                        ? 'Paragon'
                        : _storeController.text.trim(),
                    subtitle: _totalController.text.trim().isEmpty
                        ? null
                        : '${_totalController.text.trim()} zł',
                  ),
                ),
              ],
              if (widget.scanNotice != null) ...[
                const SizedBox(height: 12),
                _ScanNotice(message: widget.scanNotice!),
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
              _ReceiptItemsEditor(
                lines: _itemLines,
                onAdd: _addItemLine,
                onRemove: _removeItemLine,
                onChanged: _refreshItems,
              ),
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
    final items = _itemLines
        .map((line) => line.toItem())
        .whereType<ReceiptItem>()
        .toList();
    await AppScope.of(context).addReceipt(
      storeName: _storeController.text,
      purchasedAt: DateTime.now(),
      total: _parseMoney(_totalController.text),
      items: items,
      rawText: '',
      imageData: widget.imageData,
      imageMimeType: widget.imageMimeType,
    );
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _addItemLine() {
    setState(() {
      _itemLines.add(_ReceiptItemController());
    });
  }

  void _removeItemLine(int index) {
    setState(() {
      final removed = _itemLines.removeAt(index);
      removed.dispose();
    });
  }

  void _refreshItems() {
    setState(() {});
  }
}

class _ReceiptPhotoPreview extends StatelessWidget {
  const _ReceiptPhotoPreview({required this.imageData, this.onTap});

  final String? imageData;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bytes = _decodeReceiptImage(imageData);
    final scheme = Theme.of(context).colorScheme;
    final preview = ClipRRect(
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
    if (onTap == null || bytes == null) {
      return preview;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Stack(
          children: [
            preview,
            Positioned(
              right: 8,
              bottom: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.zoom_out_map, size: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanNotice extends StatelessWidget {
  const _ScanNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: scheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptItemsEditor extends StatelessWidget {
  const _ReceiptItemsEditor({
    required this.lines,
    required this.onAdd,
    required this.onRemove,
    required this.onChanged,
  });

  final List<_ReceiptItemController> lines;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final items = lines
        .map((line) => line.toItem())
        .whereType<ReceiptItem>()
        .toList();
    final total = items.fold<double>(0, (sum, item) => sum + item.price);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Produkty z paragonu',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Text(
              '${items.length} - ${_formatMoney(total)}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (lines.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5DDCE)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Brak rozpoznanych produktów'),
          )
        else
          ...List.generate(
            lines.length,
            (index) => _ReceiptItemLineEditor(
              line: lines[index],
              onRemove: () => onRemove(index),
              onChanged: onChanged,
            ),
          ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Dodaj produkt'),
          ),
        ),
      ],
    );
  }
}

class _ReceiptItemLineEditor extends StatelessWidget {
  const _ReceiptItemLineEditor({
    required this.line,
    required this.onRemove,
    required this.onChanged,
  });

  final _ReceiptItemController line;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5DDCE)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          TextFormField(
            controller: line.nameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Nazwa produktu'),
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: line.quantityController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Ilość'),
                  onChanged: (_) => onChanged(),
                  validator: (_) =>
                      line.nameController.text.trim().isNotEmpty &&
                          _parseMoney(line.quantityController.text) <= 0
                      ? 'Ilość'
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: line.unitController,
                  decoration: const InputDecoration(labelText: 'Jedn.'),
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: line.priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Cena',
                    suffixText: 'zł',
                  ),
                  onChanged: (_) => onChanged(),
                ),
              ),
              IconButton(
                tooltip: 'Usuń produkt',
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReceiptItemController {
  _ReceiptItemController()
    : nameController = TextEditingController(),
      quantityController = TextEditingController(text: '1'),
      unitController = TextEditingController(text: 'szt.'),
      priceController = TextEditingController();

  _ReceiptItemController.from(ReceiptItem item)
    : nameController = TextEditingController(text: item.name),
      quantityController = TextEditingController(
        text: formatQuantity(item.quantity),
      ),
      unitController = TextEditingController(text: item.unit),
      priceController = TextEditingController(
        text: _formatPlainMoney(item.price),
      );

  final TextEditingController nameController;
  final TextEditingController quantityController;
  final TextEditingController unitController;
  final TextEditingController priceController;

  ReceiptItem? toItem() {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      return null;
    }
    final quantity = _parseMoney(quantityController.text);
    if (quantity <= 0) {
      return null;
    }
    return ReceiptItem(
      name: name,
      quantity: quantity,
      unit: unitController.text.trim().isEmpty
          ? 'szt.'
          : unitController.text.trim(),
      price: _parseMoney(priceController.text),
    );
  }

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    unitController.dispose();
    priceController.dispose();
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

int _receiptParseScore(ParsedReceipt receipt) {
  var score = 0;
  if ((receipt.storeName ?? '').trim().isNotEmpty) {
    score += 1;
  }
  if (receipt.total > 0) {
    score += 3;
  }
  score += receipt.items.length * 4;
  if (!_receiptItemsLookCoherent(receipt)) {
    score -= 8;
  }
  return score;
}

bool _receiptItemsLookCoherent(ParsedReceipt receipt) {
  if (receipt.items.isEmpty || receipt.total <= 0) {
    return true;
  }
  final sum = receipt.items.fold<double>(
    0,
    (total, item) => total + item.price,
  );
  return sum <= receipt.total * 1.2;
}

Uint8List? _decodeReceiptImage(String? imageData) {
  var normalized = imageData?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  final dataUrlSeparator = normalized.indexOf(',');
  if (normalized.startsWith('data:image/') && dataUrlSeparator != -1) {
    normalized = normalized.substring(dataUrlSeparator + 1);
  }
  normalized = normalized.replaceAll(RegExp(r'\s+'), '');
  try {
    return base64Decode(normalized);
  } on FormatException {
    try {
      return base64Url.decode(base64Url.normalize(normalized));
    } on FormatException {
      return null;
    }
  }
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
