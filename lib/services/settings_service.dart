import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing app-level settings persisted in SharedPreferences.
class SettingsService {
  static const String _groqApiKeyKey = 'groq_api_key';
  static const String _acoustIdApiKeyKey = 'acoustid_api_key';

  // ═══════════════════════════════════════════════════════════════════════════
  // Groq API Key
  // ═══════════════════════════════════════════════════════════════════════════

  /// Saves the Groq API key to SharedPreferences.
  static Future<void> saveGroqApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_groqApiKeyKey, apiKey.trim());
  }

  /// Retrieves the Groq API key from SharedPreferences.
  ///
  /// Returns `null` if no key has been saved.
  static Future<String?> getGroqApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_groqApiKeyKey);
    if (key == null || key.trim().isEmpty) return null;
    return key;
  }

  /// Returns `true` if a Groq API key is configured.
  static Future<bool> isGroqConfigured() async {
    final key = await getGroqApiKey();
    return key != null;
  }

  /// Removes the saved Groq API key.
  static Future<void> clearGroqApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_groqApiKeyKey);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AcoustID API Key
  // ═══════════════════════════════════════════════════════════════════════════

  /// Saves the AcoustID API key to SharedPreferences.
  static Future<void> saveAcoustIdApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_acoustIdApiKeyKey, apiKey.trim());
  }

  /// Retrieves the AcoustID API key from SharedPreferences.
  static Future<String?> getAcoustIdApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_acoustIdApiKeyKey);
    if (key == null || key.trim().isEmpty) return null;
    return key;
  }

  /// Returns `true` if an AcoustID API key is configured.
  static Future<bool> isAcoustIdConfigured() async {
    final key = await getAcoustIdApiKey();
    return key != null;
  }

  static Future<void> clearAcoustIdApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_acoustIdApiKeyKey);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Organization Settings
  // ═══════════════════════════════════════════════════════════════════════════

  static const String _folderStructureStyleKey = 'folder_structure_style';
  static const String _fileRenameFormatKey = 'file_rename_format';
  static const String _useGroqFolderNamesKey = 'use_groq_folder_names';

  static Future<void> saveFolderStructureStyle(String style) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_folderStructureStyleKey, style);
  }

  static Future<String> getFolderStructureStyle() async {
    final prefs = await SharedPreferences.getInstance();
    // Default to 'Artist/Album' based on prompt implicature
    return prefs.getString(_folderStructureStyleKey) ?? 'Artist/Album';
  }

  static Future<void> saveFileRenameFormat(String format) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fileRenameFormatKey, format);
  }

  static Future<String> getFileRenameFormat() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_fileRenameFormatKey) ?? 'Artist - Title.mp3';
  }

  static Future<void> saveUseGroqFolderNames(bool useGroq) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useGroqFolderNamesKey, useGroq);
  }

  static Future<bool> getUseGroqFolderNames() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_useGroqFolderNamesKey) ?? false;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Reset
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> clearAllSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
