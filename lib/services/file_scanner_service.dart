import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/database/database_helper.dart';
import '../models/folder_model.dart';
import '../models/song_model.dart';
import 'metadata_service.dart';

/// Service for scanning the filesystem for audio files and building the library.
///
/// Handles folder discovery, song ingestion, and incremental rescanning.
class FileScannerService {
  final DatabaseHelper _db = DatabaseHelper();
  final MetadataService _metadata = MetadataService();

  /// Supported audio file extensions.
  static const Set<String> audioExtensions = {
    '.mp3', '.flac', '.aac', '.wav', '.m4a', '.ogg', '.opus', '.wma',
  };

  /// System/app folders excluded from automatic scanning.
  static const Set<String> _excludedFolderSegments = {
    'whatsapp',
    'telegram',
    'recordings',
    'miui',
    'sound_recorder',
    'com.sec.android.app.voicenote',
    '.cache',
    'android/data',
    'android/obb',
  };

  /// Specific path patterns to exclude.
  static const Set<String> _excludedPathPatterns = {
    'WhatsApp/Media/WhatsApp Audio',
    'MIUI/sound_recorder',
  };

  // ═══════════════════════════════════════════════════════════════════════════
  // Folder Discovery
  // ═══════════════════════════════════════════════════════════════════════════

  /// Scans the entire device storage for directories containing audio files.
  ///
  /// Returns a list of [FolderModel]s, sorted by song count descending.
  /// Automatically excludes system/hidden folders.
  Future<List<FolderModel>> scanAllFoldersWithAudio({
    void Function(String currentDir)? onProgress,
  }) async {
    final root = Directory('/storage/emulated/0');
    if (!await root.exists()) return [];

    final folderMap = <String, List<File>>{};

    await _walkDirectory(root, folderMap, onProgress);

    // Build FolderModels from discovered directories
    final folders = <FolderModel>[];
    for (final entry in folderMap.entries) {
      final dirPath = entry.key;
      final audioFiles = entry.value;
      if (audioFiles.isEmpty) continue;

      int totalSize = 0;
      for (final file in audioFiles) {
        try {
          totalSize += await file.length();
        } catch (_) {}
      }

      folders.add(FolderModel(
        folderPath: dirPath,
        folderName: p.basename(dirPath),
        songCount: audioFiles.length,
        totalSize: totalSize,
        isSelected: false, // User will select which to monitor
      ));
    }

    // Sort by song count descending
    folders.sort((a, b) => b.songCount.compareTo(a.songCount));
    return folders;
  }

