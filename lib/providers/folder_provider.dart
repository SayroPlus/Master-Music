import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/folder_model.dart';
import '../core/database/database_helper.dart';
import '../services/file_scanner_service.dart';

/// Key for storing selected folder paths in SharedPreferences.
const String kSelectedFolderPathsKey = 'selected_folder_paths';

/// State for the folder management feature.
class FolderState {
  final List<FolderModel> folders;
  final List<FolderModel> discoveredFolders;
  final bool isLoading;
  final bool isScanning;
  final String? scanningPath;
  final String? error;

  const FolderState({
    this.folders = const [],
    this.discoveredFolders = const [],
    this.isLoading = false,
    this.isScanning = false,
    this.scanningPath,
    this.error,
  });

  /// Folders the user has selected for monitoring.
  List<FolderModel> get selectedFolders =>
      folders.where((f) => f.isSelected).toList();

  FolderState copyWith({
    List<FolderModel>? folders,
    List<FolderModel>? discoveredFolders,
    bool? isLoading,
    bool? isScanning,
    String? scanningPath,
    String? error,
  }) {
    return FolderState(
      folders: folders ?? this.folders,
      discoveredFolders: discoveredFolders ?? this.discoveredFolders,
      isLoading: isLoading ?? this.isLoading,
      isScanning: isScanning ?? this.isScanning,
      scanningPath: scanningPath ?? this.scanningPath,
      error: error,
    );
  }
}

/// Manages monitored music folders.
///
/// Persists selected folder paths in SharedPreferences and full folder
/// data (with stats) in SQLite.
class FolderNotifier extends StateNotifier<FolderState> {
  final DatabaseHelper _db;
  final FileScannerService _scanner;

  FolderNotifier(this._db, this._scanner) : super(const FolderState());

  // ═══════════════════════════════════════════════════════════════════════════
  // Loading
  // ═══════════════════════════════════════════════════════════════════════════

  /// Loads all saved folders from the database.
  Future<void> loadFolders() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final folders = await _db.getAllFolders();
      state = state.copyWith(folders: folders, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Discovery (auto-scan filesystem)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Scans the device for all folders containing audio files.
  ///
  /// Populates [FolderState.discoveredFolders] — does NOT save them to the DB.
  Future<void> discoverFolders() async {
    state = state.copyWith(isScanning: true, error: null);
    try {
      final folders = await _scanner.scanAllFoldersWithAudio(
        onProgress: (dir) {
          state = state.copyWith(scanningPath: dir);
        },
      );
      state = state.copyWith(
        discoveredFolders: folders,
        isScanning: false,
        scanningPath: null,
      );
    } catch (e) {
      state = state.copyWith(
        isScanning: false,
        scanningPath: null,
        error: e.toString(),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CRUD
  // ═══════════════════════════════════════════════════════════════════════════

  /// Adds a new folder to the database and reloads.
  Future<void> addFolder(FolderModel folder) async {
    try {
      await _db.insertFolder(folder.copyWith(isSelected: true));
      await _saveSelectedPaths();
      await loadFolders();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Removes a folder from the database (and its songs) and reloads.
  Future<void> removeFolder(int id) async {
    try {
      await _db.deleteFolder(id);
      await _saveSelectedPaths();
      await loadFolders();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Toggles a folder's [isSelected] state and persists the change.
  Future<void> toggleFolderSelection(FolderModel folder) async {
    try {
      final updated = folder.copyWith(isSelected: !folder.isSelected);
      await _db.updateFolder(updated);
      await _saveSelectedPaths();
      await loadFolders();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Saves multiple folders at once (used after folder discovery UI).
  Future<void> saveSelectedFolders(List<FolderModel> foldersToSave) async {
    try {
      for (final folder in foldersToSave) {
        await _db.insertFolder(folder.copyWith(isSelected: true));
      }
      await _saveSelectedPaths();
      await loadFolders();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SharedPreferences persistence
  // ═══════════════════════════════════════════════════════════════════════════

  /// Persists the currently selected folder paths in SharedPreferences.
  ///
  /// This provides a fast startup check without hitting the DB.
  Future<void> _saveSelectedPaths() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final folders = await _db.getSelectedFolders();
      final paths = folders.map((f) => f.folderPath).toList();
      await prefs.setStringList(kSelectedFolderPathsKey, paths);
    } catch (_) {
      // Fail silently — DB is the source of truth
    }
  }

  /// Loads selected folder paths from SharedPreferences.
  ///
  /// Use this for quick startup checks before the full DB load.
  static Future<List<String>> loadSelectedPaths() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(kSelectedFolderPathsKey) ?? [];
    } catch (_) {
      return [];
    }
  }
}

/// Provider for the folder state and notifier.
final folderProvider =
    StateNotifierProvider<FolderNotifier, FolderState>((ref) {
  return FolderNotifier(DatabaseHelper(), FileScannerService());
});
