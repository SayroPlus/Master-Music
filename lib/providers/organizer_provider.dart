import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/backup_snapshot_model.dart';
import '../models/song_model.dart';

/// Represents a proposed file organization action.
class OrganizeAction {
  final SongModel song;
  final String suggestedPath;
  final String reason;
  final double confidence;
  final bool isApproved;

  const OrganizeAction({
    required this.song,
    required this.suggestedPath,
    required this.reason,
    this.confidence = 0.0,
    this.isApproved = false,
  });

  OrganizeAction copyWith({bool? isApproved}) {
    return OrganizeAction(
      song: song,
      suggestedPath: suggestedPath,
      reason: reason,
      confidence: confidence,
      isApproved: isApproved ?? this.isApproved,
    );
  }
}

/// State for the organize/AI feature, including operation tracking and backup.
class OrganizerState {
  final List<OrganizeAction> actions;
  final bool isAnalyzing;
  final bool isApplying;

  // ── Operation progress tracking ──────────────────────────────────────────
  /// Whether any background operation (scan, fix, restore) is running.
  final bool isProcessing;

  /// Number of songs processed so far in the current operation.
  final int processedCount;

  /// Total number of songs in the current operation.
  final int totalCount;

  /// Display name of the song currently being processed.
  final String currentSongName;

  /// Accumulated error messages from the current operation.
  final List<String> errors;

  // ── Backup ───────────────────────────────────────────────────────────────
  /// The most recent backup snapshot (created just before a bulk operation).
  final BackupSnapshotModel? lastBackupSnapshot;

  final String? error;

  const OrganizerState({
    this.actions = const [],
    this.isAnalyzing = false,
    this.isApplying = false,
    this.isProcessing = false,
    this.processedCount = 0,
    this.totalCount = 0,
    this.currentSongName = '',
    this.errors = const [],
    this.lastBackupSnapshot,
    this.error,
  });

  /// Progress percentage (0.0 – 1.0).
  double get progress {
    if (totalCount == 0) return 0.0;
    return processedCount / totalCount;
  }

  /// Human-readable progress string, e.g. "12 / 48".
  String get progressLabel {
    if (totalCount == 0) return '';
    return '$processedCount / $totalCount';
  }

  /// Whether the last operation finished with errors.
  bool get hasErrors => errors.isNotEmpty;

  /// Whether a backup is available for undo.
  bool get canUndo => lastBackupSnapshot != null;

  OrganizerState copyWith({
    List<OrganizeAction>? actions,
    bool? isAnalyzing,
    bool? isApplying,
    bool? isProcessing,
    int? processedCount,
    int? totalCount,
    String? currentSongName,
    List<String>? errors,
    BackupSnapshotModel? lastBackupSnapshot,
    // Use a sentinel to allow explicitly setting to null.
    bool clearLastBackup = false,
    String? error,
    bool clearError = false,
  }) {
    return OrganizerState(
      actions: actions ?? this.actions,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      isApplying: isApplying ?? this.isApplying,
      isProcessing: isProcessing ?? this.isProcessing,
      processedCount: processedCount ?? this.processedCount,
      totalCount: totalCount ?? this.totalCount,
      currentSongName: currentSongName ?? this.currentSongName,
      errors: errors ?? this.errors,
      lastBackupSnapshot: clearLastBackup
          ? null
          : (lastBackupSnapshot ?? this.lastBackupSnapshot),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Manages the AI-powered organization workflow and operation state.
class OrganizerNotifier extends StateNotifier<OrganizerState> {
  OrganizerNotifier() : super(const OrganizerState());

  // ── Organize actions ─────────────────────────────────────────────────────

  /// Sets the proposed actions after analysis.
  void setActions(List<OrganizeAction> actions) {
    state = state.copyWith(
      actions: actions,
      totalCount: actions.length,
      isAnalyzing: false,
    );
  }

  /// Toggles approval of a specific action.
  void toggleApproval(int index) {
    final updated = List<OrganizeAction>.from(state.actions);
    updated[index] = updated[index].copyWith(
      isApproved: !updated[index].isApproved,
    );
    state = state.copyWith(actions: updated);
  }

  /// Approves all proposed actions.
  void approveAll() {
    final updated =
        state.actions.map((a) => a.copyWith(isApproved: true)).toList();
    state = state.copyWith(actions: updated);
  }

  /// Marks analysis as in progress.
  void startAnalysis() {
    state = state.copyWith(
      isAnalyzing: true,
      clearError: true,
      actions: [],
    );
  }

  // ── Operation progress ───────────────────────────────────────────────────

  /// Signals that a new batch operation is starting.
  ///
  /// [total] is the number of songs to process.
  /// [backupSnapshot] is the pre-operation backup (for undo).
  void startProcessing({
    required int total,
    BackupSnapshotModel? backupSnapshot,
  }) {
    state = state.copyWith(
      isProcessing: true,
      processedCount: 0,
      totalCount: total,
      currentSongName: '',
      errors: [],
      lastBackupSnapshot: backupSnapshot,
      clearError: true,
    );
  }

  /// Updates progress during a batch operation.
  void updateProgress({
    required int processed,
    String? songName,
  }) {
    state = state.copyWith(
      processedCount: processed,
      currentSongName: songName ?? state.currentSongName,
    );
  }

  /// Records an error that occurred while processing a specific song.
  void addError(String errorMessage) {
    state = state.copyWith(
      errors: [...state.errors, errorMessage],
    );
  }

  /// Signals that the batch operation has finished.
  void finishProcessing({String? error}) {
    state = state.copyWith(
      isProcessing: false,
      isApplying: false,
      currentSongName: '',
      error: error,
    );
  }

  // ── Backup / undo ────────────────────────────────────────────────────────

  /// Stores a reference to the last backup snapshot for undo.
  void setLastBackup(BackupSnapshotModel snapshot) {
    state = state.copyWith(lastBackupSnapshot: snapshot);
  }

  /// Clears the undo backup reference (e.g. after a successful undo).
  void clearLastBackup() {
    state = state.copyWith(clearLastBackup: true);
  }

  // ── General ──────────────────────────────────────────────────────────────

  /// Resets the organizer state to defaults.
  void reset() {
    state = const OrganizerState();
  }
}

/// Provider for the organizer state and notifier.
final organizerProvider =
    StateNotifierProvider<OrganizerNotifier, OrganizerState>((ref) {
  return OrganizerNotifier();
});
