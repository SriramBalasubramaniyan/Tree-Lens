// lib/data/datasources/classifier_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:treelens/core/constants/app_constants.dart';
import 'package:treelens/data/models/scan_result_model.dart';

class ClassifierService {
  static ClassifierService? _instance;
  Interpreter? _interpreter;
  bool _isLoaded = false;

  ClassifierService._();

  static ClassifierService get instance {
    _instance ??= ClassifierService._();
    return _instance!;
  }

  bool get isLoaded => _isLoaded;

  Future<void> loadModel() async {
    if (_isLoaded) return;
    try {
      // Load INT8 model from assets
      final modelData = await rootBundle.load(AppConstants.modelPath);
      final buffer = modelData.buffer.asUint8List();
      _interpreter = Interpreter.fromBuffer(buffer);
      _isLoaded = true;
    } catch (e) {
      throw ClassifierException('Failed to load model: $e');
    }
  }

  Future<List<PredictionScore>> classify(File imageFile) async {
    if (!_isLoaded || _interpreter == null) {
      await loadModel();
    }

    try {
      // Decode and preprocess image
      final bytes = await imageFile.readAsBytes();
      final original = img.decodeImage(bytes);
      if (original == null) throw ClassifierException('Cannot decode image');

      // Resize to 224×224 (EfficientNetB0 input)
      final resized = img.copyResize(
        original,
        width: AppConstants.inputSize,
        height: AppConstants.inputSize,
        interpolation: img.Interpolation.linear,
      );

      final inputBuffer = Uint8List(1 * AppConstants.inputSize * AppConstants.inputSize * 3);
      int idx = 0;
      for (int y = 0; y < AppConstants.inputSize; y++) {
        for (int x = 0; x < AppConstants.inputSize; x++) {
          final pixel = resized.getPixel(x, y);
          inputBuffer[idx++] = pixel.r.toInt();   // 0–255 uint8
          inputBuffer[idx++] = pixel.g.toInt();
          inputBuffer[idx++] = pixel.b.toInt();
        }
      }

      final input = inputBuffer.reshape([1, AppConstants.inputSize, AppConstants.inputSize, 3]);

      final outputBuffer = List.filled(1 * AppConstants.numClasses, 0).reshape([1, AppConstants.numClasses]);

      _interpreter!.run(input, outputBuffer);

      final scores = (outputBuffer[0] as List).map((v) => (v as int) / 255.0).toList();

      // Map to labelled scores and sort descending
      final predictions = List.generate(AppConstants.numClasses, (i) {
        return PredictionScore(
          speciesCode: AppConstants.classNames[i],
          score: scores[i],
        );
      });
      predictions.sort((a, b) => b.score.compareTo(a.score));
      return predictions;
    } catch (e) {
      if (e is ClassifierException) rethrow;
      throw ClassifierException('Inference failed: $e');
    }
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
    _instance = null;
  }
}

class ClassifierException implements Exception {
  final String message;
  ClassifierException(this.message);
  @override
  String toString() => 'ClassifierException: $message';
}
