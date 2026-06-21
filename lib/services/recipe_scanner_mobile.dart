import 'dart:convert';
import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

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

bool get recipeCameraScannerSupported => Platform.isAndroid || Platform.isIOS;

Future<RecipeImageScanResult?> scanRecipeFromCamera() async {
  if (!recipeCameraScannerSupported) {
    throw const RecipeScanException(
      'Skaner aparatem działa w aplikacji Android/iOS.',
    );
  }

  final picker = ImagePicker();
  final image = await picker.pickImage(
    source: ImageSource.camera,
    imageQuality: 70,
    maxWidth: 1400,
  );
  if (image == null) {
    return null;
  }

  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final bytes = await image.readAsBytes();
    final inputImage = InputImage.fromFilePath(image.path);
    final recognizedText = await recognizer.processImage(inputImage);
    return RecipeImageScanResult(
      text: recognizedText.text,
      imageData: base64Encode(bytes),
      imageMimeType: image.mimeType ?? 'image/jpeg',
    );
  } catch (error) {
    throw RecipeScanException('Nie udało się odczytać przepisu: $error');
  } finally {
    await recognizer.close();
  }
}
