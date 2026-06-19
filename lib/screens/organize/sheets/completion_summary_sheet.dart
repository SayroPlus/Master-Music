import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';

class CompletionSummarySheet extends ConsumerWidget {
  final int fixedCount;
  final int skippedCount;
  final int failedCount;
  final List<String> errorMessages;
  final bool canUndo;
  final VoidCallback onUndo;
  final VoidCallback onViewChanges;

  const CompletionSummarySheet({
    super.key,
    required this.fixedCount,
    required this.skippedCount,
    required this.failedCount,
    required this.errorMessages,
    required this.canUndo,
    required this.onUndo,
    required this.onViewChanges,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hasErrors = failedCount > 0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  hasErrors ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                  color: hasErrors ? AppColors.error : Colors.green,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasErrors ? 'Completed with Errors' : 'Done! Here\'s what happened:',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Summary metrics
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn(context, 'Fixed', fixedCount, Colors.green),
                _buildStatColumn(context, 'Skipped', skippedCount, theme.disabledColor),
                _buildStatColumn(context, 'Failed', failedCount, AppColors.error),
              ],
            ),
            
            const SizedBox(height: 24),

            // Errors Expandable List
            if (hasErrors)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.error.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Theme(
                  data: theme.copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: Text(
                      '$failedCount files failed',
                      style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                    ),
                    iconColor: AppColors.error,
                    collapsedIconColor: AppColors.error,
                    children: [
                      Container(
                        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.2),
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: errorMessages.length,
                          itemBuilder: (ctx, i) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                '• ${errorMessages[i]}',
                                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.error),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (hasErrors) const SizedBox(height: 24),

            // Actions
            Row(
              children: [
                if (canUndo)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onUndo();
                      },
                      icon: const Icon(Icons.undo),
                      label: const Text('Undo All Changes'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                      ),
                    ),
                  ),
                if (canUndo) const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onViewChanges();
                    },
                    icon: const Icon(Icons.list),
                    label: const Text('View Changes'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(BuildContext context, String label, int value, Color color) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value.toString(),
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}
