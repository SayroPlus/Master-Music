import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/database_helper.dart';
import '../models/song_model.dart';

/// Aggregated statistics for the dashboard.
class StatsState {
  final int totalSongs;
  final int totalArtists;
  final int totalAlbums;
  final int processedSongs;
  final int duplicateSongs;
  final int totalStorageBytes;
  
  final int identifiedSongs;
  final int modifiedSongs;
  
  final int highConfidence;
  final int mediumConfidence;
  final int lowConfidence;
  final int unidentified;
  
  final int withTitle;
  final int withArtist;
  final int withAlbum;
  final int withCoverArt;
  final int withGenre;

  final Map<String, int> genreDistribution;
  final Map<String, int> artistDistribution;
  final Map<String, int> formatDistribution;
  
  final List<SongModel> recentlyFixedSongs;

  final bool isLoading;
  final String? error;

  const StatsState({
    this.totalSongs = 0,
    this.totalArtists = 0,
    this.totalAlbums = 0,
    this.processedSongs = 0,
    this.duplicateSongs = 0,
    this.totalStorageBytes = 0,
    this.identifiedSongs = 0,
    this.modifiedSongs = 0,
    this.highConfidence = 0,
    this.mediumConfidence = 0,
    this.lowConfidence = 0,
    this.unidentified = 0,
    this.withTitle = 0,
    this.withArtist = 0,
    this.withAlbum = 0,
    this.withCoverArt = 0,
    this.withGenre = 0,
    this.genreDistribution = const {},
    this.artistDistribution = const {},
    this.formatDistribution = const {},
    this.recentlyFixedSongs = const [],
    this.isLoading = false,
    this.error,
  });

  /// Percentage of songs that have been completely organized/processed.
  double get organizedPercentage {
    if (totalSongs == 0) return 0.0;
    return (processedSongs / totalSongs) * 100;
  }

  /// Completeness percentage average for metadata points.
  double get completenessPercent {
    if (totalSongs == 0) return 0.0;
    final totalPoints = totalSongs * 5; // title, artist, album, cover, genre
    final actualPoints = withTitle + withArtist + withAlbum + withCoverArt + withGenre;
    return (actualPoints / totalPoints) * 100;
  }

  /// Number of duplicate groups (simplified mapping).
  int get duplicateGroups => duplicateSongs > 0 ? (duplicateSongs / 2).ceil() : 0; 

  /// Human-readable total storage size.
  String get formattedStorage {
    if (totalStorageBytes < 1024 * 1024) {
      return '${(totalStorageBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (totalStorageBytes < 1024 * 1024 * 1024) {
      return '${(totalStorageBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(totalStorageBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  StatsState copyWith({
    int? totalSongs,
    int? totalArtists,
    int? totalAlbums,
    int? processedSongs,
    int? duplicateSongs,
    int? totalStorageBytes,
    int? identifiedSongs,
    int? modifiedSongs,
    int? highConfidence,
    int? mediumConfidence,
    int? lowConfidence,
    int? unidentified,
    int? withTitle,
    int? withArtist,
    int? withAlbum,
    int? withCoverArt,
    int? withGenre,
    Map<String, int>? genreDistribution,
    Map<String, int>? artistDistribution,
    Map<String, int>? formatDistribution,
    List<SongModel>? recentlyFixedSongs,
    bool? isLoading,
    String? error,
  }) {
    return StatsState(
      totalSongs: totalSongs ?? this.totalSongs,
      totalArtists: totalArtists ?? this.totalArtists,
      totalAlbums: totalAlbums ?? this.totalAlbums,
      processedSongs: processedSongs ?? this.processedSongs,
      duplicateSongs: duplicateSongs ?? this.duplicateSongs,
      totalStorageBytes: totalStorageBytes ?? this.totalStorageBytes,
      identifiedSongs: identifiedSongs ?? this.identifiedSongs,
      modifiedSongs: modifiedSongs ?? this.modifiedSongs,
      highConfidence: highConfidence ?? this.highConfidence,
      mediumConfidence: mediumConfidence ?? this.mediumConfidence,
      lowConfidence: lowConfidence ?? this.lowConfidence,
      unidentified: unidentified ?? this.unidentified,
      withTitle: withTitle ?? this.withTitle,
      withArtist: withArtist ?? this.withArtist,
      withAlbum: withAlbum ?? this.withAlbum,
      withCoverArt: withCoverArt ?? this.withCoverArt,
      withGenre: withGenre ?? this.withGenre,
      genreDistribution: genreDistribution ?? this.genreDistribution,
      artistDistribution: artistDistribution ?? this.artistDistribution,
      formatDistribution: formatDistribution ?? this.formatDistribution,
      recentlyFixedSongs: recentlyFixedSongs ?? this.recentlyFixedSongs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Computes and manages dashboard statistics using DatabaseHelper queries.
class StatsNotifier extends StateNotifier<StatsState> {
  final DatabaseHelper _db;

  StatsNotifier(this._db) : super(const StatsState()) {
    refreshStats();
  }

  /// Refreshes all statistics from the database.
  Future<void> refreshStats() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Aggregate counts from the database
      final stats = await _db.getSongStats();
      final completeness = await _db.getMetadataCompleteness();
      final genreMap = await _db.getGenreDistribution();
      final artistMap = await _db.getArtistDistribution();
      final formatMap = await _db.getFormatDistribution();
      final recentlyFixed = await _db.getRecentlyFixedSongs(limit: 10);

      state = state.copyWith(
        totalSongs: stats['totalSongs'] ?? 0,
        totalArtists: stats['totalArtists'] ?? 0,
        totalAlbums: stats['totalAlbums'] ?? 0,
        processedSongs: stats['processedSongs'] ?? 0,
        duplicateSongs: stats['duplicateSongs'] ?? 0,
        totalStorageBytes: stats['totalSizeBytes'] ?? 0,
        identifiedSongs: stats['identifiedSongs'] ?? 0,
        modifiedSongs: stats['modifiedSongs'] ?? 0,
        highConfidence: stats['highConfidence'] ?? 0,
        mediumConfidence: stats['mediumConfidence'] ?? 0,
        lowConfidence: stats['lowConfidence'] ?? 0,
        unidentified: stats['unidentified'] ?? 0,
        withTitle: completeness['withTitle'] ?? 0,
        withArtist: completeness['withArtist'] ?? 0,
        withAlbum: completeness['withAlbum'] ?? 0,
        withCoverArt: completeness['withCoverArt'] ?? 0,
        withGenre: completeness['withGenre'] ?? 0,
        genreDistribution: genreMap,
        artistDistribution: artistMap,
        formatDistribution: formatMap,
        recentlyFixedSongs: recentlyFixed,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

/// Provider for the stats state and notifier.
final statsProvider =
    StateNotifierProvider<StatsNotifier, StatsState>((ref) {
  return StatsNotifier(DatabaseHelper());
});
