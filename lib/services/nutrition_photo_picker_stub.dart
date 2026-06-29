class NutritionPhotoResult {
  const NutritionPhotoResult({
    required this.imageData,
    required this.imageMimeType,
  });

  final String imageData;
  final String imageMimeType;
}

class NutritionPhotoException implements Exception {
  const NutritionPhotoException(this.message);

  final String message;

  @override
  String toString() => message;
}

bool get nutritionCameraPhotoSupported => false;
bool get nutritionGalleryPhotoSupported => false;

Future<NutritionPhotoResult?> pickNutritionPhotoFromCamera() async {
  throw const NutritionPhotoException(
    'Zdjecie posilku dziala w aplikacji Android/iOS.',
  );
}

Future<NutritionPhotoResult?> pickNutritionPhotoFromGallery() async {
  throw const NutritionPhotoException(
    'Zdjecie z galerii dziala w aplikacji Android/iOS.',
  );
}
