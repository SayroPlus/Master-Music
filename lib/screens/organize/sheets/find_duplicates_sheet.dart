import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../models/song_model.dart';
import '../../../../services/duplicate_service.dart';

class FindDuplicatesSheet extends ConsumerStatefulWidget {
  final VoidCallback onScan;
  final Function(List<DuplicateGroup>) onResolveAll;
  
  final List<DuplicateGroup> duplicates;
  final bool isScanning;

  const FindDuplicatesSheet({
    super.key,
    required this.onScan,
    required this.onResolveAll,
    this.duplicates = const [],
    this.isScanning = false,
  });

  @override
  ConsumerState<FindDuplicatesSheet> createState() => _FindDuplicatesSheetState();
}

class _FindDuplicatesSheetState extends ConsumerState<FindDuplicatesSheet> {
  // Local state for UI prototyping before full provider hooks are implemented
  void _runScan() {
    widget.onScan();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isScanning = widget.isScanning;
    final hasResults = widget.duplicates.isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 24.0, bottom: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.copy_all, color: AppColors.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Find Duplicates',
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
            const SizedBox(height: 16),
            
            if (isScanning)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Scanning library for acoustic and metadata matches...'),
                    ],
                  ),
                ),
              )
            else if (!hasResults)
              Column(
                children: [
                  Text(
                    'Detect identical and highly similar audio files based on acoustic fingerprints and metadata.',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _runScan,
                    icon: const Icon(Icons.search),
                    label: const Text('Scan for Duplicates'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  Container(
                    height: MediaQuery.of(context).size.height * 0.4,
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.dividerColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: widget.duplicates.length,
                      separatorBuilder: (context, index) => const Divider(height: 24),
                      itemBuilder: (context, index) {
                        return _buildDuplicateGroup(theme, widget.duplicates[index]);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onResolveAll(widget.duplicates);
                    },
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Resolve All (Keep Best)'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDuplicateGroup(ThemeData theme, DuplicateGroup group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Group: ${group.songs.first.displayTitle}',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...group.songs.asMap().entries.map((entry) {
          final idx = entry.key;
          final song = entry.value;
          final isRecommended = idx == group.recommendedKeepIndex;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isRecommended 
                    ? Colors.green.withOpacity(0.1)
                    : theme.colorScheme.surfaceContainerHighest,
                border: Border.all(
                  color: isRecommended ? Colors.green : theme.dividerColor,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          song.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isRecommended)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'RECOMMENDED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Size: ${(song.fileSize / (1024 * 1024)).toStringAsFixed(1)} MB • ${song.bitrate != null ? (song.bitrate! ~/ 1000) : "???"} kbps',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
