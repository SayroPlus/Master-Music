import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

/// Displays album art intelligently from local path, network URL, or a fallback.
class AlbumArt extends StatelessWidget {
  final String? localPath;
  final String? imageUrl;
  final double size;
  final double borderRadius;

  const AlbumArt({
    super.key,
    this.localPath,
    this.imageUrl,
    this.size = 50.0,
    this.borderRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(50),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: _buildImage(),
      ),
    );
  }

  Widget _buildImage() {
    // 1. Try local path first
    if (localPath != null && localPath!.isNotEmpty) {
      final file = File(localPath!);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildFallback(),
        );
      }
    }

    // 2. Try network URL
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildShimmer(),
        errorWidget: (context, url, error) => _buildFallback(),
      );
    }

    // 3. Fallback to icon
    return _buildFallback();
  }

  Widget _buildShimmer() {
    // A simple colored box to act as a placeholder. We could use the shimmer
    // package here, but a solid color works well for tiny list thumbnails.
    return Container(
      width: size,
      height: size,
      color: AppColors.surfaceLight,
    );
  }

  Widget _buildFallback() {
    return Container(
      width: size,
      height: size,
      color: AppColors.primary.withAlpha(50),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          color: AppColors.primary,
          size: size * 0.5,
        ),
      ),
    );
  }
}
