// lib/data/repositories/scan_repository.dart

import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:treelens/data/datasources/classifier_service.dart';
import 'package:treelens/data/datasources/database_service.dart';
import 'package:treelens/data/models/scan_result_model.dart';
import 'package:treelens/data/repositories/species_repository.dart';

class ScanRepository {
  static ScanRepository? _instance;
  final _uuid = const Uuid();

  ScanRepository._();
  static ScanRepository get instance {
    _instance ??= ScanRepository._();
    return _instance!;
  }

  /// Run inference on [imageFile] and persist the result. Returns a [ScanResult].
  Future<ScanResult> classifyAndSave(File imageFile) async {
    // 1. Copy image to app docs so it survives cache clears
    final savedPath = await _persistImage(imageFile);

    // 2. Run inference
    final predictions = await ClassifierService.instance.classify(imageFile);
    final top = predictions.first;

    // 3. Lookup species details
    final species = await SpeciesRepository.instance.getByCode(top.speciesCode);
    if (species == null) throw Exception('Unknown species code: ${top.speciesCode}');

    // 4. Build result
    final result = ScanResult(
      id:          _uuid.v4(),
      imagePath:   savedPath,
      speciesCode: top.speciesCode,
      species:     species,
      confidence:  top.score,
      topScores:   predictions.take(3).toList(),
      scannedAt:   DateTime.now(),
    );

    // 5. Persist to SQLite
    await DatabaseService.instance.insertScan(result.toMap());
    return result;
  }

  /// Load all scan history from SQLite.
  Future<List<ScanResult>> getHistory() async {
    final rows = await DatabaseService.instance.getAllScans();
    final speciesAll = await SpeciesRepository.instance.getAll();

    return rows.map((row) {
      final code = row['species_code'] as String;
      final species = speciesAll[code]!;
      return ScanResult.fromMap(row, species, []);
    }).toList();
  }

  Future<void> updateNote(String id, String? note) =>
      DatabaseService.instance.updateNote(id, note);

  Future<void> deleteScan(String id) =>
      DatabaseService.instance.deleteScan(id);

  Future<void> clearHistory() =>
      DatabaseService.instance.deleteAllScans();

  // Copy selected image into app's documents directory
  Future<String> _persistImage(File source) async {
    final dir = await getApplicationDocumentsDirectory();
    final scansDir = Directory(p.join(dir.path, 'scans'));
    await scansDir.create(recursive: true);
    final dest = File(p.join(scansDir.path, '${_uuid.v4()}${p.extension(source.path)}'));
    await source.copy(dest.path);
    return dest.path;
  }
}
