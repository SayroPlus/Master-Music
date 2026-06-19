import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../models/song_model.dart';

/// Client for the MusicBrainz Web API and Cover Art Archive.
///
/// Handles song metadata lookup by title/artist search, file-name parsing,
/// cover art downloading with local caching, and confidence scoring.
///
/// Rate limit: MusicBrainz enforces 1 req/sec for unauthenticated clients.
/// We add a 1 100 ms delay between consecutive calls to stay compliant.
///
/// See: https://musicbrainz.org/doc/MusicBrainz_API
class MusicBrainzService {
  // ── Configuration ──────────────────────────────────────────────────────────
  static const String _baseUrl = 'https://musicbrainz.org/ws/2';
  static const String _userAgent =
      'MusicOrganizerApp/1.0 (orana4303@gmail.com)';
  static const Duration _rateLimitDelay = Duration(milliseconds: 1100);

  /// Tracks the last request timestamp so we can honour the rate limit.
  DateTime? _lastRequestTime;

  // ── Rate-limit helper ──────────────────────────────────────────────────────

  /// Ensures at least [_rateLimitDelay] has passed since the previous request.
  Future<void> _enforceRateLimit() async {
    if (_lastRequestTime != null) {
      final elapsed = DateTime.now().difference(_lastRequestTime!);
      if (elapsed < _rateLimitDelay) {
        await Future.delayed(_rateLimitDelay - elapsed);
      }
    }
    _lastRequestTime = DateTime.now();
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Searches MusicBrainz for a recording matching [title] and [artist].
  ///
  /// Returns a normalised result map with keys:
  /// `title`, `artist`, `album`, `year`, `genre`, `mbid`
  /// or `null` if nothing useful was found.
  Future<Map<String, dynamic>?> searchByTitleArtist(
    String title,
    String artist,
  ) async {
    if (title.trim().isEmpty) return null;

    await _enforceRateLimit();

    // Build the Lucene query – encode individual terms.
    final encodedTitle = Uri.encodeComponent(title.trim());
    final encodedArtist = Uri.encodeComponent(artist.trim());

    String query = 'recording:$encodedTitle';
    if (artist.trim().isNotEmpty) {
      query += '+AND+artist:$encodedArtist';
    }

    final uri = Uri.parse(
      '$_baseUrl/recording?query=$query&fmt=json&limit=5',
    );

    try {
      final response = await http.get(uri, headers: {
        'User-Agent': _userAgent,
        'Accept': 'application/json',
      });

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final recordings = data['recordings'] as List<dynamic>? ?? [];
      if (recordings.isEmpty) return null;

      // Pick the first (best) match and normalise the result.
      return _parseRecording(recordings.first as Map<String, dynamic>);
    } catch (e) {
      // Network / parse errors → treat as "no match".
      return null;
    }
  }

  /// Attempts to identify a song from its cleaned file name.
  ///
  /// Common naming patterns handled:
  ///   "Artist - Title"
  ///   "01 - Title"        → numbers-only prefix stripped
  ///   "Title (feat. X)"   → parenthetical text stripped
  ///   "Title"             → used as-is with empty artist
  Future<Map<String, dynamic>?> searchByFileName(
    String cleanedFileName,
  ) async {
    if (cleanedFileName.trim().isEmpty) return null;

    // Remove file extension if still present.
    String name = p.basenameWithoutExtension(cleanedFileName);

    // Strip leading track numbers  ("01 - ", "01. ", "1 ")
    name = name.replaceFirst(RegExp(r'^\d{1,3}[\s.\-_]+'), '');

    // Strip trailing parenthetical info  "(Official Audio)", "(feat. X)"
    name = name.replaceAll(RegExp(r'\s*\(.*?\)\s*'), ' ');
    // Strip square-bracket info  "[Official Video]"
    name = name.replaceAll(RegExp(r'\s*\[.*?\]\s*'), ' ');

    String parsedTitle;
    String parsedArtist;

    // Try "Artist - Title" split (most common convention).
    if (name.contains(' - ')) {
      final parts = name.split(' - ');
      parsedArtist = parts.first.trim();
      parsedTitle = parts.sublist(1).join(' - ').trim();

      // If the "artist" part is purely numeric (leftover track number after
      // the initial strip), swap to title-only.
      if (RegExp(r'^\d+$').hasMatch(parsedArtist)) {
        parsedTitle = '$parsedArtist $parsedTitle'.trim();
        parsedArtist = '';
      }
    } else {
      parsedTitle = name.trim();
      parsedArtist = '';
    }

    return searchByTitleArtist(parsedTitle, parsedArtist);
  }

  /// Downloads the 250 px front cover art for a MusicBrainz release.
  ///
  /// The image is saved to the app's cache directory and the **local file
  /// path** is returned. Returns `null` if no cover art is available.
  Future<String?> getCoverArt(String mbid) async {
    if (mbid.trim().isEmpty) return null;

    final uri = Uri.parse(
      'https://coverartarchive.org/release/$mbid/front-250',
    );

    try {
      // Cover Art Archive redirects (307) to the actual image CDN.
      // Using a non-redirect-following client first to check availability,
      // then downloading the bytes.
      final client = http.Client();
      try {
        final request = http.Request('GET', uri)
          ..followRedirects = true
          ..maxRedirects = 5;

        final streamedResponse = await client.send(request);

        if (streamedResponse.statusCode == 200) {
          final bytes = await streamedResponse.stream.toBytes();

          // Save to cache directory.
          final cacheDir = await getTemporaryDirectory();
          final coverDir = Directory(p.join(cacheDir.path, 'cover_art'));
          if (!await coverDir.exists()) {
            await coverDir.create(recursive: true);
          }

          final filePath = p.join(coverDir.path, '$mbid.jpg');
          final file = File(filePath);
          await file.writeAsBytes(bytes);

          return filePath;
        }
      } finally {
        client.close();
      }
    } catch (_) {
      // Network / IO error → no cover art.
    }

    return null;
  }

  /// Calculates a 0.0 – 1.0 confidence score by comparing the API result
  /// against the song's existing metadata.
  ///
  /// Scoring breakdown (each field has equal weight):
  ///   • title  match → 0.30
  ///   • artist match → 0.30
  ///   • album  match → 0.20
  ///   • year   match → 0.20
  double getConfidenceScore(Map<String, dynamic> apiResult, SongModel song) {
    double score = 0.0;

    if (_fuzzyMatch(apiResult['title'] as String?, song.title)) {
      score += 0.30;
    }
    if (_fuzzyMatch(apiResult['artist'] as String?, song.artist)) {
      score += 0.30;
    }
    if (_fuzzyMatch(apiResult['album'] as String?, song.album)) {
      score += 0.20;
    }
    if (apiResult['year'] != null &&
        song.year != null &&
        apiResult['year'].toString() == song.year) {
      score += 0.20;
    }

    // If the song had no metadata at all, but we still got a result the user
    // can review, give a baseline so it doesn't read as "zero confidence".
    if (song.title == null &&
        song.artist == null &&
        apiResult['title'] != null) {
      score = score.clamp(0.4, 1.0);
    }

    return double.parse(score.toStringAsFixed(2));
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Normalises a MusicBrainz recording JSON object into a flat map.
  Map<String, dynamic> _parseRecording(Map<String, dynamic> recording) {
    // Title
    final title = recording['title'] as String?;

    // Artist — first artist-credit entry.
    String? artist;
    final artistCredits =
        recording['artist-credit'] as List<dynamic>? ?? [];
    if (artistCredits.isNotEmpty) {
      final firstCredit = artistCredits.first as Map<String, dynamic>;
      artist = firstCredit['name'] as String? ??
          (firstCredit['artist'] as Map<String, dynamic>?)?['name'] as String?;
    }

    // Album & year — first release entry.
    String? album;
    String? year;
    String? releaseMbid;
    final releases = recording['releases'] as List<dynamic>? ?? [];
    if (releases.isNotEmpty) {
      final firstRelease = releases.first as Map<String, dynamic>;
      album = firstRelease['title'] as String?;
      releaseMbid = firstRelease['id'] as String?;
      final date = firstRelease['date'] as String?;
      if (date != null && date.length >= 4) {
        year = date.substring(0, 4);
      }
    }

    // Genre — via tag list (most common path in MusicBrainz search results).
    String? genre;
    final tags = recording['tags'] as List<dynamic>? ?? [];
    if (tags.isNotEmpty) {
      // Pick the tag with the highest count.
      tags.sort((a, b) =>
          ((b as Map)['count'] as int? ?? 0)
              .compareTo((a as Map)['count'] as int? ?? 0));
      genre = (tags.first as Map<String, dynamic>)['name'] as String?;
    }

    // MusicBrainz recording ID.
    final mbid = recording['id'] as String?;

    return {
      'title': title,
      'artist': artist,
      'album': album,
      'year': year,
      'genre': genre,
      'mbid': mbid,
      'releaseMbid': releaseMbid,
    };
  }

  /// Case-insensitive containment check — handles `null`s gracefully.
  bool _fuzzyMatch(String? a, String? b) {
    if (a == null || b == null) return false;
    final la = a.toLowerCase().trim();
    final lb = b.toLowerCase().trim();
    if (la.isEmpty || lb.isEmpty) return false;
    return la.contains(lb) || lb.contains(la);
  }
}
