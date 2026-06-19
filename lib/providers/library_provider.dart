import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart';


import '../models/song_model.dart';
import '../core/database/database_helper.dart';

enum FilterType {
  all,
  missingMetadata,
  unidentified,
  duplicates,
  recentlyFixed,
}

/// State for the song library.
class LibraryState {
  final List<SongModel> songs;
  final bool isLoading;
  final bool isScanning;
  final int scannedCount;
  final String? error;

  final String searchQuery;
  final FilterType currentFilter;
  final bool isGridView;
  final Set<int> selectedSongIds;

  const LibraryState({
    this.songs = const [],
    this.isLoading = false,
    this.isScanning = false,
    this.scannedCount = 0,
    this.error,
    this.searchQuery = '',
    this.currentFilter = FilterType.all,
    this.isGridView = false,
    this.selectedSongIds = const {},
  });

  bool get isSelectionMode => selectedSongIds.isNotEmpty;

  /// Filtered songs based on the current search query and filter chip.
  List<SongModel> get filteredSongs {
    var result = songs.where((s) {
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        if (!s.displayTitle.toLowerCase().contains(query) &&
            !s.displayArtist.toLowerCase().contains(query) &&
            !s.displayAlbum.toLowerCase().contains(query)) {
          return false;
        }
      }

      switch (currentFilter) {
        case FilterType.all:
          return true;
        case FilterType.missingMetadata:
          return s.title == null || s.artist == null;
        case FilterType.unidentified:
          return s.confidenceLevel == 'unidentified';
        case FilterType.duplicates:
          return s.isDuplicate;
        case FilterType.recentlyFixed:
          // Just as an example, songs modified in the last 24h
          return s.hasBeenProcessed &&
              DateTime.now().difference(s.lastModified).inDays <= 1;
      }
    }).toList();

    // Sort logic here if needed, default is by title (done in SQL)
    return result;
  }

  LibraryState copyWith({
    List<SongModel>? songs,
    bool? isLoading,
    bool? isScanning,
    int? scannedCount,
    String? error,
    String? searchQuery,
    FilterType? currentFilter,
    bool? isGridView,
    Set<int>? selectedSongIds,
  }) {
    return LibraryState(
      songs: songs ?? this.songs,
      isLoading: isLoading ?? this.isLoading,
      isScanning: isScanning ?? this.isScanning,
      scannedCount: scannedCount ?? this.scannedCount,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      currentFilter: currentFilter ?? this.currentFilter,
      isGridView: isGridView ?? this.isGridView,
      selectedSongIds: selectedSongIds ?? this.selectedSongIds,
    );
  }
}

/// Manages the song library.
class LibraryNotifier extends StateNotifier<LibraryState> {
  final DatabaseHelper _db;

  LibraryNotifier(this._db) : super(const LibraryState());

  /// Loads all songs from the database, pruning ghost files natively.
  Future<void> loadSongs() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final db = await _db.database;
      final rows = await db.query('songs', orderBy: 'title ASC');

      final validSongs = <SongModel>[];
      for (final r in rows) {
        final song = SongModel.fromMap(r);
        if (File(song.filePath).existsSync()) {
          validSongs.add(song);
        } else {
          // Fire-and-forget delete for ghost mapping
          _db.deleteSong(song.id!);
        }
      }

      state = state.copyWith(songs: validSongs, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Updates search filter query.
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Sets the current filter chip.
  void setFilter(FilterType filter) {
    state = state.copyWith(currentFilter: filter);
  }

  /// Toggles between grid and list view.
  void toggleGridView() {
    state = state.copyWith(isGridView: !state.isGridView);
  }

  /// Toggles selection of a specific song.
  void toggleSelection(int songId) {
    final newSelection = Set<int>.from(state.selectedSongIds);
    if (newSelection.contains(songId)) {
      newSelection.remove(songId);
    } else {
      newSelection.add(songId);
    }
    state = state.copyWith(selectedSongIds: newSelection);
  }

  /// Deselects all songs, exiting selection mode.
  void clearSelection() {
    state = state.copyWith(selectedSongIds: const {});
  }

  /// Selects all currently filtered songs.
  void selectAll() {
    final newSelection = state.filteredSongs
        .where((s) => s.id != null)
        .map((s) => s.id!)
        .toSet();
    state = state.copyWith(selectedSongIds: newSelection);
  }

  /// Updates a single song in the library state and database.
  Future<void> updateSongMetadata(SongModel updatedSong) async {
    // 1. Update database
    await _db.updateSong(updatedSong);
    
    // 2. Update local state
    state = state.copyWith(
      songs: state.songs.map((s) => s.id == updatedSong.id ? updatedSong : s).toList(),
    );
  }

  /// Updates a song's path in the database and local state.
  Future<void> updateSongPath(int songId, String newPath) async {
    // 1. Update database
    await _db.updateSongPath(songId, newPath);
    
    // 2. Update local state
    final updatedSongs = state.songs.map((s) {
      if (s.id == songId) {
        return s.copyWith(
          filePath: newPath,
          fileName: basename(newPath),
          lastModified: DateTime.now(),
        );
      }
      return s;
    }).toList();
    
    state = state.copyWith(songs: updatedSongs);
  }

  /// Placholder for Fix Metadata action.
  Future<void> fixSelectedMetadata() async {
    // TODO: implement batch fix
    clearSelection();
  }

  /// Placeholder for Organize action.
  Future<void> organizeSelected() async {
    // TODO: implement organize
    clearSelection();
  }

  /// Placeholder for Delete action.
  Future<void> deleteSelected() async {
    // TODO: implement delete
    clearSelection();
  }
}

/// Provider for the library state and notifier.
final libraryProvider = StateNotifierProvider<LibraryNotifier, LibraryState>((
  ref,
) {
  return LibraryNotifier(DatabaseHelper());
});
