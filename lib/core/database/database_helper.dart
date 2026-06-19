import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/song_model.dart';
import '../../models/folder_model.dart';
import '../../models/backup_snapshot_model.dart';

/// Singleton helper that manages the SQLite database lifecycle.
///
/// Provides full CRUD operations for songs, folders, and backup snapshots,
/// plus specialized query methods for the dashboard and organizer features.
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  static const String _dbName = 'music_organizer.db';
  static const int _dbVersion = 1;

  /// Returns the database instance, creating it if necessary.
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final path = join(documentsDir.path, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Schema
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _onCreate(Database db, int version) async {
    // ── Songs table ───────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE songs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_path TEXT NOT NULL UNIQUE,
        file_name TEXT NOT NULL,
        title TEXT,
        artist TEXT,
        album TEXT,
        genre TEXT,
        year TEXT,
        track_number TEXT,
        duration INTEGER,
        file_size INTEGER NOT NULL,
        bitrate INTEGER,
        format TEXT NOT NULL,
        cover_art_path TEXT,
        cover_art_url TEXT,
        acoust_id TEXT,
        mbid TEXT,
        confidence_score REAL,
        confidence_level TEXT,
        has_been_processed INTEGER NOT NULL DEFAULT 0,
        is_modified INTEGER NOT NULL DEFAULT 0,
        is_duplicate INTEGER NOT NULL DEFAULT 0,
        duplicate_group_id TEXT,
        date_added TEXT NOT NULL,
        last_modified TEXT NOT NULL,
        folder_id INTEGER NOT NULL,
        FOREIGN KEY (folder_id) REFERENCES folders(id) ON DELETE CASCADE
      )
    ''');

    // ── Folders table ─────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE folders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        folder_path TEXT NOT NULL UNIQUE,
        folder_name TEXT NOT NULL,
        song_count INTEGER NOT NULL DEFAULT 0,
        total_size INTEGER NOT NULL DEFAULT 0,
        is_selected INTEGER NOT NULL DEFAULT 1,
        last_scanned TEXT
      )
    ''');

    // ── Backup snapshots table ────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE backup_snapshots (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at TEXT NOT NULL,
        label TEXT NOT NULL,
        snapshot_json TEXT NOT NULL,
        song_count INTEGER NOT NULL
      )
    ''');

    // ── Indexes ───────────────────────────────────────────────────────────
    await db.execute('CREATE INDEX idx_songs_file_path ON songs(file_path)');
    await db.execute('CREATE INDEX idx_songs_folder_id ON songs(folder_id)');
    await db.execute('CREATE INDEX idx_songs_is_duplicate ON songs(is_duplicate)');
    await db.execute('CREATE INDEX idx_songs_artist ON songs(artist)');
    await db.execute('CREATE INDEX idx_songs_album ON songs(album)');
    await db.execute('CREATE INDEX idx_songs_has_been_processed ON songs(has_been_processed)');
    await db.execute('CREATE INDEX idx_folders_folder_path ON folders(folder_path)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle future schema migrations here.
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Song CRUD
  // ═══════════════════════════════════════════════════════════════════════════

  /// Inserts a new song. Returns the inserted row id.
  Future<int> insertSong(SongModel song) async {
    final db = await database;
    return await db.insert(
      'songs',
      song.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Inserts multiple songs in a single batch.
  Future<void> insertSongs(List<SongModel> songs) async {
    final db = await database;
    final batch = db.batch();
    for (final song in songs) {
      batch.insert('songs', song.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// Updates an existing song. Returns the number of rows affected.
  Future<int> updateSong(SongModel song) async {
    final db = await database;
    return await db.update(
      'songs',
      song.toMap(),
      where: 'id = ?',
      whereArgs: [song.id],
    );
  }

  /// Updates the file path of a song. Useful after renames/moves.
  Future<int> updateSongPath(int songId, String newPath) async {
    final db = await database;
    return await db.update(
      'songs',
      {
        'file_path': newPath,
        'file_name': basename(newPath),
        'last_modified': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [songId],
    );
  }

  /// Deletes a song by its id. Returns the number of rows affected.
  Future<int> deleteSong(int id) async {
    final db = await database;
    return await db.delete('songs', where: 'id = ?', whereArgs: [id]);
  }

  /// Deletes all songs belonging to a specific folder.
  Future<int> deleteSongsByFolder(int folderId) async {
    final db = await database;
    return await db.delete(
      'songs',
      where: 'folder_id = ?',
      whereArgs: [folderId],
    );
  }

  /// Returns a single song by id, or null if not found.
  Future<SongModel?> getSongById(int id) async {
    final db = await database;
    final rows = await db.query('songs', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return SongModel.fromMap(rows.first);
  }

  /// Returns a single song by file path, or null if not found.
  Future<SongModel?> getSongByPath(String filePath) async {
    final db = await database;
    final rows = await db.query(
      'songs',
      where: 'file_path = ?',
      whereArgs: [filePath],
    );
    if (rows.isEmpty) return null;
    return SongModel.fromMap(rows.first);
  }

  /// Returns all songs, ordered by title.
  Future<List<SongModel>> getAllSongs() async {
    final db = await database;
    final rows = await db.query('songs', orderBy: 'title ASC');
    return rows.map((r) => SongModel.fromMap(r)).toList();
  }

  /// Returns all songs belonging to a specific folder.
  Future<List<SongModel>> getSongsByFolder(int folderId) async {
    final db = await database;
    final rows = await db.query(
      'songs',
      where: 'folder_id = ?',
      whereArgs: [folderId],
      orderBy: 'title ASC',
    );
    return rows.map((r) => SongModel.fromMap(r)).toList();
  }

  /// Returns songs that haven't been processed (metadata lookup pending).
  Future<List<SongModel>> getSongsWithMissingMetadata() async {
    final db = await database;
    final rows = await db.query(
      'songs',
      where: 'has_been_processed = 0',
      orderBy: 'date_added ASC',
    );
    return rows.map((r) => SongModel.fromMap(r)).toList();
  }

  /// Returns all songs flagged as duplicates.
  Future<List<SongModel>> getDuplicateSongs() async {
    final db = await database;
    final rows = await db.query(
      'songs',
      where: 'is_duplicate = 1',
      orderBy: 'duplicate_group_id ASC, file_name ASC',
    );
    return rows.map((r) => SongModel.fromMap(r)).toList();
  }

  /// Marks a specific list of file paths as duplicates.
  Future<int> markDuplicates(List<String> filePaths, {String? groupId}) async {
    if (filePaths.isEmpty) return 0;
    final db = await database;
    
    // SQLite limits parameters to 999 max by default, handle chunking if needed
    int affected = 0;
    for (var i = 0; i < filePaths.length; i += 900) {
      final chunk = filePaths.skip(i).take(900).toList();
      final placeholders = List.filled(chunk.length, '?').join(',');
      
      final Map<String, dynamic> updateVals = {'is_duplicate': 1};
      if (groupId != null) {
        updateVals['duplicate_group_id'] = groupId;
      }

      affected += await db.update(
        'songs',
        updateVals,
        where: 'file_path IN ($placeholders)',
        whereArgs: chunk,
      );
    }
    return affected;
  }

  /// Removes a song by its exact file path.
  Future<int> removeSong(String filePath) async {
    final db = await database;
    return await db.delete('songs', where: 'file_path = ?', whereArgs: [filePath]);
  }

  /// Returns the total number of files flagged as duplicates.
  Future<int> getDuplicateCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as c FROM songs WHERE is_duplicate = 1');
    return (result.first['c'] as int?) ?? 0;
  }

  /// Returns total byte storage wasted by duplicate variants.
  Future<int> getStorageWastedByDuplicates() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COALESCE(SUM(file_size), 0) as size FROM songs WHERE is_duplicate = 1');
    return (result.first['size'] as int?) ?? 0;
  }

  /// Returns recently processed/fixed songs.
  Future<List<SongModel>> getRecentlyFixedSongs({int limit = 10}) async {
    final db = await database;
    final rows = await db.query(
      'songs',
      where: 'is_modified = 1',
      orderBy: 'last_modified DESC',
      limit: limit,
    );
    return rows.map((r) => SongModel.fromMap(r)).toList();
  }

  /// Returns aggregate statistics about the song library.
  ///
  /// Keys: totalSongs, processedSongs, unprocessedSongs, duplicateSongs,
  ///        totalSizeBytes, identifiedSongs, modifiedSongs,
  ///        highConfidence, mediumConfidence, lowConfidence, unidentified
  Future<Map<String, int>> getSongStats() async {
    final db = await database;

    final total =
        await db.rawQuery('SELECT COUNT(*) as c FROM songs');
    final processed =
        await db.rawQuery('SELECT COUNT(*) as c FROM songs WHERE has_been_processed = 1');
    final unprocessed =
        await db.rawQuery('SELECT COUNT(*) as c FROM songs WHERE has_been_processed = 0');
    final duplicates =
        await db.rawQuery('SELECT COUNT(*) as c FROM songs WHERE is_duplicate = 1');
    final totalSize =
        await db.rawQuery('SELECT COALESCE(SUM(file_size), 0) as c FROM songs');
    final identified =
        await db.rawQuery('SELECT COUNT(*) as c FROM songs WHERE mbid IS NOT NULL');
    final modified =
        await db.rawQuery('SELECT COUNT(*) as c FROM songs WHERE is_modified = 1');
    final high =
        await db.rawQuery("SELECT COUNT(*) as c FROM songs WHERE confidence_level = 'high'");
    final medium =
        await db.rawQuery("SELECT COUNT(*) as c FROM songs WHERE confidence_level = 'medium'");
    final low =
        await db.rawQuery("SELECT COUNT(*) as c FROM songs WHERE confidence_level = 'low'");
    final unidentified =
        await db.rawQuery("SELECT COUNT(*) as c FROM songs WHERE confidence_level = 'unidentified' OR confidence_level IS NULL");
    final artists = 
        await db.rawQuery("SELECT COUNT(DISTINCT artist) as c FROM songs WHERE artist IS NOT NULL AND artist != ''");
    final albums = 
        await db.rawQuery("SELECT COUNT(DISTINCT album) as c FROM songs WHERE album IS NOT NULL AND album != ''");

    return {
      'totalSongs': (total.first['c'] as int?) ?? 0,
      'processedSongs': (processed.first['c'] as int?) ?? 0,
      'unprocessedSongs': (unprocessed.first['c'] as int?) ?? 0,
      'duplicateSongs': (duplicates.first['c'] as int?) ?? 0,
      'totalSizeBytes': (totalSize.first['c'] as int?) ?? 0,
      'identifiedSongs': (identified.first['c'] as int?) ?? 0,
      'modifiedSongs': (modified.first['c'] as int?) ?? 0,
      'highConfidence': (high.first['c'] as int?) ?? 0,
      'mediumConfidence': (medium.first['c'] as int?) ?? 0,
      'lowConfidence': (low.first['c'] as int?) ?? 0,
      'unidentified': (unidentified.first['c'] as int?) ?? 0,
      'totalArtists': (artists.first['c'] as int?) ?? 0,
      'totalAlbums': (albums.first['c'] as int?) ?? 0,
    };
  }

  /// Returns counts for metadata completeness.
  Future<Map<String, int>> getMetadataCompleteness() async {
    final db = await database;
    
    final titles = await db.rawQuery("SELECT COUNT(*) as c FROM songs WHERE title IS NOT NULL AND title != ''");
    final artists = await db.rawQuery("SELECT COUNT(*) as c FROM songs WHERE artist IS NOT NULL AND artist != ''");
    final albums = await db.rawQuery("SELECT COUNT(*) as c FROM songs WHERE album IS NOT NULL AND album != ''");
    final covers = await db.rawQuery("SELECT COUNT(*) as c FROM songs WHERE cover_art_path IS NOT NULL AND cover_art_path != ''");
    final genres = await db.rawQuery("SELECT COUNT(*) as c FROM songs WHERE genre IS NOT NULL AND genre != ''");

    return {
      'withTitle': (titles.first['c'] as int?) ?? 0,
      'withArtist': (artists.first['c'] as int?) ?? 0,
      'withAlbum': (albums.first['c'] as int?) ?? 0,
      'withCoverArt': (covers.first['c'] as int?) ?? 0,
      'withGenre': (genres.first['c'] as int?) ?? 0,
    };
  }

  /// Returns the top N genres by song count.
  Future<Map<String, int>> getGenreDistribution({int limit = 10}) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT genre, COUNT(*) as count
      FROM songs
      WHERE genre IS NOT NULL AND genre != ''
      GROUP BY genre
      ORDER BY count DESC
      LIMIT ?
    ''', [limit]);

    return {
      for (final row in rows) row['genre'] as String: row['count'] as int,
    };
  }

  /// Returns the top N artists by song count.
  Future<Map<String, int>> getArtistDistribution({int limit = 10}) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT artist, COUNT(*) as count
      FROM songs
      WHERE artist IS NOT NULL AND artist != ''
      GROUP BY artist
      ORDER BY count DESC
      LIMIT ?
    ''', [limit]);

    return {
      for (final row in rows) row['artist'] as String: row['count'] as int,
    };
  }

  /// Returns the top N formats by song count.
  Future<Map<String, int>> getFormatDistribution() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT format, COUNT(*) as count
      FROM songs
      GROUP BY format
      ORDER BY count DESC
    ''');

    return {
      for (final row in rows) row['format'] as String: row['count'] as int,
    };
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Folder CRUD
  // ═══════════════════════════════════════════════════════════════════════════

  /// Inserts a new folder. Returns the inserted row id.
  Future<int> insertFolder(FolderModel folder) async {
    final db = await database;
    return await db.insert(
      'folders',
      folder.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Updates an existing folder. Returns the number of rows affected.
  Future<int> updateFolder(FolderModel folder) async {
    final db = await database;
    return await db.update(
      'folders',
      folder.toMap(),
      where: 'id = ?',
      whereArgs: [folder.id],
    );
  }

  /// Deletes a folder and all its songs. Returns the number of rows affected.
  Future<int> deleteFolder(int id) async {
    final db = await database;
    // Delete songs first (cascade)
    await db.delete('songs', where: 'folder_id = ?', whereArgs: [id]);
    return await db.delete('folders', where: 'id = ?', whereArgs: [id]);
  }

  /// Returns a single folder by id, or null if not found.
  Future<FolderModel?> getFolderById(int id) async {
    final db = await database;
    final rows = await db.query('folders', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return FolderModel.fromMap(rows.first);
  }

  /// Returns all folders.
  Future<List<FolderModel>> getAllFolders() async {
    final db = await database;
    final rows = await db.query('folders', orderBy: 'folder_name ASC');
    return rows.map((r) => FolderModel.fromMap(r)).toList();
  }

  /// Returns only selected (active) folders.
  Future<List<FolderModel>> getSelectedFolders() async {
    final db = await database;
    final rows = await db.query(
      'folders',
      where: 'is_selected = 1',
      orderBy: 'folder_name ASC',
    );
    return rows.map((r) => FolderModel.fromMap(r)).toList();
  }

  /// Updates the song count and total size for a folder.
  Future<void> updateFolderStats(int folderId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count, COALESCE(SUM(file_size), 0) as size
      FROM songs
      WHERE folder_id = ?
    ''', [folderId]);

    if (result.isNotEmpty) {
      await db.update(
        'folders',
        {
          'song_count': result.first['count'] as int,
          'total_size': result.first['size'] as int,
          'last_scanned': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [folderId],
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Backup Snapshot CRUD
  // ═══════════════════════════════════════════════════════════════════════════

  /// Inserts a new backup snapshot. Returns the inserted row id.
  Future<int> insertBackupSnapshot(BackupSnapshotModel snapshot) async {
    final db = await database;
    return await db.insert('backup_snapshots', snapshot.toMap());
  }

  /// Deletes a backup snapshot by id.
  Future<int> deleteBackupSnapshot(int id) async {
    final db = await database;
    return await db.delete(
      'backup_snapshots',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Returns all backup snapshots, newest first.
  Future<List<BackupSnapshotModel>> getAllBackupSnapshots() async {
    final db = await database;
    final rows = await db.query(
      'backup_snapshots',
      orderBy: 'created_at DESC',
    );
    return rows.map((r) => BackupSnapshotModel.fromMap(r)).toList();
  }

  /// Returns a single backup snapshot by id.
  Future<BackupSnapshotModel?> getBackupSnapshotById(int id) async {
    final db = await database;
    final rows = await db.query(
      'backup_snapshots',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return BackupSnapshotModel.fromMap(rows.first);
  }

  /// Returns the total number of backup snapshots.
  Future<int> getBackupSnapshotCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as c FROM backup_snapshots');
    return (result.first['c'] as int?) ?? 0;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Utilities
  // ═══════════════════════════════════════════════════════════════════════════

  /// Deletes all data from all tables.
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('songs');
    await db.delete('folders');
    await db.delete('backup_snapshots');
  }

  /// Closes the database connection.
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
