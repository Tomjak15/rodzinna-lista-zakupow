class ReceiptScanResult {
  const ReceiptScanResult({required this.text, this.imagePath});

  final String text;
  final String? imagePath;
}

class ReceiptScanException implements Exception {
  const ReceiptScanException(this.message);

  final String message;

  @override
  String toString() => message;
}

bool get receiptCameraScannerSupported => false;

Future<ReceiptScanResult?> scanReceiptFromCamera() async {
  throw const ReceiptScanException(
    'Skaner aparatem działa w aplikacji Android/iOS. W PWA wklej tekst paragonu.',
  );
}
