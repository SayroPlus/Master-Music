import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song_model.dart';
import '../services/audio_handler.dart';

/// Playback repeat mode mirroring native LoopMode.
enum AudioRepeatMode { off, one, all }

class PlayerState {
  final SongModel? currentSong;
  final List<SongModel> queue;
  final int currentIndex;
  final bool isPlaying;
  final bool isBuffering;
  final Duration position;
  final Duration duration;
  final double volume;
  final bool isShuffled;
  final AudioRepeatMode repeatMode;

  const PlayerState({
    this.currentSong,
    this.queue = const [],
    this.currentIndex = 0,
    this.isPlaying = false,
    this.isBuffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 1.0,
    this.isShuffled = false,
    this.repeatMode = AudioRepeatMode.off,
  });

  double get progress {
    if (duration.inMilliseconds == 0) return 0.0;
    return position.inMilliseconds / duration.inMilliseconds;
  }

  PlayerState copyWith({
    SongModel? currentSong,
    List<SongModel>? queue,
    int? currentIndex,
    bool? isPlaying,
    bool? isBuffering,
    Duration? position,
    Duration? duration,
    double? volume,
    bool? isShuffled,
    AudioRepeatMode? repeatMode,
  }) {
    return PlayerState(
      currentSong: currentSong ?? this.currentSong,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      isShuffled: isShuffled ?? this.isShuffled,
      repeatMode: repeatMode ?? this.repeatMode,
    );
  }
}

class PlayerNotifier extends StateNotifier<PlayerState> {
  final AppAudioHandler? _handler;
  
  StreamSubscription? _playbackStateSub;
  StreamSubscription? _mediaItemSub;
  StreamSubscription? _positionSub;

  PlayerNotifier(AppAudioHandler handler) : _handler = handler, super(const PlayerState()) {
    _initListeners();
  }

  PlayerNotifier._disabled() : _handler = null, super(const PlayerState());

  void _initListeners() {
    final h = _handler;
    if (h == null) return;

    _playbackStateSub = h.playbackState.listen((ps) {
      final isPlaying = ps.playing;
      final isBuffering = ps.processingState == AudioProcessingState.loading || 
                          ps.processingState == AudioProcessingState.buffering;
      
      state = state.copyWith(
        isPlaying: isPlaying,
        isBuffering: isBuffering,
      );
    });

    _mediaItemSub = h.mediaItem.listen((item) {
      if (item == null) return;
      
      final queueIndex = h.internalPlayer.currentIndex ?? 0;
      final queue = h.currentRawQueue;
      
      if (queueIndex < queue.length) {
        state = state.copyWith(
          currentSong: queue[queueIndex],
          currentIndex: queueIndex,
          queue: queue,
          duration: item.duration ?? Duration.zero,
        );
      }
    });

    _positionSub = AudioService.position.listen((pos) {
      state = state.copyWith(position: pos);
    });
    
    // Also listen to shuffle mode from the internal player to keep state synced
    h.internalPlayer.shuffleModeEnabledStream.listen((enabled) {
      state = state.copyWith(isShuffled: enabled);
    });
  }

  /// Loads a song and optional queue for playback.
  Future<void> playSong(SongModel song, {List<SongModel>? queue, int index = 0}) async {
    final h = _handler;
    if (h == null) return;
    final activeQueue = queue ?? [song];
    await h.loadQueue(activeQueue, initialIndex: index);
    await h.play();
  }

  Future<void> togglePlayPause() async {
    final h = _handler;
    if (h == null) return;
    if (state.isPlaying) {
      await h.pause();
    } else {
      await h.play();
    }
  }

  Future<void> seek(Duration position) async {
    await _handler?.seek(position);
  }

  Future<void> next() async {
    await _handler?.skipToNext();
  }

  Future<void> previous() async {
    await _handler?.skipToPrevious();
  }

  Future<void> toggleShuffle() async {
    await _handler?.customAction('shuffle');
  }

  Future<void> cycleRepeatMode() async {
    final h = _handler;
    if (h == null) return;
    final next = AudioRepeatMode.values[(state.repeatMode.index + 1) % AudioRepeatMode.values.length];
    state = state.copyWith(repeatMode: next);
    
    final mode = const {
      AudioRepeatMode.off: AudioServiceRepeatMode.none,
      AudioRepeatMode.one: AudioServiceRepeatMode.one,
      AudioRepeatMode.all: AudioServiceRepeatMode.all,
    }[next]!;
    
    await h.setRepeatMode(mode);
  }

  Future<void> stop() async {
    await _handler?.stop();
    state = const PlayerState();
  }
  
  @override
  void dispose() {
    _playbackStateSub?.cancel();
    _mediaItemSub?.cancel();
    _positionSub?.cancel();
    super.dispose();
  }
}

final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  final handler = audioHandler;
  if (handler == null || handler is! AppAudioHandler) {
    // Audio service failed to init — return a no-op notifier
    return _NoOpPlayerNotifier();
  }
  return PlayerNotifier(handler);
});

/// A no-op player notifier used when audio service is unavailable.
class _NoOpPlayerNotifier extends PlayerNotifier {
  _NoOpPlayerNotifier() : super._disabled();

  @override
  Future<void> playSong(SongModel song, {List<SongModel>? queue, int index = 0}) async {}
  @override
  Future<void> togglePlayPause() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> next() async {}
  @override
  Future<void> previous() async {}
  @override
  Future<void> toggleShuffle() async {}
  @override
  Future<void> cycleRepeatMode() async {}
  @override
  Future<void> stop() async {}
}
