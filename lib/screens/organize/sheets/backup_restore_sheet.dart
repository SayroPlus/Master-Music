import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../models/backup_snapshot_model.dart';
import '../../../../services/backup_service.dart';

class BackupRestoreSheet extends ConsumerStatefulWidget {
  final Future<void> Function(BackupSnapshotModel) onRestore;

  const BackupRestoreSheet({super.key, required this.onRestore});

  @override
  ConsumerState<BackupRestoreSheet> createState() => _BackupRestoreSheetState();
}

class _BackupRestoreSheetState extends ConsumerState<BackupRestoreSheet> {
  final BackupService _backupService = BackupService();
  List<BackupSnapshotModel> _snapshots = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSnapshots();
  }

  Future<void> _loadSnapshots() async {
    setState(() => _isLoading = true);
    final snapshots = await _backupService.getAvailableSnapshots();
    if (mounted) {
      setState(() {
        _snapshots = snapshots;
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmRestore(BackupSnapshotModel snapshot) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Restore'),
        content: Text(
          'This will overwrite existing song metadata to perfectly match the state from:\n\n'
          '${snapshot.label}\n\n'
          'This operation cannot be undone. Proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Restore Metadata'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      Navigator.pop(context); // Close the sheet
      widget.onRestore(snapshot);
    }
  }

  Future<void> _deleteSnapshot(int id) async {
    await _backupService.deleteSnapshot(id);
    _loadSnapshots();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.restore, color: AppColors.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Backup & Restore',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Undo bulk metadata or folder changes by restoring a snapshot.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_snapshots.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Center(
                  child: Text(
                    'No backups available.\nBackups are created automatically before bulk operations.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(
                        0.6,
                      ),
                    ),
                  ),
                ),
              )
            else
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _snapshots.length,
                  itemBuilder: (context, index) {
                    final snapshot = _snapshots[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          snapshot.label,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${snapshot.songCount} songs • ${snapshot.createdAt.toString().split('.')[0]}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              color: AppColors.error,
                              onPressed: () => _deleteSnapshot(snapshot.id!),
                            ),
                            ElevatedButton(
                              onPressed: () => _confirmRestore(snapshot),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Restore'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () async {
                setState(() => _isLoading = true);

                // We mock creating a manual snapshot here for demo
                await _loadSnapshots();
              },
              icon: const Icon(Icons.save),
              label: const Text('Create Manual Backup'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
