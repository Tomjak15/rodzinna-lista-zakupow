import 'dart:convert';
import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

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
    imageQuality: 62,
    maxWidth: 1200,
  );
  if (image == null) {
    return null;
  }

  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final bytes = await image.readAsBytes();
    final inputImage = InputImage.fromFilePath(image.path);
    final recognizedText = await recognizer.processImage(inputImage);
    return ReceiptScanResult(
      text: recognizedText.text,
      imageData: base64Encode(bytes),
      imageMimeType: image.mimeType ?? 'image/jpeg',
    );
  } catch (error) {
    throw ReceiptScanException('Nie udało się odczytać paragonu: $error');
  } finally {
    await recognizer.close();
  }
}
