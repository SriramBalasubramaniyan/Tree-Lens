// lib/data/datasources/classifier_service.dart

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:treelens/core/constants/app_constants.dart';
import 'package:treelens/data/datasources/image_validator.dart';
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
      final modelData = await rootBundle.load(AppConstants.modelPath);
      final buffer = modelData.buffer.asUint8List();
      _interpreter = Interpreter.fromBuffer(buffer);
      _isLoaded = true;
    } catch (e) {
      throw ClassifierException('Failed to load model: $e');
    }
  }

  /// Full classify pipeline:
  ///   1. Image quality validation (brightness, blur) + preprocessing (contrast, crop)
  ///   2. Model inference
  ///   3. Entropy + top-2 gap guard
  Future<ClassifyResult> classify(File imageFile) async {
    if (!_isLoaded || _interpreter == null) {
      await loadModel();
    }

    // ── Step 1: Validate and preprocess ──────────────────────────────────
    final validation = await ImageValidator.validate(imageFile);
    if (validation.isRejected) {
      return ClassifyResult.imageRejected(validation.rejectReason!);
    }

    // ── Step 2: Run inference on preprocessed image ───────────────────────
    try {
      final processed = validation.processed!;

      // Resize preprocessed image to model input size
      final resized = img.copyResize(
        processed,
        width: AppConstants.inputSize,
        height: AppConstants.inputSize,
        interpolation: img.Interpolation.linear,
      );

      final inputBuffer =
          Uint8List(1 * AppConstants.inputSize * AppConstants.inputSize * 3);
      int idx = 0;
      for (int y = 0; y < AppConstants.inputSize; y++) {
        for (int x = 0; x < AppConstants.inputSize; x++) {
          final pixel = resized.getPixel(x, y);
          inputBuffer[idx++] = pixel.r.toInt();
          inputBuffer[idx++] = pixel.g.toInt();
          inputBuffer[idx++] = pixel.b.toInt();
        }
      }

      final input = inputBuffer
          .reshape([1, AppConstants.inputSize, AppConstants.inputSize, 3]);
      final outputBuffer =
          List.filled(1 * AppConstants.numClasses, 0)
              .reshape([1, AppConstants.numClasses]);

      _interpreter!.run(input, outputBuffer);

      final scores =
          (outputBuffer[0] as List).map((v) => (v as int) / 255.0).toList();

      // ── Step 3: Entropy + top-2 gap guard ──────────────────────────────
      final guard = _inferenceGuard(scores);
      if (guard != null) {
        return ClassifyResult.inferenceRejected(guard);
      }

      // Build sorted predictions
      final predictions = List.generate(AppConstants.numClasses, (i) {
        return PredictionScore(
          speciesCode: AppConstants.classNames[i],
          score: scores[i],
        );
      });
      predictions.sort((a, b) => b.score.compareTo(a.score));

      return ClassifyResult.success(predictions);
    } catch (e) {
      if (e is ClassifierException) rethrow;
      throw ClassifierException('Inference failed: $e');
    }
  }

  // ── Guard logic ────────────────────────────────────────────────────────────

  /// Returns an [InferenceRejection] if the model output looks unreliable,
  /// null if predictions look trustworthy.
  ///
  /// Two checks:
  ///   1. Entropy — high entropy means the model spread probability across
  ///      many classes randomly (genuine confusion, likely not a known tree).
  ///   2. Top-2 gap — small gap means the model is torn between two species
  ///      and the top prediction is not reliable.
  InferenceRejection? _inferenceGuard(List<double> scores) {
    final entropy = _entropy(scores);
    final sorted = List.of(scores)..sort((a, b) => b.compareTo(a));
    final maxScore = sorted[0];
    final top2Gap = sorted[0] - sorted[1];

    // Max entropy for 8 classes = log2(8) = 3.0
    // Above 2.2 = model is genuinely confused (not just uncertain between two)
    final bool highEntropy = entropy > AppConstants.entropyRejectionThreshold;

    // Gap below 0.10 = model is nearly equally split between top 2 species
    final bool ambiguousTop2 = top2Gap < AppConstants.top2GapThreshold;

    // Also below overall confidence threshold
    final bool lowConfidence = maxScore < AppConstants.mediumConfidence;

    if (lowConfidence && highEntropy) {
      // Genuinely confused — image is likely not one of the 8 species
      // (soft guard for non-tree / unknown images)
      return InferenceRejection(
        type: InferenceRejectionType.notRecognised,
        entropy: entropy,
        top2Gap: top2Gap,
        topScore: maxScore,
      );
    }

    if (lowConfidence && ambiguousTop2) {
      // Model is torn between two species — ask for a better photo
      return InferenceRejection(
        type: InferenceRejectionType.ambiguous,
        entropy: entropy,
        top2Gap: top2Gap,
        topScore: maxScore,
      );
    }

    return null; // Predictions look trustworthy — proceed
  }

  /// Shannon entropy of the score distribution.
  /// Range: 0 (certain) → log2(numClasses) = 3.0 (uniform).
  double _entropy(List<double> scores) {
    double h = 0;
    for (final p in scores) {
      if (p > 0) h -= p * (math.log(p) / math.log(2));
    }
    return h;
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
    _instance = null;
  }
}

