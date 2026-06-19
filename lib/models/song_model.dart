/// Represents a song/audio file in the library.
class SongModel {
  final int? id;
  final String filePath;
  final String fileName;
  final String? title;
  final String? artist;
  final String? album;
  final String? genre;
  final String? year;
  final String? trackNumber;
  final int? duration; // milliseconds
  final int fileSize; // bytes
  final int? bitrate;
  final String format; // mp3, flac, wav, etc.
  final String? coverArtPath; // locally cached cover art
  final String? coverArtUrl;
  final String? acoustId; // AcoustID fingerprint
  final String? mbid; // MusicBrainz recording ID
  final double? confidenceScore; // 0.0 – 1.0
  final String? confidenceLevel; // 'high', 'medium', 'low', 'unidentified'
  final bool hasBeenProcessed;
  final bool isModified;
  final bool isDuplicate;
  final String? duplicateGroupId;
  final DateTime dateAdded;
  final DateTime lastModified;
  final int folderId; // foreign key → folders.id

  const SongModel({
    this.id,
    required this.filePath,
    required this.fileName,
    this.title,
    this.artist,
    this.album,
    this.genre,
    this.year,
    this.trackNumber,
    this.duration,
    required this.fileSize,
    this.bitrate,
    required this.format,
    this.coverArtPath,
    this.coverArtUrl,
    this.acoustId,
    this.mbid,
    this.confidenceScore,
    this.confidenceLevel,
    this.hasBeenProcessed = false,
    this.isModified = false,
    this.isDuplicate = false,
    this.duplicateGroupId,
    required this.dateAdded,
    required this.lastModified,
    required this.folderId,
  });

  // ── Display helpers ─────────────────────────────────────────────────────

  /// Display title — falls back to file name if title metadata is missing.
  String get displayTitle => title ?? fileName;

  /// Display artist — falls back to 'Unknown Artist'.
  String get displayArtist => artist ?? 'Unknown Artist';

  /// Display album — falls back to 'Unknown Album'.
  String get displayAlbum => album ?? 'Unknown Album';

  /// Duration formatted as mm:ss.
  String get formattedDuration {
    if (duration == null) return '--:--';
    final minutes = (duration! ~/ 60000).toString().padLeft(2, '0');
    final seconds = ((duration! % 60000) ~/ 1000).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Human-readable file size (e.g. "3.2 MB").
  String get formattedFileSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Human-readable bitrate (e.g. "320 kbps").
  String get formattedBitrate {
    if (bitrate == null) return 'Unknown';
    return '${bitrate! ~/ 1000} kbps';
  }

  // ── Serialization ───────────────────────────────────────────────────────

  /// Creates a [SongModel] from a database row map.
  factory SongModel.fromMap(Map<String, dynamic> map) {
    return SongModel(
      id: map['id'] as int?,
      filePath: map['file_path'] as String,
      fileName: map['file_name'] as String,
      title: map['title'] as String?,
      artist: map['artist'] as String?,
      album: map['album'] as String?,
      genre: map['genre'] as String?,
      year: map['year'] as String?,
      trackNumber: map['track_number'] as String?,
      duration: map['duration'] as int?,
      fileSize: map['file_size'] as int,
      bitrate: map['bitrate'] as int?,
      format: map['format'] as String,
      coverArtPath: map['cover_art_path'] as String?,
      coverArtUrl: map['cover_art_url'] as String?,
      acoustId: map['acoust_id'] as String?,
      mbid: map['mbid'] as String?,
      confidenceScore: (map['confidence_score'] as num?)?.toDouble(),
      confidenceLevel: map['confidence_level'] as String?,
      hasBeenProcessed: (map['has_been_processed'] as int?) == 1,
      isModified: (map['is_modified'] as int?) == 1,
      isDuplicate: (map['is_duplicate'] as int?) == 1,
      duplicateGroupId: map['duplicate_group_id'] as String?,
      dateAdded: DateTime.parse(map['date_added'] as String),
      lastModified: DateTime.parse(map['last_modified'] as String),
      folderId: map['folder_id'] as int,
    );
  }

  /// Converts this model to a map suitable for database insertion.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'file_path': filePath,
      'file_name': fileName,
      'title': title,
      'artist': artist,
      'album': album,
      'genre': genre,
      'year': year,
      'track_number': trackNumber,
      'duration': duration,
      'file_size': fileSize,
      'bitrate': bitrate,
      'format': format,
      'cover_art_path': coverArtPath,
      'cover_art_url': coverArtUrl,
      'acoust_id': acoustId,
      'mbid': mbid,
      'confidence_score': confidenceScore,
      'confidence_level': confidenceLevel,
      'has_been_processed': hasBeenProcessed ? 1 : 0,
      'is_modified': isModified ? 1 : 0,
      'is_duplicate': isDuplicate ? 1 : 0,
      'duplicate_group_id': duplicateGroupId,
      'date_added': dateAdded.toIso8601String(),
      'last_modified': lastModified.toIso8601String(),
      'folder_id': folderId,
    };
  }

  /// Creates a copy with the given fields replaced.
  SongModel copyWith({
    int? id,
    String? filePath,
    String? fileName,
    String? title,
    String? artist,
    String? album,
    String? genre,
    String? year,
    String? trackNumber,
    int? duration,
    int? fileSize,
    int? bitrate,
    String? format,
    String? coverArtPath,
    String? coverArtUrl,
    String? acoustId,
    String? mbid,
    double? confidenceScore,
    String? confidenceLevel,
    bool? hasBeenProcessed,
    bool? isModified,
    bool? isDuplicate,
    String? duplicateGroupId,
    DateTime? dateAdded,
    DateTime? lastModified,
    int? folderId,
  }) {
    return SongModel(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      genre: genre ?? this.genre,
      year: year ?? this.year,
      trackNumber: trackNumber ?? this.trackNumber,
      duration: duration ?? this.duration,
      fileSize: fileSize ?? this.fileSize,
      bitrate: bitrate ?? this.bitrate,
      format: format ?? this.format,
      coverArtPath: coverArtPath ?? this.coverArtPath,
      coverArtUrl: coverArtUrl ?? this.coverArtUrl,
      acoustId: acoustId ?? this.acoustId,
      mbid: mbid ?? this.mbid,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      confidenceLevel: confidenceLevel ?? this.confidenceLevel,
      hasBeenProcessed: hasBeenProcessed ?? this.hasBeenProcessed,
      isModified: isModified ?? this.isModified,
      isDuplicate: isDuplicate ?? this.isDuplicate,
      duplicateGroupId: duplicateGroupId ?? this.duplicateGroupId,
      dateAdded: dateAdded ?? this.dateAdded,
      lastModified: lastModified ?? this.lastModified,
      folderId: folderId ?? this.folderId,
    );
  }

  @override
  String toString() {
    return 'SongModel(id: $id, title: $displayTitle, artist: $displayArtist, '
        'format: $format, confidence: $confidenceLevel)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SongModel && other.id == id && other.filePath == filePath;
  }

  @override
  int get hashCode => filePath.hashCode;
}
