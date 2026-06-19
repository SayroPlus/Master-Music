import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/database/database_helper.dart';
import '../../providers/folder_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Controllers
  final _acoustIdController = TextEditingController();
  final _groqController = TextEditingController();
  final _resetController = TextEditingController();

  // Focus Nodes
  final _acoustIdFocus = FocusNode();
  final _groqFocus = FocusNode();

  // Toggles
  bool _obsecureAcoustId = true;
  bool _obsecureGroq = true;

  // Local state cache mapping
  int _backupCount = 0;
  String _cacheSize = "Calculating...";

  // Testing states
  bool _isTestingAcoust = false;
  String? _acoustResult;
  bool _isTestingGroq = false;
  String? _groqResult;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _initStats());
  }
  
  void _listenSettings(SettingsState state) {
    if (_acoustIdController.text != (state.acoustIdApiKey ?? '') && !_acoustIdFocus.hasFocus) {
       _acoustIdController.text = state.acoustIdApiKey ?? '';
    }
    if (_groqController.text != (state.groqApiKey ?? '') && !_groqFocus.hasFocus) {
       _groqController.text = state.groqApiKey ?? '';
    }
  }

  Future<void> _initStats() async {
    final count = await DatabaseHelper().getBackupSnapshotCount();
    final cacheBytes = await _calculateCacheSize();
    
    if (mounted) {
      setState(() {
        _backupCount = count;
        _cacheSize = _formatSize(cacheBytes);
      });
    }
  }

  Future<int> _calculateCacheSize() async {
    try {
      final dir = await getTemporaryDirectory();
      if (!dir.existsSync()) return 0;
      int size = 0;
      await for (final file in dir.list(recursive: true, followLinks: false)) {
        if (file is File) {
          size += await file.length();
        }
      }
      return size;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _clearCache() async {
    try {
      final dir = await getTemporaryDirectory();
      if (dir.existsSync()) {
        await for (final file in dir.list(recursive: true, followLinks: false)) {
          if (file is File) await file.delete();
        }
      }
      _initStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cache cleared successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear cache: $e')),
        );
      }
    }
  }

  Future<void> _clearBackups() async {
    final db = await DatabaseHelper().database;
    await db.delete('backup_snapshots');
    _initStats();
  }

  String _formatSize(int bytes) {
    if (bytes == 0) return '0 B';
    final kb = bytes / 1024;
    final mb = kb / 1024;
    if (mb > 1) return '${mb.toStringAsFixed(1)} MB';
    return '${kb.toStringAsFixed(1)} KB';
  }

  @override
  void dispose() {
    _acoustIdController.dispose();
    _groqController.dispose();
    _resetController.dispose();
    _acoustIdFocus.dispose();
    _groqFocus.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // API Testing logic
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _testAcoustId() async {
    final key = _acoustIdController.text.trim();
    if (key.isEmpty) return;

    setState(() {
      _isTestingAcoust = true;
      _acoustResult = null;
    });

    try {
      final dio = Dio();
      final response = await dio.get('https://api.acoustid.org/v2/lookup?client=$key');
      // If it complains about missing meta/format, the key is still processed as valid
      if (response.data is Map && response.data['status'] == 'error') {
        final error = response.data['error']?['message'] ?? '';
        if (error == 'invalid client') {
          setState(() => _acoustResult = 'Invalid ✗');
        } else {
          setState(() => _acoustResult = 'Valid ✓');
        }
      } else {
        setState(() => _acoustResult = 'Valid ✓');
      }
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 400) {
        final errObj = e.response?.data;
        if (errObj is Map && errObj['error']?['message'] == 'invalid client') {
           setState(() => _acoustResult = 'Invalid ✗');
        } else {
           setState(() => _acoustResult = 'Valid ✓');
        }
      } else {
        setState(() => _acoustResult = 'Failed ✗');
      }
    } finally {
      setState(() => _isTestingAcoust = false);
    }
  }

  Future<void> _testGroq() async {
    final key = _groqController.text.trim();
    if (key.isEmpty) return;

    setState(() {
      _isTestingGroq = true;
      _groqResult = null;
    });

    try {
      final dio = Dio();
      await dio.post(
        'https://api.groq.com/openai/v1/chat/completions',
        options: Options(headers: {'Authorization': 'Bearer $key'}),
        data: {
          'model': AppStrings.groqModel,
          'messages': [{'role': 'user', 'content': 'hi'}],
          'max_tokens': 5,
        },
      );
      setState(() => _groqResult = 'Valid ✓');
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
        setState(() => _groqResult = 'Invalid ✗');
      } else {
        setState(() => _groqResult = 'Failed ✗');
      }
    } finally {
      setState(() => _isTestingGroq = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Dialogs
  // ═══════════════════════════════════════════════════════════════════════════

  void _showResetDialog({required bool fullReset}) {
    _resetController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          fullReset ? 'Full Reset' : 'Reset Library',
          style: const TextStyle(color: AppColors.error),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fullReset
                  ? 'This will wipe your SQLite database AND all your saved settings/API keys.'
                  : 'This will purge your SQLite library tables but retain your Settings & API Configuration.',
            ),
            const SizedBox(height: 16),
            const Text(
              'Type "RESET" to confirm:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _resetController,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) {
                // Trigger rebuild of action buttons inside dialog
                (ctx as Element).markNeedsBuild();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: _resetController.text == 'RESET'
                ? () async {
                    Navigator.pop(ctx);
                    if (fullReset) {
                      await DatabaseHelper().clearAllData();
                      await ref.read(settingsProvider.notifier).clearAllSettings();
                    } else {
                      await DatabaseHelper().clearAllData();
                    }
                    
                    // Reload states
                    ref.read(libraryProvider.notifier).loadSongs();
                    ref.read(folderProvider.notifier).loadFolders();
                    _initStats();
                    
                    if (mounted) {
                       ScaffoldMessenger.of(context).showSnackBar(
                         const SnackBar(content: Text('Reset operation completed successfully.')),
                       );
                    }
                  }
                : null,
            child: Text(
              'CONFIRM',
              style: TextStyle(
                color: _resetController.text == 'RESET' ? AppColors.error : AppColors.textHint,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UI Builder
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final folders = ref.watch(folderProvider).folders;
    
    // Sync external changes properly
    _listenSettings(settings);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        backgroundColor: AppColors.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          
          // 1. API Configuration
          _buildSectionHeader('API Configuration'),
          _buildApiKeyField(
            title: 'AcoustID API Key',
            helper: 'Get your free key at acoustid.org',
            controller: _acoustIdController,
            focusNode: _acoustIdFocus,
            isObscured: _obsecureAcoustId,
            toggleObscure: () => setState(() => _obsecureAcoustId = !_obsecureAcoustId),
            onSave: () => ref.read(settingsProvider.notifier).saveAcoustIdKey(_acoustIdController.text),
            isTesting: _isTestingAcoust,
            testResult: _acoustResult,
            onTest: _testAcoustId,
          ),
          const SizedBox(height: 16),
          _buildApiKeyField(
            title: 'Groq API Key',
            helper: 'Get free key at console.groq.com',
            controller: _groqController,
            focusNode: _groqFocus,
            isObscured: _obsecureGroq,
            toggleObscure: () => setState(() => _obsecureGroq = !_obsecureGroq),
            onSave: () => ref.read(settingsProvider.notifier).saveGroqKey(_groqController.text),
            isTesting: _isTestingGroq,
            testResult: _groqResult,
            onTest: _testGroq,
          ),
          
          const Divider(height: 48),

          // 2. Storage Folders
          _buildSectionHeader('Storage Folders'),
          ...folders.map((folder) => ListTile(
                leading: const Icon(Icons.folder_rounded, color: AppColors.primary),
                title: Text(folder.folderName),
                subtitle: Text('${folder.songCount} songs'),
                trailing: IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textHint),
                  onPressed: () {
                    // Quick remove logic directly calling provider is preferred
                    ref.read(folderProvider.notifier).removeFolder(folder.id!);
                  },
                ),
              )),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.create_new_folder_rounded),
                    label: const Text('Add Folder'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary.withAlpha(40),
                      foregroundColor: AppColors.primary,
                    ),
                    onPressed: () {
                      Navigator.pushNamed(context, '/folder-picker');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.sync_rounded),
                    label: const Text('Rescan All'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      // Trigger rescan trigger
                      // Example: context.read(fileScannerProvider).scanAll();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Rescan triggered')),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 48),

          // 3. Organization Settings
          _buildSectionHeader('Organization Settings'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Folder Structure Style', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        title: const Text('Artist/Album'),
                        value: 'Artist/Album',
                        groupValue: settings.folderStructureStyle,
                        onChanged: (val) => ref.read(settingsProvider.notifier).saveFolderStructureStyle(val!),
                        activeColor: AppColors.primary,
                      ),
                      RadioListTile<String>(
                        title: const Text('Genre/Artist'),
                        value: 'Genre/Artist',
                        groupValue: settings.folderStructureStyle,
                        onChanged: (val) => ref.read(settingsProvider.notifier).saveFolderStructureStyle(val!),
                        activeColor: AppColors.primary,
                      ),
                      RadioListTile<String>(
                        title: const Text('Flat (All in one folder)'),
                        value: 'Flat',
                        groupValue: settings.folderStructureStyle,
                        onChanged: (val) => ref.read(settingsProvider.notifier).saveFolderStructureStyle(val!),
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                const Text('File Rename Format', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      dropdownColor: AppColors.surface,
                      value: settings.fileRenameFormat,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'Artist - Title.mp3', child: Text('Artist - Title.mp3')),
                        DropdownMenuItem(value: 'Title - Artist.mp3', child: Text('Title - Artist.mp3')),
                        DropdownMenuItem(value: 'TrackNo. Title.mp3', child: Text('TrackNo. Title.mp3')),
                        DropdownMenuItem(value: 'Original filename', child: Text('Original filename (no rename)')),
                      ],
                      onChanged: (val) => ref.read(settingsProvider.notifier).saveFileRenameFormat(val!),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Use Groq for folder name cleaning'),
                  activeColor: AppColors.primary,
                  value: settings.useGroqFolderNames,
                  onChanged: (val) => ref.read(settingsProvider.notifier).saveUseGroqFolderNames(val),
                ),
              ],
            ),
          ),
          
          const Divider(height: 48),

          // 4. Backup & Storage
          _buildSectionHeader('Backup & Storage'),
          ListTile(
            title: const Text('Backups stored'),
            trailing: Text('$_backupCount', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton(
              onPressed: _backupCount > 0
                  ? () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Clear Backups?'),
                          content: const Text('This will permanently delete all metadata undo histories.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.error))),
                          ],
                        ),
                      );
                      if (confirm == true) _clearBackups();
                    }
                  : null,
              child: const Text('Clear all backups', style: TextStyle(color: AppColors.error)),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('App cache size'),
            trailing: Text(_cacheSize, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton(
              onPressed: _clearCache,
              child: const Text('Clear cache', style: TextStyle(color: Colors.white)),
            ),
          ),

          const Divider(height: 48),

          // 5. About
          _buildSectionHeader('About'),
          const ListTile(
            title: Text('Music Organizer'),
            subtitle: Text('Version 1.0.0+1\nBuilt with Flutter'),
            isThreeLine: true,
          ),
          ListTile(
            leading: const Icon(Icons.language_rounded, color: AppColors.textSecondary),
            title: const Text('MusicBrainz'),
            trailing: const Icon(Icons.open_in_new_rounded, size: 16, color: AppColors.textHint),
            onTap: () => launchUrl(Uri.parse('https://musicbrainz.org')),
          ),
          ListTile(
            leading: const Icon(Icons.language_rounded, color: AppColors.textSecondary),
            title: const Text('AcoustID'),
            trailing: const Icon(Icons.open_in_new_rounded, size: 16, color: AppColors.textHint),
            onTap: () => launchUrl(Uri.parse('https://acoustid.org')),
          ),
          ListTile(
            leading: const Icon(Icons.language_rounded, color: AppColors.textSecondary),
            title: const Text('Groq Cloud API'),
            trailing: const Icon(Icons.open_in_new_rounded, size: 16, color: AppColors.textHint),
            onTap: () => launchUrl(Uri.parse('https://console.groq.com')),
          ),

          const Divider(height: 48),

          // 6. Danger Zone
          _buildSectionHeader('Danger Zone', color: AppColors.error),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error.withAlpha(40),
                    foregroundColor: AppColors.error,
                  ),
                  onPressed: () => _showResetDialog(fullReset: false),
                  child: const Text('Reset Library'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _showResetDialog(fullReset: true),
                  child: const Text('Full Reset'),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 64),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {Color color = AppColors.primary}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildApiKeyField({
    required String title,
    required String helper,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool isObscured,
    required VoidCallback toggleObscure,
    required VoidCallback onSave,
    required bool isTesting,
    required String? testResult,
    required VoidCallback onTest,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
               if (testResult != null)
                 Text(
                   testResult,
                   style: TextStyle(
                     fontWeight: FontWeight.bold,
                     color: testResult.contains('Valid') ? AppColors.success : AppColors.error,
                   ),
                 ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            focusNode: focusNode,
            obscureText: isObscured,
            decoration: InputDecoration(
              hintText: 'Paste your API key here',
              helperText: helper,
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: Icon(isObscured ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                color: AppColors.textHint,
                onPressed: toggleObscure,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: isTesting ? null : onTest,
                child: isTesting 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Test Key', style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: onSave,
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
