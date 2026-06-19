import 'dart:convert';

import 'package:dio/dio.dart';

import '../core/constants/app_strings.dart';
import '../core/exceptions/groq_exception.dart';
import '../models/song_model.dart';
import 'settings_service.dart';

/// Client for the Groq API (Llama 3.3 70B Versatile).
///
/// Provides AI-powered methods for:
/// - Extracting metadata from raw file names
/// - Generating filesystem-safe folder names
/// - Suggesting metadata corrections for existing songs
/// - Suggesting folder organization structures
///
/// Requires a Groq API key stored in SharedPreferences via [SettingsService].
class GroqService {
  late final Dio _dio;
  String? _apiKey;

  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';

  GroqService() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
      },
    ));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Configuration
  // ═══════════════════════════════════════════════════════════════════════════

  /// Returns `true` if a Groq API key is configured in SharedPreferences.
  Future<bool> isGroqConfigured() async {
    return await SettingsService.isGroqConfigured();
  }

  /// Loads the API key from SharedPreferences. Must be called before
  /// any API methods, or use [_ensureApiKey] which does this automatically.
  Future<void> _loadApiKey() async {
    _apiKey = await SettingsService.getGroqApiKey();
  }

  /// Ensures the API key is loaded and valid; throws if missing.
  Future<void> _ensureApiKey() async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      await _loadApiKey();
    }
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw const GroqNotConfiguredException();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Public API Methods
  // ═══════════════════════════════════════════════════════════════════════════

  /// Extracts metadata from a raw audio file name using AI.
  ///
  /// Returns a map with keys: `title`, `artist`, `album`, `year`.
  /// Returns `null` on failure (does not crash).
  Future<Map<String, String?>?> cleanFileName(String rawFileName) async {
    const systemPrompt =
        'You are a music metadata assistant. You extract metadata from file names.';

    final userPrompt = '''
You are a music metadata assistant. Given this raw audio file name, extract the most likely:
- Song title
- Artist name
- Album name (if detectable)
- Year (if detectable)

File name: $rawFileName

Return ONLY a JSON object with keys: title, artist, album, year. 
If a field cannot be determined, use null.
No explanation, no markdown, just the JSON.''';

    try {
      final response = await _sendChatRequest(
        systemPrompt: systemPrompt,
        userMessage: userPrompt,
        temperature: 0.1,
        maxTokens: 256,
      );

      if (response == null) return null;
      return _parseJsonResponse(response);
    } catch (e) {
      if (e is GroqNotConfiguredException) rethrow;
      return null;
    }
  }

  /// Generates a filesystem-safe folder name from an artist name.
  ///
  /// Returns the cleaned name, or [rawArtistName] unchanged on failure.
  Future<String> generateFolderName(String rawArtistName) async {
    const systemPrompt =
        'You are a file system assistant. You clean names for use as folder names.';

    final userPrompt = '''
Clean this artist name for use as a folder name on Android.
Remove special characters that are invalid in file paths.
Preserve the actual artist name, just make it filesystem-safe.
Artist: $rawArtistName
Return ONLY the cleaned folder name, nothing else.''';

    try {
      final response = await _sendChatRequest(
        systemPrompt: systemPrompt,
        userMessage: userPrompt,
        temperature: 0.0,
        maxTokens: 128,
      );

      if (response == null) return rawArtistName;
      return response.trim().replaceAll('"', '').replaceAll("'", '');
    } catch (e) {
      if (e is GroqNotConfiguredException) rethrow;
      return rawArtistName;
    }
  }

  /// Suggests corrected metadata for a song based on existing info + file name.
  ///
  /// Returns a map with keys: `title`, `artist`, `album`, `genre`, `year`.
  /// Returns `null` on failure (does not crash).
  Future<Map<String, String?>?> suggestMetadata(SongModel song) async {
    const systemPrompt =
        'You are a music expert. You suggest accurate metadata for audio files.';

    final userPrompt = '''
You are a music expert. Based on this information about an audio file, 
suggest the most accurate metadata:

File name: ${song.fileName}
Current title: ${song.title ?? 'unknown'}
Current artist: ${song.artist ?? 'unknown'}
Current album: ${song.album ?? 'unknown'}
Current genre: ${song.genre ?? 'unknown'}

Return ONLY a JSON object with keys: title, artist, album, genre, year.
Use null for fields you are not confident about.
No explanation, no markdown, just JSON.''';

    try {
      final response = await _sendChatRequest(
        systemPrompt: systemPrompt,
        userMessage: userPrompt,
        temperature: 0.2,
        maxTokens: 256,
      );

      if (response == null) return null;
      return _parseJsonResponse(response);
    } catch (e) {
      if (e is GroqNotConfiguredException) rethrow;
      return null;
    }
  }

  /// Asks the AI to suggest a folder structure for a list of songs.
  ///
  /// Returns the raw AI response string for further parsing, or `null`.
  Future<String?> suggestOrganization(
    List<Map<String, String>> songMetadata,
  ) async {
    const systemPrompt = '''
You are a music library organizer. Given a list of songs with their metadata,
suggest the best folder structure to organize them. Use the format:
Artist/Album/TrackNumber - Title.extension

Return a JSON array of objects with:
- "original_path": the current file path
- "suggested_path": the recommended new path
- "reason": brief explanation of the change
- "confidence": a number 0.0-1.0 indicating confidence''';

    final userMessage = jsonEncode(songMetadata);

    try {
      return await _sendChatRequest(
        systemPrompt: systemPrompt,
        userMessage: userMessage,
        temperature: 0.3,
        maxTokens: 4096,
      );
    } catch (e) {
      if (e is GroqNotConfiguredException) rethrow;
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Core API Communication
  // ═══════════════════════════════════════════════════════════════════════════

  /// Sends a chat completion request to the Groq API.
  ///
  /// Handles rate limiting by waiting 2 seconds and retrying once.
  /// Returns the content string from the first choice, or `null`.
  Future<String?> _sendChatRequest({
    required String systemPrompt,
    required String userMessage,
    double temperature = 0.3,
    int maxTokens = 2048,
  }) async {
    await _ensureApiKey();

    return await _sendWithRetry(
      systemPrompt: systemPrompt,
      userMessage: userMessage,
      temperature: temperature,
      maxTokens: maxTokens,
    );
  }

  /// Attempts the API call, retrying once on rate-limit (429).
  Future<String?> _sendWithRetry({
    required String systemPrompt,
    required String userMessage,
    required double temperature,
    required int maxTokens,
    bool isRetry = false,
  }) async {
    try {
      final response = await _dio.post(
        _baseUrl,
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
          },
        ),
        data: jsonEncode({
          'model': AppStrings.groqModel,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userMessage},
          ],
          'temperature': temperature,
          'max_tokens': maxTokens,
          'stream': false,
        }),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final choices = data['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          return choices[0]['message']['content'] as String?;
        }
      }

      return null;
    } on DioException catch (e) {
      // ── Rate limited (429) → retry once after 2 seconds ───────────
      if (!isRetry && e.response?.statusCode == 429) {
        await Future.delayed(const Duration(seconds: 2));
        return _sendWithRetry(
          systemPrompt: systemPrompt,
          userMessage: userMessage,
          temperature: temperature,
          maxTokens: maxTokens,
          isRetry: true,
        );
      }

      // ── Unauthorized (401) → bad API key ──────────────────────────
      if (e.response?.statusCode == 401) {
        throw const GroqNotConfiguredException(
          'Invalid Groq API key. Please check your key in Settings.',
        );
      }

      // ── Any other error → return null gracefully ──────────────────
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Response Parsing
  // ═══════════════════════════════════════════════════════════════════════════

  /// Parses a JSON response string from the AI into a Map.
  ///
  /// Handles common AI response quirks:
  /// - Strips markdown code fences (```json ... ```)
  /// - Trims whitespace
  Map<String, String?>? _parseJsonResponse(String raw) {
    try {
      var cleaned = raw.trim();

      // Strip markdown code fences if the AI wrapped the JSON
      if (cleaned.startsWith('```')) {
        cleaned = cleaned
            .replaceFirst(RegExp(r'^```\w*\n?'), '')
            .replaceFirst(RegExp(r'\n?```$'), '');
      }

      final decoded = jsonDecode(cleaned) as Map<String, dynamic>;

      // Convert all values to String? for consistency
      return decoded.map((key, value) {
        if (value == null) return MapEntry(key, null);
        return MapEntry(key, value.toString());
      });
    } catch (_) {
      return null;
    }
  }
}
