import '../core/database/database_helper.dart';
import '../models/song_model.dart';
import 'acoustid_service.dart';
import 'musicbrainz_service.dart';

/// Orchestrates the full metadata-identification pipeline for a single song.
///
/// Pipeline steps:
///   1. Check if the song already has good metadata → skip to scoring.
///   2. Search MusicBrainz by existing title + artist.
///   3. Fall back to AcoustID fingerprint lookup.
///   4. If still unidentified → mark as `'unidentified'`.
///   5. On match → update all metadata fields, fetch cover art, compute
///      confidence score and level.
///   6. Persist the updated song to SQLite.
///
/// Confidence levels:
///   • ≥ 0.8 → `'high'`
///   • ≥ 0.5 → `'medium'`
///   • < 0.5 → `'low'`
class MetadataLookupService {
  final MusicBrainzService _musicBrainz;
  final AcoustIdService _acoustId;
  final DatabaseHelper _db;

  MetadataLookupService({
    MusicBrainzService? musicBrainzService,
    AcoustIdService? acoustIdService,
    DatabaseHelper? databaseHelper,
  })  : _musicBrainz = musicBrainzService ?? MusicBrainzService(),
        _acoustId = acoustIdService ?? AcoustIdService(),
        _db = databaseHelper ?? DatabaseHelper();

  // ── Public entry point ─────────────────────────────────────────────────────

  /// Runs the full identification pipeline and returns an updated [SongModel].
  ///
  /// The returned model will always have [hasBeenProcessed] set to `true` and
  /// a [confidenceLevel] of `'high'`, `'medium'`, `'low'`, or `'unidentified'`.
  Future<SongModel> identifySong(SongModel song) async {
    Map<String, dynamic>? lookupResult;

    // ── Step 1: Already identified? ────────────────────────────────────────
    final hasGoodMetadata =
        _isNotEmpty(song.title) && _isNotEmpty(song.artist);

    if (hasGoodMetadata) {
      // Still run a MusicBrainz search so we can compute a confidence score
      // and potentially fill in missing album / genre / cover art.
      lookupResult = await _musicBrainz.searchByTitleArtist(
        song.title!,
        song.artist!,
      );
    }

    // ── Step 2: MusicBrainz search with existing metadata ──────────────────
    if (lookupResult == null && _isNotEmpty(song.title)) {
      lookupResult = await _musicBrainz.searchByTitleArtist(
        song.title!,
        song.artist ?? '',
      );
    }

    // ── Step 2b: Try file-name based search ────────────────────────────────
    lookupResult ??= await _musicBrainz.searchByFileName(song.fileName);

    // ── Step 3: AcoustID fingerprint lookup ─────────────────────────────────
    if (lookupResult == null) {
      try {
        final fpResult =
            await _acoustId.generateFingerprint(song.filePath);

        if (fpResult != null) {
          lookupResult = await _acoustId.lookupFingerprint(
            fpResult['fingerprint'] as String,
            fpResult['duration'] as int,
          );
        }
      } catch (_) {
        // AcoustID unavailable (no API key, fpcalc missing, etc.).
        // Fall through to "unidentified".
      }
    }

    // ── Step 4: No result → unidentified ───────────────────────────────────
    if (lookupResult == null) {
      final unidentified = song.copyWith(
        hasBeenProcessed: true,
        confidenceLevel: 'unidentified',
        confidenceScore: 0.0,
        lastModified: DateTime.now(),
      );
      await _db.updateSong(unidentified);
      return unidentified;
    }

    // ── Step 5: Apply result to song ───────────────────────────────────────
    // Compute confidence score BEFORE overwriting fields, so the comparison
    // is against the original file metadata.
    final confidence = _musicBrainz.getConfidenceScore(lookupResult, song);

    // Fetch cover art if we have a release MBID.
    String? coverArtPath = song.coverArtPath;
    final releaseMbid = lookupResult['releaseMbid'] as String?;
    if (releaseMbid != null && coverArtPath == null) {
      coverArtPath = await _musicBrainz.getCoverArt(releaseMbid);
    }

    // ── Step 6: Map confidence → level ─────────────────────────────────────
    final confidenceLevel = _mapConfidenceLevel(confidence);

    // Build the updated model — prefer API data but keep existing values
    // where the API returned null.
    final updated = song.copyWith(
      title: lookupResult['title'] as String? ?? song.title,
      artist: lookupResult['artist'] as String? ?? song.artist,
      album: lookupResult['album'] as String? ?? song.album,
      genre: lookupResult['genre'] as String? ?? song.genre,
      year: lookupResult['year'] as String? ?? song.year,
      mbid: lookupResult['mbid'] as String? ?? song.mbid,
      coverArtPath: coverArtPath,
      confidenceScore: confidence,
      confidenceLevel: confidenceLevel,
      hasBeenProcessed: true,
      lastModified: DateTime.now(),
    );

    // ── Step 7: Persist to SQLite ──────────────────────────────────────────
    await _db.updateSong(updated);

    return updated;
  }

  // ── Batch helpers ──────────────────────────────────────────────────────────

  /// Processes a list of songs sequentially (respecting rate limits).
  ///
  /// [onProgress] is called after each song with the 0-based index.
  Future<List<SongModel>> identifyBatch(
    List<SongModel> songs, {
    void Function(int index, SongModel updatedSong)? onProgress,
  }) async {
    final results = <SongModel>[];

    for (var i = 0; i < songs.length; i++) {
      final updated = await identifySong(songs[i]);
      results.add(updated);
      onProgress?.call(i, updated);
    }

    return results;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Maps a numeric confidence score to a human-readable level.
  String _mapConfidenceLevel(double score) {
    if (score >= 0.8) return 'high';
    if (score >= 0.5) return 'medium';
    return 'low';
  }

  /// Returns `true` if [value] is non-null and non-empty.
  bool _isNotEmpty(String? value) =>
      value != null && value.trim().isNotEmpty;
}
