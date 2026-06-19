import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';

class OrganizeFoldersSheet extends ConsumerStatefulWidget {
  final int totalSongs;
  final String currentStyle;
  final VoidCallback onPreview;
  final VoidCallback onApply;

  const OrganizeFoldersSheet({
    super.key,
    required this.totalSongs,
    required this.currentStyle,
    required this.onPreview,
    required this.onApply,
  });

  @override
  ConsumerState<OrganizeFoldersSheet> createState() => _OrganizeFoldersSheetState();
}

class _OrganizeFoldersSheetState extends ConsumerState<OrganizeFoldersSheet> {
  bool _cleanWithGroq = false;

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
                const Icon(Icons.folder, color: AppColors.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Organize Folders',
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
              'Move and rename ${widget.totalSongs} songs based on the selected style:',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            
            // Preview box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Target Style:', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(
                    widget.currentStyle,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Divider(height: 24),
                  Text('Example Path:', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Music / Artist / Album / 01 - Title.mp3',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Groq Clean Toggle
            SwitchListTile(
              title: const Text('Clean folder names with Groq'),
              subtitle: const Text('Remove garbage characters from resulting folder and file names.'),
              value: _cleanWithGroq,
              onChanged: (val) => setState(() => _cleanWithGroq = val),
              activeColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
            ),
            
            const SizedBox(height: 32),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onPreview();
                    },
                    icon: const Icon(Icons.preview),
                    label: const Text('Preview'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onApply();
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Apply'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
