// lib/data/repositories/scan_repository.dart

import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:treelens/data/datasources/classifier_service.dart';
import 'package:treelens/data/datasources/database_service.dart';
import 'package:treelens/data/models/scan_result_model.dart';
import 'package:treelens/data/repositories/species_repository.dart';

/// Outcome returned by [ScanRepository.classifyAndSave].
/// Either a [ScanResult] on success, or a rejection message.
class ScanOutcome {
  final ScanResult? result;
  final String? rejectionMessage;

  const ScanOutcome._({this.result, this.rejectionMessage});

  factory ScanOutcome.success(ScanResult r) => ScanOutcome._(result: r);
  factory ScanOutcome.rejected(String message) =>
      ScanOutcome._(rejectionMessage: message);

  bool get isSuccess => result != null;
  bool get isRejected => rejectionMessage != null;
}

class ScanRepository {
  static ScanRepository? _instance;
  final _uuid = const Uuid();

  ScanRepository._();
  static ScanRepository get instance {
    _instance ??= ScanRepository._();
    return _instance!;
  }

  /// Run the full pipeline on [imageFile]:
  ///   image validation → inference → guard check → persist (on success only)
  ///
  /// Returns [ScanOutcome] — caller checks [isRejected] before using [result].
  /// Rejected images are NOT saved to history (no point logging bad inputs).
  Future<ScanOutcome> classifyAndSave(File imageFile) async {
    // 1. Run full classify pipeline (validation + inference + guard)
    final classifyResult = await ClassifierService.instance.classify(imageFile);

    // 2. If any rejection, surface the message without saving
    if (classifyResult.isAnyRejection) {
      return ScanOutcome.rejected(classifyResult.rejectionMessage);
    }

    // 3. Successful inference — look up species and persist
    final predictions = classifyResult.predictions!;
    final top = predictions.first;

    final species = await SpeciesRepository.instance.getByCode(top.speciesCode);
    if (species == null) throw Exception('Unknown species code: ${top.speciesCode}');

    // Copy image to app docs so it survives cache clears
    final savedPath = await _persistImage(imageFile);

    final scanResult = ScanResult(
      id:          _uuid.v4(),
      imagePath:   savedPath,
      speciesCode: top.speciesCode,
      species:     species,
      confidence:  top.score,
      topScores:   predictions.take(3).toList(),
      scannedAt:   DateTime.now(),
    );

    await DatabaseService.instance.insertScan(scanResult.toMap());
    return ScanOutcome.success(scanResult);
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

  Future<String> _persistImage(File source) async {
    final dir = await getApplicationDocumentsDirectory();
    final scansDir = Directory(p.join(dir.path, 'scans'));
    await scansDir.create(recursive: true);
    final dest = File(p.join(
        scansDir.path, '${_uuid.v4()}${p.extension(source.path)}'));
    await source.copy(dest.path);
    return dest.path;
  }
}
