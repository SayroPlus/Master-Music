import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../../core/constants/app_colors.dart';
import '../../models/folder_model.dart';
import '../../providers/folder_provider.dart';
import '../../services/file_scanner_service.dart';
import '../../widgets/folder_card.dart';
import '../../app.dart';

/// Screen for selecting music folders to monitor.
///
/// On first load, auto-scans the device for folders containing audio files.
/// Shows results as selectable cards. On continue, scans selected folders
/// for songs and navigates to MainShell.
class FolderPickerScreen extends ConsumerStatefulWidget {
  const FolderPickerScreen({super.key});

  @override
  ConsumerState<FolderPickerScreen> createState() => _FolderPickerScreenState();
}

class _FolderPickerScreenState extends ConsumerState<FolderPickerScreen> {
  /// All discovered music folders from device scan.
  List<FolderModel> _musicFolders = [];

  /// System/excluded folders found during scan.
  List<FolderModel> _systemFolders = [];

  /// Set of selected folder paths.
  final Set<String> _selectedPaths = {};

  /// Song file name previews per folder path.
  Map<String, List<String>> _songPreviews = {};

  bool _isScanning = true;
  bool _isImporting = false;
  int _importProgress = 0;
  int _importTotal = 0;
  String _scanStatus = 'Scanning your storage for music folders...';
  bool _systemFoldersExpanded = false;

  final FileScannerService _scanner = FileScannerService();

  // ── System folder detection ─────────────────────────────────────────────

  static const Set<String> _systemPatterns = {
    'whatsapp',
    'telegram',
    'recordings',
    'miui',
    'sound_recorder',
    'com.sec.android.app.voicenote',
    'ringtones',
    'notifications',
    'alarms',
  };

