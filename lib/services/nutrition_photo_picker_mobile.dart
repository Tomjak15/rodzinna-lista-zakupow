import 'dart:convert';
import 'dart:io';

import 'package:image_picker/image_picker.dart';

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

bool get nutritionCameraPhotoSupported => Platform.isAndroid || Platform.isIOS;
bool get nutritionGalleryPhotoSupported => Platform.isAndroid || Platform.isIOS;

Future<NutritionPhotoResult?> pickNutritionPhotoFromCamera() {
  return _pickNutritionPhoto(source: ImageSource.camera);
}

Future<NutritionPhotoResult?> pickNutritionPhotoFromGallery() {
  return _pickNutritionPhoto(source: ImageSource.gallery);
}

Future<NutritionPhotoResult?> _pickNutritionPhoto({
  required ImageSource source,
}) async {
  if (!nutritionCameraPhotoSupported && !nutritionGalleryPhotoSupported) {
    throw const NutritionPhotoException(
      'Zdjecie posilku dziala w aplikacji Android/iOS.',
    );
  }

  final picker = ImagePicker();
  final image = await picker.pickImage(
    source: source,
    imageQuality: 82,
    maxWidth: 1280,
  );
  if (image == null) {
    return null;
  }

  try {
    final bytes = await image.readAsBytes();
    return NutritionPhotoResult(
      imageData: base64Encode(bytes),
      imageMimeType: image.mimeType ?? 'image/jpeg',
    );
  } catch (error) {
    throw NutritionPhotoException('Nie udalo sie dodac zdjecia: $error');
  }
}
