import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/library_provider.dart';
import '../../providers/organizer_provider.dart';
import 'processing_overlay.dart';
import 'sheets/backup_restore_sheet.dart';
import 'sheets/completion_summary_sheet.dart';
import 'sheets/find_duplicates_sheet.dart';
import 'sheets/fix_metadata_sheet.dart';
import 'sheets/organize_folders_sheet.dart';
import 'widgets/organize_quick_action_card.dart';
import '../../models/folder_model.dart';
import '../../services/duplicate_service.dart';
import '../../services/backup_service.dart';
import '../../services/groq_service.dart';
import '../../services/id3_writer_service.dart';
import '../../core/database/database_helper.dart';
import '../editor/metadata_editor_screen.dart';
import '../../providers/navigation_provider.dart';


enum OrganizationStyle { artistAlbumSong, genreArtistSong, flat }

class OrganizeScreen extends ConsumerStatefulWidget {
  const OrganizeScreen({super.key});

  @override
  ConsumerState<OrganizeScreen> createState() => _OrganizeScreenState();
}

class _OrganizeScreenState extends ConsumerState<OrganizeScreen> {
  OrganizationStyle _selectedStyle = OrganizationStyle.artistAlbumSong;

  // To track route of the overlay
  bool _isOverlayShowing = false;

  // Real data state
  List<DuplicateGroup> _lastDuplicates = [];
  bool _isDuplicateScanning = false;

