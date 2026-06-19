import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song_model.dart';
import 'dart:async';

/// Global reference to the Audio Handler (null if init failed).
AudioHandler? audioHandler;

Future<void> initAudioService() async {
  audioHandler = await AudioService.init(
    builder: () => AppAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.music_organizer.channel.audio',
      androidNotificationChannelName: 'Music Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidShowNotificationBadge: true,
    ),
  );
}

class AppAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  late ConcatenatingAudioSource _playlist;
  
  // Keep original song models mapping
  List<SongModel> _rawQueue = [];

  AppAudioHandler() {
    _playlist = ConcatenatingAudioSource(children: []);
    _initStreams();
  }

  void _initStreams() {
    // Broadcast playback state changes
    _player.playbackEventStream.listen((event) {
      _broadcastState(event);
    });

    // Broadcast current media item when track changes
    _player.currentIndexStream.listen((index) {
      if (index != null && queue.value.isNotEmpty && index < queue.value.length) {
        mediaItem.add(queue.value[index]);
      }
    });
  }

  void _broadcastState(PlaybackEvent event) {
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    ));
  }

  // --- External Control APIs ---

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode == AudioServiceShuffleMode.all;
    if (enabled) {
      await _player.shuffle();
    }
    await _player.setShuffleModeEnabled(enabled);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    final bm = const {
      AudioServiceRepeatMode.none: LoopMode.off,
      AudioServiceRepeatMode.one: LoopMode.one,
      AudioServiceRepeatMode.all: LoopMode.all,
      AudioServiceRepeatMode.group: LoopMode.all,
    }[repeatMode]!;
    await _player.setLoopMode(bm);
  }

  // Map songs into just_audio sources and audio_service items
  Future<void> loadQueue(List<SongModel> songs, {int initialIndex = 0}) async {
    _rawQueue = songs;
    
    final mediaItems = songs.map((s) => _mapToMediaItem(s)).toList();
    
    final audioSources = songs.map((s) => AudioSource.uri(
      Uri.file(s.filePath),
      tag: _mapToMediaItem(s), // Attaching MediaItem to tag
    )).toList();

    _playlist = ConcatenatingAudioSource(children: audioSources);
    
    // Update audio_service queue
    queue.add(mediaItems);
    
    // Set just_audio playlist
    await _player.setAudioSource(
      _playlist,
      initialIndex: initialIndex,
      initialPosition: Duration.zero,
    );
  }
  
  // Custom API to load and play directly
  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == 'shuffle') {
      final isShuffled = _player.shuffleModeEnabled;
      await setShuffleMode(isShuffled ? AudioServiceShuffleMode.none : AudioServiceShuffleMode.all);
    }
  }
  
  List<SongModel> get currentRawQueue => _rawQueue;
  AudioPlayer get internalPlayer => _player;

  MediaItem _mapToMediaItem(SongModel song) {
    return MediaItem(
      id: song.filePath, // Use file path as unique identifier
      album: song.album ?? 'Unknown Album',
      title: song.title ?? song.fileName,
      artist: song.artist ?? 'Unknown Artist',
      duration: song.duration != null ? Duration(milliseconds: song.duration!) : null,
      artUri: song.coverArtPath != null 
          ? Uri.file(song.coverArtPath!) 
          : (song.coverArtUrl != null ? Uri.parse(song.coverArtUrl!) : null),
    );
  }
}