  /// Recursively walks directories, populating [folderMap] with audio files.
  Future<void> _walkDirectory(
    Directory dir,
    Map<String, List<File>> folderMap,
    void Function(String)? onProgress,
  ) async {
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is Directory) {
          final dirName = p.basename(entity.path);

          // Skip hidden folders (starting with '.')
          if (dirName.startsWith('.')) continue;

          // Skip excluded system folders
          if (_isExcludedFolder(entity.path)) continue;

          onProgress?.call(entity.path);
          await _walkDirectory(entity, folderMap, onProgress);
        } else if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (audioExtensions.contains(ext)) {
            final parentDir = p.dirname(entity.path);
            folderMap.putIfAbsent(parentDir, () => []).add(entity);
          }
        }
      }
    } on FileSystemException {
      // Permission denied or inaccessible directory — skip silently
    }
  }

  /// Returns `true` if a directory path matches any exclusion pattern.
  bool _isExcludedFolder(String dirPath) {
    final lowerPath = dirPath.toLowerCase();

    // Check excluded path patterns
    for (final pattern in _excludedPathPatterns) {
      if (lowerPath.contains(pattern.toLowerCase())) return true;
    }

    // Check individual folder segments
    final segments = dirPath.split('/');
    for (final segment in segments) {
      final lowerSegment = segment.toLowerCase();
      if (_excludedFolderSegments.contains(lowerSegment)) return true;
    }

    return false;
  }

  /// Checks if a given file is a supported audio format.
  static bool isAudioFile(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    return audioExtensions.contains(ext);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Song Scanning
  // ═══════════════════════════════════════════════════════════════════════════

  /// Scans selected folders for audio files and saves them to the database.
  ///
  /// For each audio file found:
  /// - Creates a [SongModel] with file info and basic metadata
  /// - Reads metadata via the native MethodChannel
  /// - Inserts into SQLite
  ///
  /// Returns the total number of songs added.
  Future<int> scanSongsInFolders(
    List<FolderModel> selectedFolders, {
    void Function(int scanned, int total)? onProgress,
  }) async {
    int totalAdded = 0;
    int scanned = 0;

    for (final folder in selectedFolders) {
      // Ensure the folder exists in the DB and get its ID
      int folderId;
      final existingFolder = await _findFolderInDb(folder.folderPath);
      if (existingFolder != null && existingFolder.id != null) {
        folderId = existingFolder.id!;
      } else {
        folderId = await _db.insertFolder(folder);
      }

      // Find all audio files in this folder
      final audioFiles = await _listAudioFiles(folder.folderPath);

      // Process in batches for performance
      final batch = <SongModel>[];
      for (final file in audioFiles) {
        try {
          // Check if this file already exists in the DB
          final existing = await _db.getSongByPath(file.path);
          if (existing != null) {
            scanned++;
            onProgress?.call(scanned, -1); // total unknown at this point
            continue;
          }

          final song = await _buildSongModel(file, folderId);
          batch.add(song);
          totalAdded++;

          // Insert in batches of 50
          if (batch.length >= 50) {
            await _db.insertSongs(batch);
            batch.clear();
          }

          scanned++;
          onProgress?.call(scanned, -1);
        } catch (_) {
          scanned++;
          onProgress?.call(scanned, -1);
          continue;
        }
      }

      // Insert remaining songs
      if (batch.isNotEmpty) {
        await _db.insertSongs(batch);
      }

      // Update folder stats
      if (folderId > 0) {
        await _db.updateFolderStats(folderId);
      }
    }

    return totalAdded;
  }

  /// Re-scans a single folder and adds only new files.
  ///
  /// Returns the count of newly added files.
  Future<int> rescanFolder(FolderModel folder) async {
    if (folder.id == null) return 0;

    final audioFiles = await _listAudioFiles(folder.folderPath);
    int newCount = 0;

    final batch = <SongModel>[];
    for (final file in audioFiles) {
      try {
        final existing = await _db.getSongByPath(file.path);
        if (existing != null) continue;

        final song = await _buildSongModel(file, folder.id!);
        batch.add(song);
        newCount++;

        if (batch.length >= 50) {
          await _db.insertSongs(batch);
          batch.clear();
        }
      } catch (_) {
        continue;
      }
    }

    if (batch.isNotEmpty) {
      await _db.insertSongs(batch);
    }

    // Update folder stats
    await _db.updateFolderStats(folder.id!);

    return newCount;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Private helpers
  // ═══════════════════════════════════════════════════════════════════════════

  /// Lists all audio files in a directory (non-recursive for a single folder).
  Future<List<File>> _listAudioFiles(String directoryPath) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) return [];

    final files = <File>[];
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (audioExtensions.contains(ext)) {
            files.add(entity);
          }
        }
      }
    } on FileSystemException {
      // Skip inaccessible directories
    }
    return files;
  }

  /// Builds a [SongModel] from a [File], reading metadata via native channel.
  Future<SongModel> _buildSongModel(File file, int folderId) async {
    final fileStat = await file.stat();
    final fileName = p.basename(file.path);
    final ext = p.extension(file.path).toLowerCase().replaceAll('.', '');

    // Read metadata via the native Android MethodChannel
    final meta = await _metadata.readMetadata(file.path);

    return SongModel(
      filePath: file.path,
      fileName: fileName,
      title: meta['title'] as String?,
      artist: meta['artist'] as String?,
      album: meta['album'] as String?,
      genre: meta['genre'] as String?,
      year: meta['year'] as String?,
      trackNumber: meta['trackNumber'] as String?,
      duration: (meta['duration'] as num?)?.toInt(),
      fileSize: fileStat.size,
      bitrate: (meta['bitrate'] as num?)?.toInt(),
      format: ext,
      dateAdded: fileStat.modified,
      lastModified: fileStat.modified,
      folderId: folderId,
    );
  }

  /// Finds a folder in the DB by its path.
  Future<FolderModel?> _findFolderInDb(String folderPath) async {
    final db = await _db.database;
    final rows = await db.query(
      'folders',
      where: 'folder_path = ?',
      whereArgs: [folderPath],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return FolderModel.fromMap(rows.first);
  }
}