  @override
  void initState() {
    super.initState();
    // Fetch initial list of missing metadata songs
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(libraryProvider.notifier).setFilter(FilterType.missingMetadata);
    });
  }

  // Listens to organizer state to show/hide the full screen processing overlay
  void _listenToProcessingState() {
    ref.listen<OrganizerState>(organizerProvider, (previous, next) {
      if (next.isProcessing && !_isOverlayShowing) {
        _isOverlayShowing = true;
        showGeneralDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black87,
          pageBuilder: (context, _, __) {
            return ProcessingOverlay(
              onCancel: () {
                // Cancel operation in provider
                ref
                    .read(organizerProvider.notifier)
                    .finishProcessing(error: "Cancelled by user");
              },
            );
          },
        ).then((_) {
          _isOverlayShowing = false;
        });
      } else if (!next.isProcessing && _isOverlayShowing) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).pop(); // Close overlay router
        _isOverlayShowing = false;

        // Show summary sheet if not cancelled explicitly
        if (previous != null && previous.isProcessing) {
          _showCompletionSummary();
        }
      }
    });
  }

  // ── Bottom Sheet Triggers ────────────────────────────────────────────────

  void _showFixMetadataSheet(int missingCount) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => FixMetadataSheet(
        missingMetadataCount: missingCount,
        onStart: () {
          _executeOperation(missingCount, "Fix Metadata", () async {
            final db = DatabaseHelper();
            final songsToFix = await db.getSongsWithMissingMetadata();
            final groq = GroqService();
            final id3Writer = Id3WriterService();
            final libNotifier = ref.read(libraryProvider.notifier);
            final orgNotifier = ref.read(organizerProvider.notifier);
            
            int processed = 0;
            for (final song in songsToFix) {
              if (!ref.read(organizerProvider).isProcessing) break;
              
              orgNotifier.updateProgress(processed: processed, songName: song.fileName);
              
              try {
                final suggestion = await groq.suggestMetadata(song);
                if (suggestion != null) {
                  final success = await id3Writer.writeMetadata(
                    filePath: song.filePath,
                    title: suggestion['title'],
                    artist: suggestion['artist'],
                    album: suggestion['album'],
                    year: suggestion['year'],
                    genre: suggestion['genre'],
                  );
                  
                  if (success) {
                    final updatedSong = song.copyWith(
                      title: suggestion['title'] ?? song.title,
                      artist: suggestion['artist'] ?? song.artist,
                      album: suggestion['album'] ?? song.album,
                      year: suggestion['year'] ?? song.year,
                      genre: suggestion['genre'] ?? song.genre,
                      isModified: true,
                      hasBeenProcessed: true,
                      lastModified: DateTime.now(),
                    );
                    await libNotifier.updateSongMetadata(updatedSong);
                  }
                }
              } catch (e) {
                orgNotifier.addError('Failed fixing ${song.fileName}: $e');
              }
              
              processed++;
            }
          });
        },
      ),
    );
  }

  void _showOrganizeFoldersSheet(int totalSongs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => OrganizeFoldersSheet(
        totalSongs: totalSongs,
        currentStyle: _getStyleLabel(_selectedStyle),
        onPreview: () {},
        onApply: () {
          _executeOperation(totalSongs, "Organize Folders", () async {
            final db = DatabaseHelper();
            final allSongs = await db.getAllSongs();
            final allFolders = await db.getSelectedFolders();
            final libNotifier = ref.read(libraryProvider.notifier);
            final orgNotifier = ref.read(organizerProvider.notifier);
            
            if (allSongs.isEmpty) return;

            int processed = 0;
            for (final song in allSongs) {
              if (!ref.read(organizerProvider).isProcessing) break;
              orgNotifier.updateProgress(processed: processed, songName: song.fileName);

              try {
                // Find the parent folder for this song from our monitored list
                final parentFolder = allFolders.firstWhere(
                  (f) => song.filePath.startsWith(f.folderPath),
                  orElse: () => FolderModel(folderPath: File(song.filePath).parent.path, folderName: ''),
                );
                
                final baseDir = parentFolder.folderPath;

                // Determine new path relative to the base directory
                String newRelativePath;
                
                // Fallback Logic: Try to parse artist from filename if metadata is missing
                String artist = (song.artist?.isNotEmpty == true) ? song.artist! : 'Unknown Artist';
                if (artist == 'Unknown Artist' || artist.isEmpty) {
                  // Try to find "Artist - Title" pattern
                  if (song.fileName.contains(' - ')) {
                    artist = song.fileName.split(' - ').first.trim();
                  } else if (song.fileName.contains('-')) {
                    // Simpler dash check
                    artist = song.fileName.split('-').first.trim();
                  }
                }
                
                final album = (song.album?.isNotEmpty == true) ? song.album! : 'Unknown Album';
                final genre = (song.genre?.isNotEmpty == true) ? song.genre! : 'Unknown Genre';
                final title = song.displayTitle;

                
                switch (_selectedStyle) {
                  case OrganizationStyle.artistAlbumSong:
                    newRelativePath = '$artist/$album/$title${song.format.startsWith('.') ? '' : '.'}${song.format}';
                    break;
                  case OrganizationStyle.genreArtistSong:
                    newRelativePath = '$genre/$artist/$title${song.format.startsWith('.') ? '' : '.'}${song.format}';
                    break;
                  case OrganizationStyle.flat:
                    newRelativePath = '$title${song.format.startsWith('.') ? '' : '.'}${song.format}';
                    break;
                }

                final newFullPath = '$baseDir/$newRelativePath';
                final newFile = File(newFullPath);
                
                if (song.filePath != newFullPath) {
                  if (!await newFile.parent.exists()) {
                    await newFile.parent.create(recursive: true);
                  }
                  
                  final oldFile = File(song.filePath);
                  if (await oldFile.exists()) {
                    await oldFile.rename(newFullPath);
                    await libNotifier.updateSongPath(song.id!, newFullPath);
                  }
                }
              } catch (e) {
                orgNotifier.addError('Failed moving ${song.fileName}: $e');
              }
              
              processed++;
            }
          });
        },
      ),
    );
  }

  void _showFindDuplicatesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => FindDuplicatesSheet(
        isScanning: _isDuplicateScanning,
        duplicates: _lastDuplicates,
        onScan: () async {
          setState(() => _isDuplicateScanning = true);
          try {
            final db = DatabaseHelper();
            final allSongs = await db.getAllSongs();
            final results = await DuplicateService().scanForDuplicates(allSongs);
            if (mounted) {
              setState(() {
                _lastDuplicates = results;
                _isDuplicateScanning = false;
              });
              Navigator.pop(context); // Refresh sheet with results
              _showFindDuplicatesSheet();
            }
          } catch (e) {
            if (mounted) setState(() => _isDuplicateScanning = false);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scan failed: $e')));
          }
        },
        onResolveAll: (groups) async {
          _executeOperation(groups.length, "Resolve Duplicates", () async {
             final service = DuplicateService();
             final orgNotifier = ref.read(organizerProvider.notifier);
             
             int processed = 0;
             for (final group in groups) {
               if (!ref.read(organizerProvider).isProcessing) break;
               orgNotifier.updateProgress(processed: processed, songName: group.songs.first.displayTitle);
               await service.resolveGroup(group, group.recommendedKeepIndex);
               processed++;
             }
             _lastDuplicates = []; // Clear after resolve
          });
        },
      ),
    );
  }

  void _showBackupRestoreSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => BackupRestoreSheet(
        onRestore: (snapshot) async {
          _executeOperation(snapshot.songCount, "Restore", () async {
            await BackupService(databaseHelper: DatabaseHelper()).restoreSnapshot(snapshot);
          });
        },
      ),
    );
  }

  void _showCompletionSummary() {
    final state = ref.read(organizerProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CompletionSummarySheet(
        fixedCount: state.processedCount - state.errors.length,
        skippedCount: 0,
        failedCount: state.errors.length,
        errorMessages: state.errors,
        canUndo: state.canUndo,
        onUndo: () {
          // Restore logic triggered
        },
        onViewChanges: () {
          // Navigate to recently fixed
          ref
              .read(libraryProvider.notifier)
              .setFilter(FilterType.recentlyFixed);
        },
      ),
    );
  }

  // Wrap full executions for real async callbacks
  void _executeOperation(
    int total,
    String actionLabel,
    Future<void> Function() operation,
  ) async {
    final notifier = ref.read(organizerProvider.notifier);
    notifier.startProcessing(total: total);

    try {
      await operation();
      // Resync UI states natively via rivers
      ref.read(libraryProvider.notifier).loadSongs();
      if (ref.read(organizerProvider).isProcessing) {
        notifier.finishProcessing();
      }
    } catch (e) {
      notifier.addError('$actionLabel Failed: $e');
      notifier.finishProcessing(error: e.toString());
    }
  }

  // ── Build Methods ────────────────────────────────────────────────────────

  String _getStyleLabel(OrganizationStyle style) {
    switch (style) {
      case OrganizationStyle.artistAlbumSong:
        return 'Artist / Album / Song';
      case OrganizationStyle.genreArtistSong:
        return 'Genre / Artist / Song';
      case OrganizationStyle.flat:
        return 'Flat Folder (Rename only)';
    }
  }

  String _getStylePreview(OrganizationStyle style) {
    switch (style) {
      case OrganizationStyle.artistAlbumSong:
        return 'Music/Arijit Singh/Aashiqui 2/Arijit Singh - Tum Hi Ho.mp3';
      case OrganizationStyle.genreArtistSong:
        return 'Music/Bollywood/Arijit Singh/Tum Hi Ho.mp3';
      case OrganizationStyle.flat:
        return 'Music/Arijit Singh - Tum Hi Ho.mp3';
    }
  }

  @override
  Widget build(BuildContext context) {
    _listenToProcessingState();

    final theme = Theme.of(context);
    final libraryState = ref.watch(libraryProvider);

    // In a real app we might fetch these counts efficiently from SQLite directly
    // For UI demonstration, we rely on the filtered library elements
    final missingCount = libraryState.filteredSongs.length;
    final totalSongs = libraryState.songs.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Organize'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Settings',
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section A: Quick Actions ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Bulk Actions', style: theme.textTheme.titleMedium),
            ),
            SizedBox(
              height: 140,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                children: [
                  OrganizeQuickActionCard(
                    title: 'Fix All Metadata',
                    subtitle: '$missingCount songs missing data',
                    icon: Icons.auto_fix_high,
                    color: AppColors.primary,
                    onTap: () => _showFixMetadataSheet(missingCount),
                  ),
                  OrganizeQuickActionCard(
                    title: 'Organize Folders',
                    subtitle: 'Rename and sort $totalSongs files',
                    icon: Icons.folder,
                    color: Colors.orange,
                    onTap: () => _showOrganizeFoldersSheet(totalSongs),
                  ),
                  OrganizeQuickActionCard(
                    title: 'Find Duplicates',
                    subtitle: 'Detect identical files',
                    icon: Icons.copy_all,
                    color: Colors.purple,
                    onTap: _showFindDuplicatesSheet,
                  ),
                  OrganizeQuickActionCard(
                    title: 'Backup & Restore',
                    subtitle: 'Manage local snapshots',
                    icon: Icons.restore,
                    color: Colors.teal,
                    onTap: _showBackupRestoreSheet,
                  ),
                ],
              ),
            ),

            const Divider(height: 32),

            // ── Section B: Songs Needing Attention ───────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Needing Attention', style: theme.textTheme.titleMedium),
                  if (libraryState.isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (missingCount == 0 && !libraryState.isLoading)
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Center(
                  child: Text(
                    'All clear! Your library looks perfectly organized.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.green,
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: missingCount > 5
                    ? 5
                    : missingCount, // Show max 5 in this view
                itemBuilder: (context, index) {
                  final song = libraryState.filteredSongs[index];

                  // Determine missing parts for UI hint
                  final List<String> missing = [];
                  if (song.artist == null) missing.add('artist');
                  if (song.album == null) missing.add('album');
                  final missingLabel = missing.isEmpty
                      ? 'unidentified'
                      : 'No ${missing.join(' or ')}';

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.music_note, color: Colors.grey),
                    ),
                    title: Text(
                      song.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      missingLabel,
                      style: const TextStyle(color: AppColors.error),
                    ),
                    trailing: FilledButton.tonal(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MetadataEditorScreen(song: song),
                          ),
                        );
                      },
                      child: const Text('Fix'),
                    ),
                  );
                },
              ),

            if (missingCount > 5)
              Center(
                child: TextButton(
                  onPressed: () {
                    ref.read(navigationProvider.notifier).goToLibraryWithFilter(FilterType.missingMetadata);
                  },
                  child: Text('View all $missingCount songs'),
                ),
              ),

            const Divider(height: 32),

            // ── Section C: Organization Style Selector ───────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Organization Style',
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(
                  0.5,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Text(
                'Example:\n${_getStylePreview(_selectedStyle)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            RadioListTile<OrganizationStyle>(
              title: const Text('Artist → Album → Song'),
              value: OrganizationStyle.artistAlbumSong,
              groupValue: _selectedStyle,
              onChanged: (val) => setState(() => _selectedStyle = val!),
              activeColor: AppColors.primary,
            ),
            RadioListTile<OrganizationStyle>(
              title: const Text('Genre → Artist → Song'),
              value: OrganizationStyle.genreArtistSong,
              groupValue: _selectedStyle,
              onChanged: (val) => setState(() => _selectedStyle = val!),
              activeColor: AppColors.primary,
            ),
            RadioListTile<OrganizationStyle>(
              title: const Text('Flat (Rename only, no subfolders)'),
              value: OrganizationStyle.flat,
              groupValue: _selectedStyle,
              onChanged: (val) => setState(() => _selectedStyle = val!),
              activeColor: AppColors.primary,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
