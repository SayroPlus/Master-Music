import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/player_provider.dart';
import '../../widgets/album_art.dart';

class MiniPlayer extends ConsumerWidget {
  final VoidCallback onTap;
  
  const MiniPlayer({super.key, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerProvider);
    final song = state.currentSong;

    // We animate the appearance of the mini player based on whether a song is loaded
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: song == null ? 0 : 64,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        border: const Border(
          top: BorderSide(color: Colors.white10),
        ),
      ),
      child: song == null
          ? const SizedBox.shrink()
          : GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Playback progress strip at the top
                  LinearProgressIndicator(
                    value: state.progress.clamp(0.0, 1.0),
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    minHeight: 2,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          AlbumArt(
                            localPath: song.coverArtPath,
                            imageUrl: song.coverArtUrl,
                            size: 40,
                            borderRadius: 6,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  song.displayTitle,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  song.displayArtist,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              ref.read(playerProvider.notifier).togglePlayPause();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
                            onPressed: () {
                              ref.read(playerProvider.notifier).next();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
