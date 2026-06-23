// lib/data/repositories/species_repository.dart

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:treelens/core/constants/app_constants.dart';
import 'package:treelens/data/models/species_model.dart';

class SpeciesRepository {
  static SpeciesRepository? _instance;
  Map<String, SpeciesModel>? _cache;

  SpeciesRepository._();

  static SpeciesRepository get instance {
    _instance ??= SpeciesRepository._();
    return _instance!;
  }

  Future<Map<String, SpeciesModel>> _load() async {
    if (_cache != null) return _cache!;
    final jsonStr = await rootBundle.loadString(AppConstants.speciesDataPath);
    final Map<String, dynamic> raw = json.decode(jsonStr);
    _cache = {
      for (final entry in raw.entries)
        entry.key: SpeciesModel.fromJson(entry.key, entry.value as Map<String, dynamic>)
    };
    return _cache!;
  }

  Future<SpeciesModel?> getByCode(String code) async {
    final all = await _load();
    return all[code];
  }

  Future<Map<String, SpeciesModel>> getAll() => _load();
}
