// lib/core/constants/app_constants.dart

class AppConstants {
  // Model
  static const String modelPath = 'assets/models/model_int8.tflite';
  static const String speciesDataPath = 'assets/data/species_lookup.json';
  static const int inputSize = 224;
  static const int numClasses = 8;

  // Database
  static const String dbName = 'tree_classifier.db';
  static const int dbVersion = 1;
  static const String historyTable = 'scan_history';

  // Class labels — must match training order
  static const List<String> classNames = [
    'BAM', 'MGR', 'MNG', 'MOR', 'NEM', 'PEP', 'RSW', 'TEK'
  ];

  // CO₂ class colours (hex strings for display)
  static const Map<String, String> co2ClassColor = {
    'HIGH':   '#2D6A4F',
    'MEDIUM': '#B7791F',
    'LOW':    '#718096',
  };

  // ── Confidence thresholds ──────────────────────────────────────────────────
  static const double highConfidence   = 0.75;
  static const double mediumConfidence = 0.50;
  // Below mediumConfidence = low confidence warning shown in result screen

  // ── Inference guard thresholds ─────────────────────────────────────────────
  //
  // Entropy: Shannon entropy of the 8-class softmax output.
  // Max possible = log2(8) = 3.0 (uniform distribution = totally lost).
  // > 2.2 with low max score = model is genuinely confused, likely not a
  // known species → soft non-tree guard triggers.
  static const double entropyRejectionThreshold = 2.2;

  // Top-2 gap: difference between #1 and #2 class scores.
  // < 0.10 with low max score = model is torn between two species → ambiguous.
  static const double top2GapThreshold = 0.10;

  // App info
  static const String appName = 'TreeLens';
  static const String appTagline = 'Carbon tree identification, on-device';
}
