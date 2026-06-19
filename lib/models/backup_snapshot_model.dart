/// Represents a point-in-time snapshot of all song metadata,
/// used for undo/rollback of bulk operations.
class BackupSnapshotModel {
  final int? id;
  final DateTime createdAt;
  final String label; // e.g. "Before bulk fix - 12 Jan 2025"
  final String snapshotJson; // JSON of all song metadata at that point
  final int songCount;

  const BackupSnapshotModel({
    this.id,
    required this.createdAt,
    required this.label,
    required this.snapshotJson,
    required this.songCount,
  });

  /// Creates a [BackupSnapshotModel] from a database row map.
  factory BackupSnapshotModel.fromMap(Map<String, dynamic> map) {
    return BackupSnapshotModel(
      id: map['id'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      label: map['label'] as String,
      snapshotJson: map['snapshot_json'] as String,
      songCount: map['song_count'] as int,
    );
  }

  /// Converts this model to a map suitable for database insertion.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'created_at': createdAt.toIso8601String(),
      'label': label,
      'snapshot_json': snapshotJson,
      'song_count': songCount,
    };
  }

  @override
  String toString() {
    return 'BackupSnapshotModel(id: $id, label: $label, songs: $songCount)';
  }
}
