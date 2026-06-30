// lib/data/datasources/database_service.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:treelens/core/constants/app_constants.dart';

class DatabaseService {
  static DatabaseService? _instance;
  Database? _db;

  DatabaseService._();

  static DatabaseService get instance {
    _instance ??= DatabaseService._();
    return _instance!;
  }

  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);

    return await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _createTables,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ${AppConstants.historyTable} (
        id           TEXT PRIMARY KEY,
        image_path   TEXT NOT NULL,
        species_code TEXT NOT NULL,
        confidence   REAL NOT NULL,
        scanned_at   TEXT NOT NULL,
        note         TEXT
      )
    ''');
  }

  Future<void> insertScan(Map<String, dynamic> scanMap) async {
    final db = await database;
    await db.insert(
      AppConstants.historyTable,
      scanMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getAllScans() async {
    final db = await database;
    return await db.query(
      AppConstants.historyTable,
      orderBy: 'scanned_at DESC',
    );
  }

  Future<Map<String, dynamic>?> getScanById(String id) async {
    final db = await database;
    final results = await db.query(
      AppConstants.historyTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isEmpty ? null : results.first;
  }

  Future<void> updateNote(String id, String? note) async {
    final db = await database;
    await db.update(
      AppConstants.historyTable,
      {'note': note},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteScan(String id) async {
    final db = await database;
    await db.delete(
      AppConstants.historyTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteAllScans() async {
    final db = await database;
    await db.delete(AppConstants.historyTable);
  }

  Future<int> getScanCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM ${AppConstants.historyTable}');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
