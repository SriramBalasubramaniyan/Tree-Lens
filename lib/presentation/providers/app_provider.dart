// lib/presentation/providers/app_provider.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:treelens/data/datasources/classifier_service.dart';
import 'package:treelens/data/models/scan_result_model.dart';
import 'package:treelens/data/repositories/scan_repository.dart';

enum ClassifyState { idle, loading, success, error }

class AppProvider extends ChangeNotifier {
  // -- Theme
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  // -- Model loading
  bool _modelReady = false;
  bool get modelReady => _modelReady;

  Future<void> initModel() async {
    await ClassifierService.instance.loadModel();
    _modelReady = true;
    notifyListeners();
  }

  // -- Classification
  ClassifyState _classifyState = ClassifyState.idle;
  ClassifyState get classifyState => _classifyState;

  ScanResult? _lastResult;
  ScanResult? get lastResult => _lastResult;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<ScanResult?> classify(File imageFile) async {
    _classifyState = ClassifyState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await ScanRepository.instance.classifyAndSave(imageFile);
      _lastResult = result;
      _classifyState = ClassifyState.success;
      // Refresh history
      await loadHistory();
      notifyListeners();
      return result;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _classifyState = ClassifyState.error;
      notifyListeners();
      return null;
    }
  }

  void resetClassify() {
    _classifyState = ClassifyState.idle;
    _lastResult = null;
    _errorMessage = null;
    notifyListeners();
  }

  // -- History
  List<ScanResult> _history = [];
  List<ScanResult> get history => _history;
  bool _historyLoading = false;
  bool get historyLoading => _historyLoading;

  Future<void> loadHistory() async {
    _historyLoading = true;
    notifyListeners();
    _history = await ScanRepository.instance.getHistory();
    _historyLoading = false;
    notifyListeners();
  }

  Future<void> deleteScan(String id) async {
    await ScanRepository.instance.deleteScan(id);
    _history.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  Future<void> clearHistory() async {
    await ScanRepository.instance.clearHistory();
    _history = [];
    notifyListeners();
  }

  Future<void> saveNote(String id, String? note) async {
    await ScanRepository.instance.updateNote(id, note);
    final idx = _history.indexWhere((s) => s.id == id);
    if (idx != -1) {
      _history[idx] = _history[idx].copyWith(note: note);
      notifyListeners();
    }
  }
}
