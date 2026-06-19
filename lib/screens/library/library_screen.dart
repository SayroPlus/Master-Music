import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shimmer/shimmer.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../providers/library_provider.dart';
import '../../providers/folder_provider.dart';
import '../../providers/player_provider.dart';
import '../../widgets/song_tile.dart';
import '../../widgets/album_art.dart';

/// The main library screen, handling search, filtering, and selection mode.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(libraryProvider.notifier).loadSongs();
      ref.read(folderProvider.notifier).loadFolders();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Computes a "Last scanned" string from folder data.
  String _getLastScannedText(FolderState folderState) {
    DateTime? latest;
    for (final folder in folderState.folders) {
      if (folder.lastScanned != null) {
        if (latest == null || folder.lastScanned!.isAfter(latest)) {
          latest = folder.lastScanned;
        }
      }
    }
    if (latest == null) return '';

    final diff = DateTime.now().difference(latest);
    if (diff.inMinutes < 5) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    return '${diff.inDays} days ago';
  }

  void _onSongTap(int songId) {
    final libState = ref.read(libraryProvider);
    if (libState.isSelectionMode) {
      ref.read(libraryProvider.notifier).toggleSelection(songId);
    } else {
      final songIndex = libState.filteredSongs.indexWhere((s) => s.id == songId);
      if (songIndex >= 0) {
        final song = libState.filteredSongs[songIndex];
        ref.read(playerProvider.notifier).playSong(
          song,
          queue: libState.filteredSongs,
          index: songIndex,
        );
      }
    }
  }

  void _onSongLongPress(int songId) {
    ref.read(libraryProvider.notifier).toggleSelection(songId);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryProvider);
    final folderState = ref.watch(folderProvider);
    final lastScanned = _getLastScannedText(folderState);

    return Scaffold(
      appBar: _buildAppBar(context, state, lastScanned),
      body: Column(
        children: [
          // Filter Chips
          if (!state.isSelectionMode && !_isSearching)
            _buildFilterRow(context, state),
          
          // Search Field
          if (_isSearching && !state.isSelectionMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (query) {
                  ref.read(libraryProvider.notifier).setSearchQuery(query);
                },
                decoration: InputDecoration(
                  hintText: 'Search songs, artists, albums...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      setState(() => _isSearching = false);
                      _searchController.clear();
                      ref.read(libraryProvider.notifier).setSearchQuery('');
                    },
                  ),
                ),
              ),
            ),
            
          // Main Content
          Expanded(
            child: _buildBody(context, state),
          ),
        ],
      ),
      bottomNavigationBar: state.isSelectionMode
          ? _buildSelectionBottomBar(context, state)
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    LibraryState state,
    String lastScanned,
  ) {
    if (state.isSelectionMode) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => ref.read(libraryProvider.notifier).clearSelection(),
        ),
        title: Text('${state.selectedSongIds.length} selected'),
        actions: [
          IconButton(
            icon: const Icon(Icons.select_all_rounded),
            tooltip: 'Select All',
            onPressed: () => ref.read(libraryProvider.notifier).selectAll(),
          ),
        ],
      );
    }

    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('My Library'),
          if (lastScanned.isNotEmpty)
            Text(
              'Last scanned: $lastScanned',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textHint,
                    fontSize: 12,
                  ),
            ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded),
          tooltip: 'Search',
          onPressed: () => setState(() => _isSearching = !_isSearching),
        ),
        IconButton(
          icon: Icon(state.isGridView
              ? Icons.view_list_rounded
              : Icons.grid_view_rounded),
          tooltip: 'Toggle View',
          onPressed: () => ref.read(libraryProvider.notifier).toggleGridView(),
        ),
        IconButton(
          icon: const Icon(Icons.sync_rounded),
          tooltip: 'Rescan',
          onPressed: () {
            // TODO: dispatch rescan to file scanner service
          },
        ),
        IconButton(
          icon: const Icon(Icons.settings_rounded),
          tooltip: 'Settings',
          onPressed: () => Navigator.pushNamed(context, '/settings'),
        ),
      ],
    );
  }

  Widget _buildFilterRow(BuildContext context, LibraryState state) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: FilterType.values.map((type) {
          final isSelected = type == state.currentFilter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(_getFilterLabel(type)),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  ref.read(libraryProvider.notifier).setFilter(type);
                }
              },
              selectedColor: AppColors.primary.withAlpha(50),
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getFilterLabel(FilterType type) {
    switch (type) {
      case FilterType.all: return 'All';
      case FilterType.missingMetadata: return 'Missing Metadata';
      case FilterType.unidentified: return 'Unidentified';
      case FilterType.duplicates: return 'Duplicates';
      case FilterType.recentlyFixed: return 'Recently Fixed';
    }
  }

  Widget _buildBody(BuildContext context, LibraryState state) {
    if (state.isLoading) {
      return _buildShimmerLoading();
    }

    if (state.songs.isEmpty) {
      return _buildEmptyState(context);
    }

    if (state.filteredSongs.isEmpty) {
      return Center(
        child: Text(
          'No songs match the current filter',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    if (state.isGridView) {
      return RefreshIndicator(
        onRefresh: () => ref.read(libraryProvider.notifier).loadSongs(),
        color: AppColors.primary,
        backgroundColor: AppColors.card,
        child: GridView.builder(
          padding: const EdgeInsets.all(16).copyWith(bottom: 80),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.8,
          ),
          itemCount: state.filteredSongs.length,
          itemBuilder: (context, index) {
            return _buildGridTile(context, state.filteredSongs[index], state);
          },
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(libraryProvider.notifier).loadSongs(),
      color: AppColors.primary,
      backgroundColor: AppColors.card,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
      itemCount: state.filteredSongs.length,
      itemBuilder: (context, index) {
        final song = state.filteredSongs[index];
        return SongTile(
          song: song,
          isSelectionMode: state.isSelectionMode,
          isSelected: state.selectedSongIds.contains(song.id),
          onTap: () => _onSongTap(song.id!),
          onLongPress: () => _onSongLongPress(song.id!),
        );
      },
    ));
  }

  Widget _buildGridTile(BuildContext context, song, LibraryState state) {
    final isSelected = state.selectedSongIds.contains(song.id);
    
    return InkWell(
      onTap: () => _onSongTap(song.id!),
      onLongPress: () => _onSongLongPress(song.id!),
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: AlbumArt(
                  localPath: song.coverArtPath,
                  imageUrl: song.coverArtUrl,
                  borderRadius: 12,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                song.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Text(
                song.displayArtist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
          if (state.isSelectionMode)
            Positioned(
              top: 8,
              right: 8,
              child: Checkbox(
                value: isSelected,
                onChanged: (_) => _onSongTap(song.id),
                activeColor: AppColors.primary,
                fillColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AppColors.primary;
                  }
                  return Colors.black54; // Better visibility over art
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.music_off_rounded,
            size: 64,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 16),
          Text(
            AppStrings.libraryEmpty,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Go to Settings to select folders',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      itemCount: 8,
      padding: const EdgeInsets.all(16),
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Shimmer.fromColors(
          baseColor: AppColors.card,
          highlightColor: AppColors.card.withAlpha(150),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 200, height: 16, color: Colors.white),
                    const SizedBox(height: 8),
                    Container(width: 120, height: 12, color: Colors.white),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionBottomBar(BuildContext context, LibraryState state) {
    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionCol(
              icon: Icons.auto_fix_high_rounded,
              label: 'Fix Metadata',
              onTap: () => ref.read(libraryProvider.notifier).fixSelectedMetadata(),
            ),
            _buildActionCol(
              icon: Icons.create_new_folder_rounded,
              label: 'Organize',
              onTap: () => ref.read(libraryProvider.notifier).organizeSelected(),
            ),
            _buildActionCol(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              color: AppColors.error,
              onTap: () {
                // TODO: Show confirmation dialog
                ref.read(libraryProvider.notifier).deleteSelected();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCol({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = AppColors.primary,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
