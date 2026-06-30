// lib/data/datasources/image_validator.dart
//
// Pure-Dart image quality checks that run BEFORE model inference.
// No ML model involved — pixel math only.
//
// Pipeline order:
//   1. Brightness check  — reject too dark / too blown-out
//   2. Blur check        — Laplacian variance (same metric as training pipeline)
//   3. Contrast stretch  — lift flat/dull images into usable range
//   4. Center crop       — remove noisy borders, focus on subject
//
// All operations use the `image` package already in pubspec.yaml.

import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

// ── Result types ─────────────────────────────────────────────────────────────

enum ImageRejectReason { tooDark, tooBright, tooBlurry }

class ImageValidationResult {
  /// null  → image passed all checks; [processed] is ready for inference
  /// non-null → image rejected before inference runs
  final ImageRejectReason? rejectReason;

  /// The preprocessed image (contrast-stretched + center-cropped).
  /// Only valid when [rejectReason] is null.
  final img.Image? processed;

  const ImageValidationResult._({this.rejectReason, this.processed});

  bool get isRejected => rejectReason != null;

  factory ImageValidationResult.rejected(ImageRejectReason reason) =>
      ImageValidationResult._(rejectReason: reason);

  factory ImageValidationResult.passed(img.Image image) =>
      ImageValidationResult._(processed: image);

  String get userMessage {
    switch (rejectReason) {
      case ImageRejectReason.tooDark:
        return 'Image is too dark — try in better lighting.';
      case ImageRejectReason.tooBright:
        return 'Image is overexposed — avoid direct sunlight on the lens.';
      case ImageRejectReason.tooBlurry:
        return 'Image is too blurry — hold steady and tap to focus.';
      case null:
        return '';
    }
  }
}

// ── Thresholds (tunable) ─────────────────────────────────────────────────────

class _Thresholds {
  // Brightness: mean pixel luminance 0-255
  static const double minBrightness = 35.0;   // below → too dark
  static const double maxBrightness = 220.0;  // above → overexposed

  // Blur: Laplacian variance (same scale as training pipeline's BLUR_THRESHOLD=80)
  // Lowered slightly for real-world shots which are less ideal than iNat photos.
  static const double minLaplacianVariance = 60.0;

  // Center-crop: keep this fraction of width/height
  static const double cropFraction = 0.85;
}

// ── Main validator ────────────────────────────────────────────────────────────

class ImageValidator {
  /// Validate and preprocess [imageFile].
  /// Returns a [ImageValidationResult] — check [isRejected] before using.
  static Future<ImageValidationResult> validate(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final original = img.decodeImage(bytes);
    if (original == null) {
      // Corrupt / unsupported — treat as blur rejection (can't read at all)
      return ImageValidationResult.rejected(ImageRejectReason.tooBlurry);
    }

    // Work on a small thumbnail for fast metric computation (doesn't need
    // full res to get brightness / blur statistics).
    final thumb = img.copyResize(original, width: 224, height: 224);

    // ── 1. Brightness check ───────────────────────────────────────────────
    final brightness = _meanLuminance(thumb);
    if (brightness < _Thresholds.minBrightness) {
      return ImageValidationResult.rejected(ImageRejectReason.tooDark);
    }
    if (brightness > _Thresholds.maxBrightness) {
      return ImageValidationResult.rejected(ImageRejectReason.tooBright);
    }

    // ── 2. Blur check ─────────────────────────────────────────────────────
    final laplacianVar = _laplacianVariance(thumb);
    if (laplacianVar < _Thresholds.minLaplacianVariance) {
      return ImageValidationResult.rejected(ImageRejectReason.tooBlurry);
    }

    // ── 3. Contrast stretch ───────────────────────────────────────────────
    // Only apply when the image is flat (low contrast). Avoids over-processing
    // already-good images.
    final enhanced = _contrastStretch(original);

    // ── 4. Center crop ────────────────────────────────────────────────────
    final cropped = _centerCrop(enhanced, _Thresholds.cropFraction);

    return ImageValidationResult.passed(cropped);
  }

  // ── Metric helpers ────────────────────────────────────────────────────────

  /// Mean luminance across all pixels (0-255).
  static double _meanLuminance(img.Image image) {
    double sum = 0;
    int count = 0;
    for (final pixel in image) {
      // Standard luminance formula
      sum += 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
      count++;
    }
    return count == 0 ? 0 : sum / count;
  }

  /// Laplacian variance — measures edge sharpness.
  /// Low value = blurry. Same metric used in the training pipeline (cv2.Laplacian).
  static double _laplacianVariance(img.Image image) {
    // 3x3 Laplacian kernel
    const kernel = [
      0,  1,  0,
      1, -4,  1,
      0,  1,  0,
    ];

    final w = image.width;
    final h = image.height;
    final values = <double>[];

    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        double conv = 0;
        int ki = 0;
        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            final p = image.getPixel(x + kx, y + ky);
            final gray = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
            conv += gray * kernel[ki++];
          }
        }
        values.add(conv);
      }
    }

    if (values.isEmpty) return 0;

    final mean = values.reduce((a, b) => a + b) / values.length;
    double variance = 0;
    for (final v in values) {
      variance += (v - mean) * (v - mean);
    }
    return variance / values.length;
  }

  // ── Enhancement helpers ───────────────────────────────────────────────────

  /// Stretch the histogram so the darkest pixel → 0 and brightest → 255.
  /// Only applies when the image has low dynamic range (contrast < 100 pts).
  /// Leaves already-vivid images untouched.
  static img.Image _contrastStretch(img.Image image) {
    int minVal = 255, maxVal = 0;

    for (final pixel in image) {
      final gray = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b).toInt();
      if (gray < minVal) minVal = gray;
      if (gray > maxVal) maxVal = gray;
    }

    final range = maxVal - minVal;
    // If the image already has good contrast (range ≥ 100), skip stretching.
    if (range >= 100 || range == 0) return image;

    final stretched = img.Image(width: image.width, height: image.height);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        final r = _stretch(p.r.toInt(), minVal, range);
        final g = _stretch(p.g.toInt(), minVal, range);
        final b = _stretch(p.b.toInt(), minVal, range);
        stretched.setPixelRgb(x, y, r, g, b);
      }
    }
    return stretched;
  }

  static int _stretch(int value, int minVal, int range) =>
      ((value - minVal) * 255 / range).round().clamp(0, 255);

  /// Crop the center [fraction] of the image to remove distracting borders.
  static img.Image _centerCrop(img.Image image, double fraction) {
    final w = image.width;
    final h = image.height;
    final cropW = (w * fraction).round();
    final cropH = (h * fraction).round();
    final offsetX = ((w - cropW) / 2).round();
    final offsetY = ((h - cropH) / 2).round();

    return img.copyCrop(
      image,
      x: offsetX,
      y: offsetY,
      width: cropW,
      height: cropH,
    );
  }
}
