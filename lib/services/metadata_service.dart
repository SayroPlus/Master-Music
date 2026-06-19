import 'package:flutter/services.dart';

/// Service for reading audio file metadata via a native Android MethodChannel.
///
/// Uses Android's [MediaMetadataRetriever] under the hood to extract
/// title, artist, album, genre, year, trackNumber, duration, bitrate, etc.
/// Compatible with Android 10 (API 29) through Android 16 (API 36).
class MetadataService {
  static const MethodChannel _channel = MethodChannel('music_organizer/metadata');

  /// Reads metadata from a single audio file.
  ///
  /// Returns a map with keys: title, artist, album, genre, year, trackNumber,
  /// duration (ms), bitrate, sampleRate, mimeType, hasAlbumArt.
  /// Returns an empty map if reading fails.
  Future<Map<String, dynamic>> readMetadata(String filePath) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getAudioMetadata',
        {'filePath': filePath},
      );
      if (result == null) return {};
      return result.cast<String, dynamic>();
    } on PlatformException {
      return {};
    } catch (_) {
      return {};
    }
  }

  /// Reads metadata from multiple audio files in a single native call.
  ///
  /// Returns a list of maps matching the input files by index.
  Future<List<Map<String, dynamic>>> readMetadataBatch(
    List<String> filePaths,
  ) async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'getAudioMetadataBatch',
        {'filePaths': filePaths},
      );
      if (result == null) return [];
      return result
          .map((item) => (item as Map<dynamic, dynamic>).cast<String, dynamic>())
          .toList();
    } on PlatformException {
      return List.generate(filePaths.length, (_) => <String, dynamic>{});
    } catch (_) {
      return List.generate(filePaths.length, (_) => <String, dynamic>{});
    }
  }
}
