import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../models/song_model.dart';
import '../../providers/player_provider.dart';
import '../../widgets/album_art.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  Color _dominantColor = AppColors.primary;
  SongModel? _lastSong;
  
  bool _isDragging = false;
  double _dragValue = 0.0;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _updatePalette(SongModel song) async {
    if (song == _lastSong) return;
    _lastSong = song;

    if (song.coverArtPath == null && song.coverArtUrl == null) {
      if (mounted) setState(() => _dominantColor = AppColors.primary);
      return;
    }

    try {
      ImageProvider? imageProvider;
      if (song.coverArtPath != null) {
        imageProvider = FileImage(File(song.coverArtPath!));
      } else if (song.coverArtUrl != null) {
        imageProvider = NetworkImage(song.coverArtUrl!);
      }

      if (imageProvider != null) {
        final palette = await PaletteGenerator.fromImageProvider(imageProvider);
        if (mounted) {
          setState(() {
            _dominantColor = palette.dominantColor?.color ?? AppColors.primary;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _dominantColor = AppColors.primary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerProvider);
    final song = state.currentSong;

    if (song != null) {
      // Intentionally not awaiting so UI renders immediately
      _updatePalette(song);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.playerTitle),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: song == null
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.headphones_rounded, size: 64, color: AppColors.textHint),
                  SizedBox(height: 16),
                  Text(AppStrings.playerNoSong),
                ],
              ),
            )
          : Stack(
              children: [
                // Faded background glow
                Positioned.fill(
                  child: AnimatedContainer(
                    duration: const Duration(seconds: 1),
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          _dominantColor.withAlpha(90),
                          AppColors.background,
                        ],
                        center: const Alignment(0, -0.2),
                        radius: 1.2,
                        stops: const [0.0, 1.0],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      const Spacer(),
                      
                      // Album Art with Glow
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 48),
                        child: AnimatedContainer(
                          duration: const Duration(seconds: 1),
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: _dominantColor.withAlpha(120),
                                blurRadius: 40,
                                spreadRadius: -10,
                                offset: const Offset(0, 20),
                              ),
                            ],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Hero(
                              tag: 'album_art_${song.filePath}',
                              child: AlbumArt(
                                localPath: song.coverArtPath,
                                imageUrl: song.coverArtUrl,
                                size: 280,
                                borderRadius: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Song Info
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          children: [
                            Text(
                              song.displayTitle,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              song.displayArtist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                            if (song.album != null && song.album!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                song.album!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.white54,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ]
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Progress Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 4,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                activeTrackColor: _dominantColor,
                                inactiveTrackColor: Colors.white24,
                                thumbColor: Colors.white,
                                overlayColor: _dominantColor.withAlpha(32),
                              ),
                              child: Slider(
                                value: _isDragging ? _dragValue : state.progress.clamp(0.0, 1.0),
                                onChangeStart: (val) {
                                  setState(() {
                                    _isDragging = true;
                                    _dragValue = val;
                                  });
                                },
                                onChanged: (value) {
                                  setState(() => _dragValue = value);
                                },
                                onChangeEnd: (value) {
                                  final position = Duration(
                                    milliseconds: (value * state.duration.inMilliseconds).round(),
                                  );
                                  ref.read(playerProvider.notifier).seek(position);
                                  setState(() => _isDragging = false);
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(_isDragging 
                                      ? Duration(milliseconds: (_dragValue * state.duration.inMilliseconds).round())
                                      : state.position),
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                  Text(
                                    _formatDuration(state.duration),
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.shuffle_rounded,
                              color: state.isShuffled ? _dominantColor : Colors.white54,
                            ),
                            onPressed: () => ref.read(playerProvider.notifier).toggleShuffle(),
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: const Icon(Icons.skip_previous_rounded, size: 40, color: Colors.white),
                            onPressed: () => ref.read(playerProvider.notifier).previous(),
                          ),
                          const SizedBox(width: 24),
                          GestureDetector(
                            onTap: () => ref.read(playerProvider.notifier).togglePlayPause(),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: _dominantColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _dominantColor.withAlpha(100),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: state.isBuffering
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : Icon(
                                      state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                      size: 40,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          IconButton(
                            icon: const Icon(Icons.skip_next_rounded, size: 40, color: Colors.white),
                            onPressed: () => ref.read(playerProvider.notifier).next(),
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: Icon(
                              _repeatIcon(state.repeatMode),
                              color: state.repeatMode != AudioRepeatMode.off ? _dominantColor : Colors.white54,
                            ),
                            onPressed: () => ref.read(playerProvider.notifier).cycleRepeatMode(),
                          ),
                        ],
                      ),
                      
                      const Spacer(),
                      
                      // Up Next Queue
                      if (state.queue.length > 1) 
                        _buildUpNextQueue(state),
                        
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
  
  Widget _buildUpNextQueue(PlayerState state) {
    // Collect next 3 items
    final upcomingList = <SongModel>[];
    for (var i = 1; i <= 3; i++) {
      final index = state.currentIndex + i;
      if (index < state.queue.length) {
        upcomingList.add(state.queue[index]);
      } else if (state.repeatMode == AudioRepeatMode.all && state.queue.isNotEmpty) {
        // Wrap around
        upcomingList.add(state.queue[index % state.queue.length]);
      }
    }
    
    if (upcomingList.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      height: 130, // Fixed height for visual consistency
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Up Next',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: upcomingList.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final s = upcomingList[index];
                return Row(
                  children: [
                    AlbumArt(
                      localPath: s.coverArtPath,
                      imageUrl: s.coverArtUrl,
                      size: 32,
                      borderRadius: 4,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            s.displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          Text(
                            s.displayArtist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  IconData _repeatIcon(AudioRepeatMode mode) {
    switch (mode) {
      case AudioRepeatMode.one: return Icons.repeat_one_rounded;
      case AudioRepeatMode.all: return Icons.repeat_rounded;
      case AudioRepeatMode.off: return Icons.repeat_rounded;
    }
  }
}
