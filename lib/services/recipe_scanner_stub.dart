class RecipeImageScanResult {
  const RecipeImageScanResult({
    required this.text,
    required this.imageData,
    required this.imageMimeType,
  });

  final String text;
  final String imageData;
  final String imageMimeType;
}

class RecipeScanException implements Exception {
  const RecipeScanException(this.message);

  final String message;

  @override
  String toString() => message;
}

bool get recipeCameraScannerSupported => false;

Future<RecipeImageScanResult?> scanRecipeFromCamera() async {
  throw const RecipeScanException(
    'Skaner aparatem działa w aplikacji Android/iOS. W PWA wklej tekst przepisu.',
  );
}
