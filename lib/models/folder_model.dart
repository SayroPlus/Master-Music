/// Represents a music folder being monitored by the app.
class FolderModel {
  final int? id;
  final String folderPath;
  final String folderName;
  final int songCount;
  final int totalSize; // bytes
  final bool isSelected;
  final DateTime? lastScanned;

  const FolderModel({
    this.id,
    required this.folderPath,
    required this.folderName,
    this.songCount = 0,
    this.totalSize = 0,
    this.isSelected = true,
    this.lastScanned,
  });

  /// Human-readable total size string (e.g. "1.2 GB").
  String get formattedSize {
    if (totalSize < 1024) return '$totalSize B';
    if (totalSize < 1024 * 1024) {
      return '${(totalSize / 1024).toStringAsFixed(1)} KB';
    }
    if (totalSize < 1024 * 1024 * 1024) {
      return '${(totalSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(totalSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Creates a [FolderModel] from a database row map.
  factory FolderModel.fromMap(Map<String, dynamic> map) {
    return FolderModel(
      id: map['id'] as int?,
      folderPath: map['folder_path'] as String,
      folderName: map['folder_name'] as String,
      songCount: map['song_count'] as int? ?? 0,
      totalSize: map['total_size'] as int? ?? 0,
      isSelected: (map['is_selected'] as int?) == 1,
      lastScanned: map['last_scanned'] != null
          ? DateTime.parse(map['last_scanned'] as String)
          : null,
    );
  }

  /// Converts this model to a map suitable for database insertion.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'folder_path': folderPath,
      'folder_name': folderName,
      'song_count': songCount,
      'total_size': totalSize,
      'is_selected': isSelected ? 1 : 0,
      'last_scanned': lastScanned?.toIso8601String(),
    };
  }

  /// Creates a copy with the given fields replaced.
  FolderModel copyWith({
    int? id,
    String? folderPath,
    String? folderName,
    int? songCount,
    int? totalSize,
    bool? isSelected,
    DateTime? lastScanned,
  }) {
    return FolderModel(
      id: id ?? this.id,
      folderPath: folderPath ?? this.folderPath,
      folderName: folderName ?? this.folderName,
      songCount: songCount ?? this.songCount,
      totalSize: totalSize ?? this.totalSize,
      isSelected: isSelected ?? this.isSelected,
      lastScanned: lastScanned ?? this.lastScanned,
    );
  }

  @override
  String toString() {
    return 'FolderModel(id: $id, name: $folderName, songs: $songCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FolderModel && other.folderPath == folderPath;
  }

  @override
  int get hashCode => folderPath.hashCode;
}
