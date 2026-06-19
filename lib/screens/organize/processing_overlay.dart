import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/organizer_provider.dart';

class ProcessingOverlay extends ConsumerWidget {
  final VoidCallback onCancel;

  const ProcessingOverlay({
    super.key,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(organizerProvider);
    final theme = Theme.of(context);

    // Using PopScope to prevent accidental dismissal during batch operation.
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black87,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated Icon / Loader
                const CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 4,
                ),
                const SizedBox(height: 32),
                
                // Progress Bar
                LinearProgressIndicator(
                  value: state.progress,
                  backgroundColor: Colors.white24,
                  color: AppColors.primary,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 16),
                
                // Overall Progress text
                Text(
                  '${(state.progress * 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Processing ${state.progressLabel}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Current Song Details
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Currently processing:',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        state.currentSongName.isEmpty ? 'Preparing...' : state.currentSongName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Live Counters
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildCounter('Fixed', state.processedCount - state.errors.length, Colors.green),
                    _buildCounter('Failed', state.errors.length, AppColors.error),
                  ],
                ),
                
                const SizedBox(height: 48),
                
                // Cancel Button
                OutlinedButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.stop),
                  label: const Text('Cancel Operation'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCounter(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70),
        ),
      ],
    );
  }
}
