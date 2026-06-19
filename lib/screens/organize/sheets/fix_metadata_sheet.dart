import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';

class FixMetadataSheet extends ConsumerStatefulWidget {
  final int missingMetadataCount;
  final VoidCallback onStart;

  const FixMetadataSheet({
    super.key,
    required this.missingMetadataCount,
    required this.onStart,
  });

  @override
  ConsumerState<FixMetadataSheet> createState() => _FixMetadataSheetState();
}

class _FixMetadataSheetState extends ConsumerState<FixMetadataSheet> {
  bool _useAcoustid = true;
  bool _useGroq = false;

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
                const Icon(Icons.auto_fix_high, color: AppColors.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Fix All Metadata',
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
              'This will process ${widget.missingMetadataCount} songs missing artist or album info.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            
            // AcoustID Toggle
            SwitchListTile(
              title: const Text('Use AcoustID fingerprinting'),
              subtitle: const Text('Slower, but identifies songs with completely missing tags.'),
              value: _useAcoustid,
              onChanged: (val) => setState(() => _useAcoustid = val),
              activeColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
            ),
            
            // Groq Toggle
            SwitchListTile(
              title: const Text('Use Groq AI processing'),
              subtitle: const Text('Uses AI to parse garbage filenames. Requires API key.'),
              value: _useGroq,
              onChanged: (val) => setState(() => _useGroq = val),
              activeColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
            ),
            
            const SizedBox(height: 8),
            
            // Backup Checkbox (Disabled / Checked by default)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_box, color: AppColors.accent),
              title: const Text('Create backup before fixing'),
              subtitle: const Text('Recommended. Allows undoing all changes.', style: TextStyle(fontSize: 12)),
              enabled: false,
            ),
            
            const SizedBox(height: 32),
            
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context); // Close sheet
                widget.onStart(); // Trigger action
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start Processing'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
