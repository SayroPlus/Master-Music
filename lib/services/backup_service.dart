import 'dart:convert';

import '../core/database/database_helper.dart';
import '../models/backup_snapshot_model.dart';
import '../models/restore_result_model.dart';
import '../models/song_model.dart';
import 'id3_writer_service.dart';

/// Service for creating, listing, restoring, and clearing metadata backups.
///
/// Each backup is a JSON snapshot of every song's metadata at a point in time.
/// Restoration writes the saved metadata back to both the actual audio files
/// (via [Id3WriterService]) and the SQLite database.
///
/// A maximum of 3 snapshots are retained — the oldest is automatically purged
/// whenever a new one is created.
class BackupService {
  final DatabaseHelper _db;
  final Id3WriterService _id3Writer;

  /// Maximum number of backup snapshots to keep.
  static const int _maxSnapshots = 3;

  BackupService({
    DatabaseHelper? databaseHelper,
    Id3WriterService? id3WriterService,
  })  : _db = databaseHelper ?? DatabaseHelper(),
        _id3Writer = id3WriterService ?? Id3WriterService();

  // ═══════════════════════════════════════════════════════════════════════════
  // Create
  // ═══════════════════════════════════════════════════════════════════════════

  /// Creates a metadata snapshot from the provided [songs] list.
  ///
  /// [label] describes the operation that is about to happen, e.g.
  /// `"Before bulk fix – 11 Apr 2026"`.
  ///
  /// After insertion the oldest snapshots are pruned so that at most
  /// [_maxSnapshots] remain.
  ///
  /// Returns the newly created [BackupSnapshotModel].
  Future<BackupSnapshotModel> createBackupSnapshot(
    List<SongModel> songs,
    String label,
  ) async {
    // Serialize every song's metadata map to a single JSON array string.
    final songMaps = songs.map((s) => s.toMap()).toList();
    final snapshotJson = jsonEncode(songMaps);

    final snapshot = BackupSnapshotModel(
      createdAt: DateTime.now(),
      label: label,
      snapshotJson: snapshotJson,
      songCount: songs.length,
    );

    final insertedId = await _db.insertBackupSnapshot(snapshot);

    // Prune old snapshots beyond the limit.
    await _pruneOldSnapshots();

    // Return the snapshot with its DB-assigned id.
    return BackupSnapshotModel(
      id: insertedId,
      createdAt: snapshot.createdAt,
      label: snapshot.label,
      snapshotJson: snapshot.snapshotJson,
      songCount: snapshot.songCount,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Read
  // ═══════════════════════════════════════════════════════════════════════════

  /// Returns all available snapshots ordered by [createdAt] descending
  /// (newest first).
  Future<List<BackupSnapshotModel>> getAvailableSnapshots() async {
    return await _db.getAllBackupSnapshots();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Restore (full snapshot)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Restores **all** songs from the given [snapshot].
  ///
  /// For each song in the snapshot:
  ///   1. Locate the matching DB record by `file_path`.
  ///   2. Write the original metadata back to the **actual audio file**
  ///      via the native ID3-writer channel.
  ///   3. Update the DB record with the snapshot's metadata.
  ///
  /// Returns a [RestoreResult] summarising successes, failures, and errors.
  Future<RestoreResult> restoreSnapshot(BackupSnapshotModel snapshot) async {
    final List<dynamic> songMaps;
    try {
      songMaps = jsonDecode(snapshot.snapshotJson) as List<dynamic>;
    } catch (e) {
      return RestoreResult(
        successCount: 0,
        failCount: 1,
        errors: ['Failed to parse snapshot JSON: $e'],
      );
    }

    int successCount = 0;
    int failCount = 0;
    final errors = <String>[];

    for (final raw in songMaps) {
      final songData = raw as Map<String, dynamic>;
      final filePath = songData['file_path'] as String;

      try {
        final currentSong = await _db.getSongByPath(filePath);
        if (currentSong == null) {
          // File was removed from the library since the snapshot was taken.
          failCount++;
          errors.add('Song not found in DB: $filePath');
          continue;
        }

        // 1. Write metadata back to the actual file.
        final writeOk = await _id3Writer.writeMetadataFromMap(songData);
        if (!writeOk) {
          // Non-fatal: the file tag write failed but we can still update DB.
          errors.add('ID3 write failed (DB still updated): $filePath');
        }

        // 2. Update the DB record — keep the current row id.
        final restoredSong = SongModel.fromMap({
          ...songData,
          'id': currentSong.id,
        });
        await _db.updateSong(restoredSong);

        successCount++;
      } catch (e) {
        failCount++;
        errors.add('Error restoring $filePath: $e');
      }
    }

    return RestoreResult(
      successCount: successCount,
      failCount: failCount,
      errors: errors,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Restore (single song)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Restores a **single** song identified by [filePath] from the given
  /// [snapshot].
  ///
  /// Returns `true` if the song was found in the snapshot and successfully
  /// restored to both the file and the database.
  Future<bool> restoreSingleSong(
    String filePath,
    BackupSnapshotModel snapshot,
  ) async {
    final List<dynamic> songMaps;
    try {
      songMaps = jsonDecode(snapshot.snapshotJson) as List<dynamic>;
    } catch (_) {
      return false;
    }

    // Find the specific song in the snapshot.
    Map<String, dynamic>? targetData;
    for (final raw in songMaps) {
      final data = raw as Map<String, dynamic>;
      if (data['file_path'] == filePath) {
        targetData = data;
        break;
      }
    }

    if (targetData == null) return false;

    // Look up the current DB record.
    final currentSong = await _db.getSongByPath(filePath);
    if (currentSong == null) return false;

    try {
      // Write metadata back to the file.
      await _id3Writer.writeMetadataFromMap(targetData);

      // Update DB.
      final restoredSong = SongModel.fromMap({
        ...targetData,
        'id': currentSong.id,
      });
      await _db.updateSong(restoredSong);

      return true;
    } catch (_) {
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Clear
  // ═══════════════════════════════════════════════════════════════════════════

  /// Deletes **all** backup snapshots from the database.
  Future<void> clearAllBackups() async {
    final snapshots = await _db.getAllBackupSnapshots();
    for (final s in snapshots) {
      if (s.id != null) {
        await _db.deleteBackupSnapshot(s.id!);
      }
    }
  }

  /// Deletes a specific snapshot by its ID.
  Future<void> deleteSnapshot(int id) async {
    await _db.deleteBackupSnapshot(id);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Internal helpers
  // ═══════════════════════════════════════════════════════════════════════════

  /// Keeps only the most recent [_maxSnapshots] snapshots and deletes the rest.
  Future<void> _pruneOldSnapshots() async {
    final snapshots = await _db.getAllBackupSnapshots(); // newest first
    if (snapshots.length <= _maxSnapshots) return;

    for (var i = _maxSnapshots; i < snapshots.length; i++) {
      final id = snapshots[i].id;
      if (id != null) {
        await _db.deleteBackupSnapshot(id);
      }
    }
  }
}
