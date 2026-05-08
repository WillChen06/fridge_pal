import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

final ocrServiceProvider = Provider<OcrService>((ref) {
  final service = MlKitOcrService();
  ref.onDispose(service.dispose);
  return service;
});

abstract class OcrService {
  Future<String> recognize(File imageFile);

  Future<void> dispose();
}

class MlKitOcrService implements OcrService {
  MlKitOcrService({
    TextRecognitionScript script = TextRecognitionScript.chinese,
  }) : _recognizer = TextRecognizer(script: script);

  final TextRecognizer _recognizer;

  @override
  Future<String> recognize(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final text = await _recognizer.processImage(inputImage);

    return text.blocks
        .expand((block) => block.lines)
        .map((line) => line.text.trim())
        .where((line) => line.isNotEmpty)
        .join('\n');
  }

  @override
  Future<void> dispose() => _recognizer.close();
}
