import 'dart:io';

/// Service that orchestrates file organization operations.
///
/// Handles moving, renaming, and reorganizing audio files based on
/// AI suggestions or user-defined rules.
class OrganizerService {
  /// Moves a file from [sourcePath] to [destinationPath].
  ///
  /// Creates destination directories if they don't exist.
  /// Returns the new file path on success, `null` on failure.
  Future<String?> moveFile(String sourcePath, String destinationPath) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) return null;

      // Create destination directory if needed
      final destDir = Directory(destinationPath).parent;
      if (!await destDir.exists()) {
        await destDir.create(recursive: true);
      }

      // Move the file
      final movedFile = await sourceFile.rename(destinationPath);
      return movedFile.path;
    } catch (e) {
      // rename() may fail across filesystems; fall back to copy + delete
      try {
        final sourceFile = File(sourcePath);
        await sourceFile.copy(destinationPath);
        await sourceFile.delete();
        return destinationPath;
      } catch (_) {
        return null;
      }
    }
  }

  /// Renames a file while keeping it in the same directory.
  Future<String?> renameFile(String filePath, String newFileName) async {
    try {
      final file = File(filePath);
      final dir = file.parent.path;
      final newPath = '$dir${Platform.pathSeparator}$newFileName';
      final renamed = await file.rename(newPath);
      return renamed.path;
    } catch (e) {
      return null;
    }
  }

  /// Generates a clean file name from metadata.
  String generateFileName({
    int? trackNumber,
    required String title,
    required String extension,
  }) {
    final sanitized = _sanitizeFileName(title);
    if (trackNumber != null) {
      final padded = trackNumber.toString().padLeft(2, '0');
      return '$padded - $sanitized.$extension';
    }
    return '$sanitized.$extension';
  }

  /// Generates a folder path from metadata.
  String generateFolderPath({
    required String baseDir,
    required String artist,
    String? album,
  }) {
    final sanitizedArtist = _sanitizeFileName(artist);
    if (album != null) {
      final sanitizedAlbum = _sanitizeFileName(album);
      return '$baseDir${Platform.pathSeparator}$sanitizedArtist${Platform.pathSeparator}$sanitizedAlbum';
    }
    return '$baseDir${Platform.pathSeparator}$sanitizedArtist';
  }

  /// Removes characters that are invalid in file/directory names.
  String _sanitizeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
