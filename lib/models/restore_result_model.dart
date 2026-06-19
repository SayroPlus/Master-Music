/// Encapsulates the outcome of a snapshot restore operation.
///
/// Tracks how many songs were successfully restored, how many failed,
/// and collects error messages for failed restorations.
class RestoreResult {
  final int successCount;
  final int failCount;
  final List<String> errors;

  const RestoreResult({
    required this.successCount,
    required this.failCount,
    this.errors = const [],
  });

  /// Total songs that were attempted.
  int get totalAttempted => successCount + failCount;

  /// Whether the entire restore completed without errors.
  bool get isFullSuccess => failCount == 0 && errors.isEmpty;

  /// Human-readable summary.
  String get summary {
    if (isFullSuccess) {
      return 'Successfully restored $successCount song(s).';
    }
    return 'Restored $successCount, failed $failCount of $totalAttempted song(s).';
  }

  @override
  String toString() =>
      'RestoreResult(success: $successCount, fail: $failCount, errors: ${errors.length})';
}
