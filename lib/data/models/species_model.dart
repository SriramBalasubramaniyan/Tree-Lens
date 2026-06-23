// lib/data/models/species_model.dart

class SpeciesModel {
  final String code;
  final String common;
  final String scientific;
  final String family;
  final String co2Class;
  final double co2KgYr;
  final double co2Min;
  final double co2Max;
  final double dbhCm;
  final double heightM;
  final String biome;
  final String growthRate;
  final String description;
  final String carbonNote;
  final String emoji;

  const SpeciesModel({
    required this.code,
    required this.common,
    required this.scientific,
    required this.family,
    required this.co2Class,
    required this.co2KgYr,
    required this.co2Min,
    required this.co2Max,
    required this.dbhCm,
    required this.heightM,
    required this.biome,
    required this.growthRate,
    required this.description,
    required this.carbonNote,
    required this.emoji,
  });

  factory SpeciesModel.fromJson(String code, Map<String, dynamic> json) {
    return SpeciesModel(
      code:        code,
      common:      json['common'] as String,
      scientific:  json['scientific'] as String,
      family:      json['family'] as String,
      co2Class:    json['co2_class'] as String,
      co2KgYr:     (json['co2_kg_yr'] as num).toDouble(),
      co2Min:      (json['co2_min'] as num).toDouble(),
      co2Max:      (json['co2_max'] as num).toDouble(),
      dbhCm:       (json['dbh_cm'] as num).toDouble(),
      heightM:     (json['height_m'] as num).toDouble(),
      biome:       json['biome'] as String,
      growthRate:  json['growth_rate'] as String,
      description: json['description'] as String,
      carbonNote:  json['carbon_note'] as String,
      emoji:       json['emoji'] as String,
    );
  }
}
