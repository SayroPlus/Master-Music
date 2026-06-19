import 'song_model.dart';

/// Represents a group of duplicate audio files detected in the library.
class DuplicateGroupModel {
  final String groupId;
  final List<SongModel> songs;
  final String detectionMethod; // 'hash' or 'fingerprint'
  final int recommendedKeepIndex;

  const DuplicateGroupModel({
    required this.groupId,
    required this.songs,
    required this.detectionMethod,
    this.recommendedKeepIndex = 0,
  });

  /// Number of duplicates in this group.
  int get count => songs.length;

  /// The song recommended to keep (usually highest quality / best metadata).
  SongModel get recommendedKeep => songs[recommendedKeepIndex];

  /// Songs that are candidates for removal (everything except the recommended one).
  List<SongModel> get removalCandidates {
    return [
      for (int i = 0; i < songs.length; i++)
        if (i != recommendedKeepIndex) songs[i],
    ];
  }

  /// Total space that would be freed by removing all duplicates except the kept one.
  int get potentialSavingsBytes {
    return removalCandidates.fold(0, (sum, song) => sum + song.fileSize);
  }

  /// Human-readable potential savings string.
  String get formattedSavings {
    final bytes = potentialSavingsBytes;
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  String toString() {
    return 'DuplicateGroupModel(groupId: $groupId, count: $count, '
        'method: $detectionMethod)';
  }
}
