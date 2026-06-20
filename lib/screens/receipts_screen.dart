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
            onPaste: () => _openReceiptEditor(context),
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
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Wklej'),
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
      if (result.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nie odczytano tekstu z paragonu.')),
        );
        return;
      }
      await _openReceiptEditor(context, initialRawText: result.text);
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
    String initialRawText = '',
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ReceiptEditorSheet(initialRawText: initialRawText),
    );
  }
}

class _ReceiptActions extends StatelessWidget {
  const _ReceiptActions({
    required this.scanning,
    required this.scannerSupported,
    required this.onScan,
    required this.onPaste,
  });

  final bool scanning;
  final bool scannerSupported;
  final VoidCallback onScan;
  final VoidCallback onPaste;

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
          onPressed: onPaste,
          icon: const Icon(Icons.edit_note_outlined),
          label: const Text('Wklej tekst'),
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
                .take(10)
                .map(
                  (item) => ListTile(
                    dense: true,
                    title: Text(item.name),
                    subtitle: Text(
                      '${formatQuantity(item.quantity)} ${item.unit} • '
                      '${_formatMoney(item.price)}',
                    ),
                  ),
                ),
          if (receipt.items.length > 10)
            ListTile(
              dense: true,
              title: Text('+${receipt.items.length - 10} więcej'),
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

class _ReceiptEditorSheet extends StatefulWidget {
  const _ReceiptEditorSheet({required this.initialRawText});

  final String initialRawText;

  @override
  State<_ReceiptEditorSheet> createState() => _ReceiptEditorSheetState();
}

class _ReceiptEditorSheetState extends State<_ReceiptEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _storeController = TextEditingController(text: 'Sklep');
  late final TextEditingController _rawController;
  late ParsedReceipt _parsed;

  @override
  void initState() {
    super.initState();
    _rawController = TextEditingController(text: widget.initialRawText);
    _parsed = parseReceiptText(widget.initialRawText);
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
                    ? 'Brakuje tekstu paragonu'
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

String _formatMoney(double value) {
  return NumberFormat.currency(locale: 'pl_PL', symbol: 'zł').format(value);
}
