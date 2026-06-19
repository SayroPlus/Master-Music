import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Client for the AcoustID audio-fingerprint lookup service.
///
/// Two-step flow:
///   1. [generateFingerprint] — uses a platform MethodChannel to invoke the
///      Chromaprint / fpcalc binary on the native side and returns the
///      fingerprint string + audio duration.
///   2. [lookupFingerprint] — sends the fingerprint to the AcoustID API and
///      returns the best-matching recording metadata.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// HOW TO BUNDLE fpcalc FOR ANDROID (ARM64):
///
///   1. Download the pre-built Chromaprint binary for Android ARM64 from:
///      https://github.com/nicfit/chromaprint/releases
///      (or cross-compile from source: https://acoustid.org/chromaprint)
///
///   2. Place the `fpcalc` binary at:
///      android/app/src/main/jniLibs/arm64-v8a/libfpcalc.so
///      Note the `lib` prefix and `.so` suffix — Android's asset bundler
///      requires this naming convention for native libs.
///
///   3. In `MainActivity.kt`, resolve the binary path at runtime:
///        val fpcalcPath = applicationInfo.nativeLibraryDir + "/libfpcalc.so"
///
///   4. Execute via `ProcessBuilder` (see the MethodChannel handler in
///      `MainActivity.kt` for the `generateFingerprint` method).
///
///   5. Parse the stdout: fpcalc outputs lines like
///        DURATION=213
///        FINGERPRINT=AQAAE0k...
///      Split on '=' and return both values to Dart.
/// ─────────────────────────────────────────────────────────────────────────────
class AcoustIdService {
  // ── Configuration ──────────────────────────────────────────────────────────
  static const String _baseUrl = 'https://api.acoustid.org/v2';
  static const MethodChannel _channel =
      MethodChannel('music_organizer/acoustid');

  /// Preference key where the user stores their AcoustID API key.
  static const String _apiKeyPrefKey = 'acoustid_api_key';

  /// Minimum score threshold — results below this are discarded.
  static const double _minScoreThreshold = 0.6;

  /// Cached API key (loaded once from SharedPreferences).
  String? _apiKey;

  // ── API key management ─────────────────────────────────────────────────────

  /// Sets / updates the API key and persists it to SharedPreferences.
  Future<void> setApiKey(String key) async {
    _apiKey = key;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyPrefKey, key);
  }

  /// Loads the stored API key from SharedPreferences.
  /// Returns `true` if a key was found.
  Future<bool> loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString(_apiKeyPrefKey);
    return _apiKey != null && _apiKey!.isNotEmpty;
  }

  /// Whether an API key is currently available.
  bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;

  // ── Fingerprint generation (native) ────────────────────────────────────────

  /// Generates a Chromaprint audio fingerprint for the file at [filePath].
  ///
  /// Returns a map with keys `fingerprint` (String) and `duration` (int,
  /// seconds), or `null` if fingerprinting fails (e.g., missing fpcalc).
  ///
  /// This invokes the native Android side via MethodChannel. The Kotlin
  /// handler must call fpcalc and return the parsed result.
  Future<Map<String, dynamic>?> generateFingerprint(String filePath) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'generateFingerprint',
        {'filePath': filePath},
      );

      if (result == null) return null;

      final fingerprint = result['fingerprint'] as String?;
      final duration = result['duration'] as int?;

      if (fingerprint == null || duration == null) return null;

      return {
        'fingerprint': fingerprint,
        'duration': duration,
      };
    } on PlatformException catch (e) {
      // fpcalc not bundled or execution failed.
      // ignore: avoid_print
      print('AcoustID fingerprint error: ${e.message}');
      return null;
    } on MissingPluginException {
      // MethodChannel not registered on this platform.
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Fingerprint lookup (API) ───────────────────────────────────────────────

  /// Looks up a previously generated [fingerprint] + [duration] against the
  /// AcoustID database.
  ///
  /// Returns a normalised map with keys:
  ///   `title`, `artist`, `album`, `mbid`, `score`
  /// or `null` if no sufficiently confident match was found.
  Future<Map<String, dynamic>?> lookupFingerprint(
    String fingerprint,
    int duration,
  ) async {
    // Ensure we have an API key.
    if (!hasApiKey) {
      final loaded = await loadApiKey();
      if (!loaded) {
        throw Exception(
          'AcoustID API key not set. '
          'Register at https://acoustid.org and paste your key in Settings.',
        );
      }
    }

    final uri = Uri.parse('$_baseUrl/lookup');

    try {
      final response = await http.post(uri, body: {
        'client': _apiKey!,
        'fingerprint': fingerprint,
        'duration': duration.toString(),
        'meta': 'recordings+releases+releasegroups',
      });

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // Check top-level status.
      if (data['status'] != 'ok') return null;

      final results = data['results'] as List<dynamic>? ?? [];
      if (results.isEmpty) return null;

      // Iterate results sorted by score descending and return the first one
      // that exceeds our confidence threshold AND contains recording data.
      for (final result in results) {
        final resultMap = result as Map<String, dynamic>;
        final score = (resultMap['score'] as num?)?.toDouble() ?? 0.0;

        if (score < _minScoreThreshold) continue;

        final recordings =
            resultMap['recordings'] as List<dynamic>? ?? [];
        if (recordings.isEmpty) continue;

        // Use the first recording entry.
        final recording = recordings.first as Map<String, dynamic>;

        final title = recording['title'] as String?;

        // Artist
        String? artist;
        final artists = recording['artists'] as List<dynamic>? ?? [];
        if (artists.isNotEmpty) {
          artist =
              (artists.first as Map<String, dynamic>)['name'] as String?;
        }

        // Album & MBID from releasegroups.
        String? album;
        String? releaseMbid;
        final releaseGroups =
            recording['releasegroups'] as List<dynamic>? ?? [];
        if (releaseGroups.isNotEmpty) {
          final rg = releaseGroups.first as Map<String, dynamic>;
          album = rg['title'] as String?;

          // Try to extract a release MBID for cover art lookup.
          final releases = rg['releases'] as List<dynamic>? ?? [];
          if (releases.isNotEmpty) {
            releaseMbid =
                (releases.first as Map<String, dynamic>)['id'] as String?;
          }
        }

        // MusicBrainz recording ID
        final mbid = recording['id'] as String?;

        return {
          'title': title,
          'artist': artist,
          'album': album,
          'mbid': mbid,
          'releaseMbid': releaseMbid,
          'score': score,
        };
      }
    } catch (e) {
      // Network / parse errors.
      // ignore: avoid_print
      print('AcoustID lookup error: $e');
    }

    return null;
  }
}