// ── Result types ──────────────────────────────────────────────────────────────

/// Wraps every possible outcome from [ClassifierService.classify].
class ClassifyResult {
  final List<PredictionScore>? predictions;
  final ImageRejectReason? imageRejectReason;
  final InferenceRejection? inferenceRejection;

  const ClassifyResult._({
    this.predictions,
    this.imageRejectReason,
    this.inferenceRejection,
  });

  factory ClassifyResult.success(List<PredictionScore> p) =>
      ClassifyResult._(predictions: p);

  factory ClassifyResult.imageRejected(ImageRejectReason r) =>
      ClassifyResult._(imageRejectReason: r);

  factory ClassifyResult.inferenceRejected(InferenceRejection r) =>
      ClassifyResult._(inferenceRejection: r);

  bool get isSuccess => predictions != null;
  bool get isImageRejected => imageRejectReason != null;
  bool get isInferenceRejected => inferenceRejection != null;
  bool get isAnyRejection => isImageRejected || isInferenceRejected;

  /// Human-readable rejection message for the UI.
  String get rejectionMessage {
    if (imageRejectReason != null) {
      switch (imageRejectReason!) {
        case ImageRejectReason.tooDark:
          return 'Image is too dark — try in better lighting.';
        case ImageRejectReason.tooBright:
          return 'Image is overexposed — avoid direct sunlight on the lens.';
        case ImageRejectReason.tooBlurry:
          return 'Image is too blurry — hold steady and tap to focus.';
      }
    }
    if (inferenceRejection != null) {
      switch (inferenceRejection!.type) {
        case InferenceRejectionType.notRecognised:
          return 'This doesn\'t look like one of the 8 supported tree species. Try a clearer photo of leaves, bark, or the full tree.';
        case InferenceRejectionType.ambiguous:
          return 'The image is unclear — model is uncertain. Try a closer photo of the leaves or bark.';
      }
    }
    return 'Could not classify image.';
  }
}

enum InferenceRejectionType {
  /// High entropy — image probably doesn't match any known species.
  /// Acts as the soft non-tree guard.
  notRecognised,

  /// Low top-2 gap — model torn between two species.
  ambiguous,
}

class InferenceRejection {
  final InferenceRejectionType type;
  final double entropy;
  final double top2Gap;
  final double topScore;

  const InferenceRejection({
    required this.type,
    required this.entropy,
    required this.top2Gap,
    required this.topScore,
  });
}

class ClassifierException implements Exception {
  final String message;
  ClassifierException(this.message);
  @override
  String toString() => 'ClassifierException: $message';
}
