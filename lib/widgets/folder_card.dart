import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../models/folder_model.dart';

/// A card widget displaying a music folder with selection checkbox.
///
/// Shows folder name, path, song count, total size, and optional
/// preview of song file names. Selected state is indicated by a
/// purple border and filled checkbox.
class FolderCard extends StatelessWidget {
  final FolderModel folder;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final List<String> songPreviews;

  const FolderCard({
    super.key,
    required this.folder,
    this.isSelected = false,
    this.onTap,
    this.onRemove,
    this.songPreviews = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // ── Folder icon ─────────────────────────────────────
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withAlpha(30)
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.folder_rounded,
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // ── Folder info ─────────────────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name
                        Text(
                          folder.folderName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? AppColors.textPrimary
                                    : AppColors.textPrimary,
                              ),
                        ),
                        const SizedBox(height: 3),

                        // Stats row: song count + size
                        Row(
                          children: [
                            Icon(
                              Icons.music_note_rounded,
                              size: 13,
                              color: AppColors.textHint,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${folder.songCount} songs',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.storage_rounded,
                              size: 13,
                              color: AppColors.textHint,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              folder.formattedSize,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                          ],
                        ),

                        // Song previews (first 2-3 file names)
                        if (songPreviews.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            songPreviews.take(3).join(', '),
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

                  // ── Checkbox / Remove ───────────────────────────────
                  if (onRemove != null)
                    IconButton(
                      onPressed: onRemove,
                      icon: const Icon(
                        Icons.remove_circle_outline_rounded,
                        color: AppColors.error,
                        size: 22,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      padding: EdgeInsets.zero,
                    )
                  else
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.navBarUnselected,
                          width: 1.5,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                          : null,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A compact system/excluded folder card with a warning icon.
class SystemFolderCard extends StatelessWidget {
  final FolderModel folder;

  const SystemFolderCard({super.key, required this.folder});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 18,
              color: AppColors.warning.withAlpha(180),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    folder.folderName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  Text(
                    '${folder.songCount} songs',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textHint,
                          fontSize: 11,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
