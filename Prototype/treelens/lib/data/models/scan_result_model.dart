// lib/data/models/scan_result_model.dart

import 'package:treelens/data/models/species_model.dart';

class ScanResult {
  final String id;
  final String imagePath;
  final String speciesCode;
  final SpeciesModel species;
  final double confidence;
  final List<PredictionScore> topScores;
  final DateTime scannedAt;
  final String? note;

  const ScanResult({
    required this.id,
    required this.imagePath,
    required this.speciesCode,
    required this.species,
    required this.confidence,
    required this.topScores,
    required this.scannedAt,
    this.note,
  });

  ScanResult copyWith({String? note}) => ScanResult(
    id:          id,
    imagePath:   imagePath,
    speciesCode: speciesCode,
    species:     species,
    confidence:  confidence,
    topScores:   topScores,
    scannedAt:   scannedAt,
    note:        note ?? this.note,
  );

  // SQLite serialization
  Map<String, dynamic> toMap() => {
    'id':           id,
    'image_path':   imagePath,
    'species_code': speciesCode,
    'confidence':   confidence,
    'scanned_at':   scannedAt.toIso8601String(),
    'note':         note,
  };

  static ScanResult fromMap(
    Map<String, dynamic> map,
    SpeciesModel species,
    List<PredictionScore> scores,
  ) => ScanResult(
    id:          map['id'] as String,
    imagePath:   map['image_path'] as String,
    speciesCode: map['species_code'] as String,
    species:     species,
    confidence:  map['confidence'] as double,
    topScores:   scores,
    scannedAt:   DateTime.parse(map['scanned_at'] as String),
    note:        map['note'] as String?,
  );
}

class PredictionScore {
  final String speciesCode;
  final double score;

  const PredictionScore({required this.speciesCode, required this.score});
}
