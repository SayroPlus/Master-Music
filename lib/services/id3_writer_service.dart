import 'package:flutter/services.dart';

/// Writes audio metadata (ID3 tags) back to files via a native MethodChannel.
///
/// The native side (MainActivity.kt) uses the JAudioTagger library to write
/// ID3v2 tags for MP3 and equivalent tags for FLAC/OGG/M4A, then triggers
/// a MediaStore scan so the system media database picks up the changes.
///
/// Requirements:
///   • MANAGE_EXTERNAL_STORAGE permission (Android 11+)
///   • Standard WRITE_EXTERNAL_STORAGE for Android 10
class Id3WriterService {
  static const MethodChannel _channel =
      MethodChannel('music_organizer/id3_writer');

  /// Writes metadata fields to the audio file at [filePath].
  ///
  /// Returns `true` if the native side reports success, `false` otherwise.
  /// Any field that is `null` will be left unchanged in the file.
  Future<bool> writeMetadata({
    required String filePath,
    String? title,
    String? artist,
    String? album,
    String? genre,
    String? year,
    String? trackNumber,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'writeMetadata',
        {
          'filePath': filePath,
          'title': title,
          'artist': artist,
          'album': album,
          'genre': genre,
          'year': year,
          'trackNumber': trackNumber,
        },
      );
      return result ?? false;
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('ID3 write error: ${e.message}');
      return false;
    } on MissingPluginException {
      // Channel not registered on this platform.
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Writes metadata from a song map (as stored in backup snapshots).
  ///
  /// Convenience wrapper that extracts the relevant fields from a map keyed
  /// with the same column names used by [SongModel.toMap].
  Future<bool> writeMetadataFromMap(Map<String, dynamic> songMap) async {
    return writeMetadata(
      filePath: songMap['file_path'] as String,
      title: songMap['title'] as String?,
      artist: songMap['artist'] as String?,
      album: songMap['album'] as String?,
      genre: songMap['genre'] as String?,
      year: songMap['year'] as String?,
      trackNumber: songMap['track_number'] as String?,
    );
  }
}
