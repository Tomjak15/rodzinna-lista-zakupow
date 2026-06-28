class ReceiptScanResult {
  const ReceiptScanResult({
    required this.text,
    required this.imageData,
    required this.imageMimeType,
  });

  final String text;
  final String imageData;
  final String imageMimeType;
}

class ReceiptScanException implements Exception {
  const ReceiptScanException(this.message);

  final String message;

  @override
  String toString() => message;
}

bool get receiptCameraScannerSupported => false;
bool get receiptGalleryScannerSupported => false;

Future<ReceiptScanResult?> scanReceiptFromCamera() async {
  throw const ReceiptScanException(
    'Skaner aparatem działa w aplikacji Android/iOS. W PWA dodaj paragon ręcznie.',
  );
}

Future<ReceiptScanResult?> scanReceiptFromGallery() async {
  throw const ReceiptScanException(
    'Skan z galerii działa w aplikacji Android/iOS. W PWA dodaj paragon ręcznie.',
  );
}
