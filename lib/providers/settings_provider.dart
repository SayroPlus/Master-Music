import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/settings_service.dart';

class SettingsState {
  final String? acoustIdApiKey;
  final String? groqApiKey;
  final String folderStructureStyle;
  final String fileRenameFormat;
  final bool useGroqFolderNames;

  const SettingsState({
    this.acoustIdApiKey,
    this.groqApiKey,
    this.folderStructureStyle = 'Artist/Album',
    this.fileRenameFormat = 'Artist - Title.mp3',
    this.useGroqFolderNames = false,
  });

  SettingsState copyWith({
    String? acoustIdApiKey,
    bool clearAcoustId = false,
    String? groqApiKey,
    bool clearGroq = false,
    String? folderStructureStyle,
    String? fileRenameFormat,
    bool? useGroqFolderNames,
  }) {
    return SettingsState(
      acoustIdApiKey: clearAcoustId ? null : (acoustIdApiKey ?? this.acoustIdApiKey),
      groqApiKey: clearGroq ? null : (groqApiKey ?? this.groqApiKey),
      folderStructureStyle: folderStructureStyle ?? this.folderStructureStyle,
      fileRenameFormat: fileRenameFormat ?? this.fileRenameFormat,
      useGroqFolderNames: useGroqFolderNames ?? this.useGroqFolderNames,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState()) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final acoustIdKey = await SettingsService.getAcoustIdApiKey();
    final groqKey = await SettingsService.getGroqApiKey();
    final folderStyle = await SettingsService.getFolderStructureStyle();
    final renameFormat = await SettingsService.getFileRenameFormat();
    final useGroq = await SettingsService.getUseGroqFolderNames();

    state = state.copyWith(
      acoustIdApiKey: acoustIdKey,
      groqApiKey: groqKey,
      folderStructureStyle: folderStyle,
      fileRenameFormat: renameFormat,
      useGroqFolderNames: useGroq,
    );
  }

  Future<void> saveAcoustIdKey(String key) async {
    if (key.trim().isEmpty) {
      await SettingsService.clearAcoustIdApiKey();
      state = state.copyWith(clearAcoustId: true);
    } else {
      await SettingsService.saveAcoustIdApiKey(key);
      state = state.copyWith(acoustIdApiKey: key);
    }
  }

  Future<void> saveGroqKey(String key) async {
    if (key.trim().isEmpty) {
      await SettingsService.clearGroqApiKey();
      state = state.copyWith(clearGroq: true);
    } else {
      await SettingsService.saveGroqApiKey(key);
      state = state.copyWith(groqApiKey: key);
    }
  }

  Future<void> saveFolderStructureStyle(String style) async {
    await SettingsService.saveFolderStructureStyle(style);
    state = state.copyWith(folderStructureStyle: style);
  }

  Future<void> saveFileRenameFormat(String format) async {
    await SettingsService.saveFileRenameFormat(format);
    state = state.copyWith(fileRenameFormat: format);
  }

  Future<void> saveUseGroqFolderNames(bool useGroq) async {
    await SettingsService.saveUseGroqFolderNames(useGroq);
    state = state.copyWith(useGroqFolderNames: useGroq);
  }

  Future<void> clearAllSettings() async {
    await SettingsService.clearAllSettings();
    await loadSettings();
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});
