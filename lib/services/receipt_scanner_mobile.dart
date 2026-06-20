import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

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

bool get receiptCameraScannerSupported => Platform.isAndroid || Platform.isIOS;

Future<ReceiptScanResult?> scanReceiptFromCamera() async {
  if (!receiptCameraScannerSupported) {
    throw const ReceiptScanException(
      'Skaner aparatem działa w aplikacji Android/iOS.',
    );
  }

  final picker = ImagePicker();
  final image = await picker.pickImage(
    source: ImageSource.camera,
    imageQuality: 85,
    maxWidth: 1800,
  );
  if (image == null) {
    return null;
  }

  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final inputImage = InputImage.fromFilePath(image.path);
    final recognizedText = await recognizer.processImage(inputImage);
    return ReceiptScanResult(text: recognizedText.text, imagePath: image.path);
  } catch (error) {
    throw ReceiptScanException('Nie udało się odczytać paragonu: $error');
  } finally {
    await recognizer.close();
  }
}
