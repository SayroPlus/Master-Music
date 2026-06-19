import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../models/song_model.dart';
import '../screens/editor/metadata_editor_screen.dart';
import 'album_art.dart';
import 'confidence_badge.dart';

/// A list tile displaying a single song with album art, title, artist, 
/// and a confidence badge (if processed). Supports selection mode.
class SongTile extends StatelessWidget {
  final SongModel song;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const SongTile({
    super.key,
    required this.song,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected ? AppColors.primary.withAlpha(20) : Colors.transparent;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      splashColor: AppColors.primary.withAlpha(30),
      highlightColor: AppColors.primary.withAlpha(10),
      child: Container(
        color: bgColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            if (isSelectionMode) ...[
              Checkbox(
                value: isSelected,
                onChanged: (_) => onTap?.call(),
                activeColor: AppColors.primary,
                side: BorderSide(color: AppColors.textHint, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
            ],
            
            Hero(
              tag: 'album_art_${song.filePath}',
              child: AlbumArt(
                localPath: song.coverArtPath,
                imageUrl: song.coverArtUrl,
                size: 50,
                borderRadius: 8,
              ),
            ),
            const SizedBox(width: 12),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.displayArtist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  if (song.displayAlbum.isNotEmpty && song.displayAlbum != 'Unknown Album') ...[
                    const SizedBox(height: 2),
                    Text(
                      song.displayAlbum,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textHint,
                            fontSize: 11,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            
            if (song.hasBeenProcessed && song.confidenceLevel != null)
              ConfidenceBadge(level: song.confidenceLevel)
            else if (!isSelectionMode)
              Text(
                song.formattedDuration,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textHint,
                    ),
              ),
              
            if (!isSelectionMode)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textHint),
                color: AppColors.card,
                onSelected: (value) {
                  if (value == 'edit') {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => MetadataEditorScreen(song: song),
                    ));
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 8),
                        Text('Edit Metadata'),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