  bool _isSystemFolder(String path) {
    final lower = path.toLowerCase();
    for (final pattern in _systemPatterns) {
      if (lower.contains(pattern)) return true;
    }
    return false;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Lifecycle
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _scanStatus = 'Scanning your storage for music folders...';
    });

    try {
      final folders = await _scanner.scanAllFoldersWithAudio(
        onProgress: (dir) {
          if (mounted) {
            setState(() {
              _scanStatus = 'Scanning: ${p.basename(dir)}';
            });
          }
        },
      );

      if (!mounted) return;

      // Separate music folders from system folders
      final music = <FolderModel>[];
      final system = <FolderModel>[];

      for (final folder in folders) {
        if (_isSystemFolder(folder.folderPath)) {
          system.add(folder);
        } else {
          music.add(folder);
        }
      }

      // Load song previews for each folder (first 3 filenames)
      final previews = <String, List<String>>{};
      for (final folder in [...music, ...system]) {
        try {
          final dir = Directory(folder.folderPath);
          if (await dir.exists()) {
            final names = <String>[];
            await for (final entity in dir.list(followLinks: false)) {
              if (entity is File &&
                  FileScannerService.isAudioFile(entity.path)) {
                names.add(p.basenameWithoutExtension(entity.path));
                if (names.length >= 3) break;
              }
            }
            previews[folder.folderPath] = names;
          }
        } catch (_) {}
      }

      // Pre-select previously saved folders
      final savedPaths = await FolderNotifier.loadSelectedPaths();

      setState(() {
        _musicFolders = music;
        _systemFolders = system;
        _songPreviews = previews;
        _isScanning = false;
        // Pre-select previously saved folders, or select all if first time
        if (savedPaths.isNotEmpty) {
          _selectedPaths.addAll(savedPaths);
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _scanStatus = 'Scan failed: $e';
        });
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Actions
  // ═══════════════════════════════════════════════════════════════════════════

  void _toggleFolder(FolderModel folder) {
    setState(() {
      if (_selectedPaths.contains(folder.folderPath)) {
        _selectedPaths.remove(folder.folderPath);
      } else {
        _selectedPaths.add(folder.folderPath);
      }
    });
  }

  Future<void> _addManualFolder() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null && mounted) {
      // Count audio files in the picked directory
      int songCount = 0;
      int totalSize = 0;
      final previews = <String>[];

      try {
        final dir = Directory(result);
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File && FileScannerService.isAudioFile(entity.path)) {
            songCount++;
            totalSize += await entity.length();
            if (previews.length < 3) {
              previews.add(p.basenameWithoutExtension(entity.path));
            }
          }
        }
      } catch (_) {}

      if (songCount == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No audio files found in this folder'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        return;
      }

      final folder = FolderModel(
        folderPath: result,
        folderName: p.basename(result),
        songCount: songCount,
        totalSize: totalSize,
        isSelected: true,
      );

      setState(() {
        // Add to music folders if not already present
        if (!_musicFolders.any((f) => f.folderPath == result)) {
          _musicFolders.insert(0, folder);
        }
        _songPreviews[result] = previews;
        _selectedPaths.add(result);
      });
    }
  }

  Future<void> _continueWithSelection() async {
    if (_selectedPaths.isEmpty) return;

    // Build the list of selected FolderModels
    final selectedFolders = _musicFolders
        .where((f) => _selectedPaths.contains(f.folderPath))
        .map((f) => f.copyWith(isSelected: true))
        .toList();

    // Show scanning bottom sheet
    setState(() {
      _isImporting = true;
      _importProgress = 0;
      _importTotal = selectedFolders.fold(0, (sum, f) => sum + f.songCount);
    });

    _showScanningSheet();

    try {
      // Save folders to DB
      await ref.read(folderProvider.notifier).saveSelectedFolders(selectedFolders);

      // Scan songs
      final totalSongs = await _scanner.scanSongsInFolders(
        selectedFolders,
        onProgress: (scanned, total) {
          if (mounted) {
            setState(() {
              _importProgress = scanned;
            });
          }
        },
      );

      if (!mounted) return;

      // Close bottom sheet
      Navigator.of(context).pop();

      // Navigate to main shell
      Navigator.of(context).pushReplacementNamed(AppRoutes.main);

      // Show success snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Library loaded: $totalSongs songs found'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close bottom sheet
        setState(() => _isImporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showScanningSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            // Re-read state for progress updates
            final progress = _importProgress;
            final total = _importTotal;
            final fraction = total > 0 ? (progress / total).clamp(0.0, 1.0) : 0.0;

            // Schedule a rebuild when progress changes
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted && _isImporting) {
                setSheetState(() {});
              }
            });

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textHint,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Icon(
                    Icons.scanner_rounded,
                    color: AppColors.primary,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Scanning songs...',
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$progress ${total > 0 ? 'of $total' : ''} files processed',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total > 0 ? fraction : null,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Computed values
  // ═══════════════════════════════════════════════════════════════════════════

  int get _selectedCount => _selectedPaths.length;

  int get _selectedSongCount {
    int count = 0;
    for (final folder in _musicFolders) {
      if (_selectedPaths.contains(folder.folderPath)) {
        count += folder.songCount;
      }
    }
    return count;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Music Folders'),
        actions: [
          // Manual add folder button
          IconButton(
            icon: const Icon(Icons.create_new_folder_rounded),
            tooltip: 'Add folder manually',
            onPressed: _isScanning ? null : _addManualFolder,
          ),
        ],
      ),
      body: _isScanning ? _buildScanningState() : _buildFolderList(),
      bottomNavigationBar: _isScanning ? null : _buildBottomBar(),
    );
  }

  // ── Scanning state ────────────────────────────────────────────────────

  Widget _buildScanningState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.primary,
                backgroundColor: AppColors.surfaceLight,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              _scanStatus,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'This may take a moment...',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  // ── Folder list ───────────────────────────────────────────────────────

  Widget _buildFolderList() {
    return CustomScrollView(
      slivers: [
        // Subtitle
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Text(
              'Choose folders containing your songs',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),

        // Music folders
        if (_musicFolders.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                children: [
                  Icon(Icons.folder_off_rounded, size: 64, color: AppColors.textHint),
                  const SizedBox(height: 16),
                  Text(
                    'No music folders found',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the folder icon above to add one manually',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final folder = _musicFolders[index];
                final isSelected = _selectedPaths.contains(folder.folderPath);
                return FolderCard(
                  folder: folder,
                  isSelected: isSelected,
                  songPreviews: _songPreviews[folder.folderPath] ?? [],
                  onTap: () => _toggleFolder(folder),
                );
              },
              childCount: _musicFolders.length,
            ),
          ),

        // System folders section (collapsible)
        if (_systemFolders.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: InkWell(
                onTap: () {
                  setState(() => _systemFoldersExpanded = !_systemFoldersExpanded);
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: AppColors.warning.withAlpha(180),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'System Folders (excluded) · ${_systemFolders.length}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: _systemFoldersExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.expand_more_rounded,
                          size: 20,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_systemFoldersExpanded)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return SystemFolderCard(folder: _systemFolders[index]);
                },
                childCount: _systemFolders.length,
              ),
            ),
        ],

        // Bottom padding
        const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
      ],
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        child: Row(
          children: [
            // Selection info
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_selectedCount folder${_selectedCount != 1 ? 's' : ''} selected',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$_selectedSongCount songs total',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            // Continue button
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _selectedCount > 0 && !_isImporting
                    ? _continueWithSelection
                    : null,
                child: _isImporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
