import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/exceptions/groq_exception.dart';
import '../../models/song_model.dart';
import '../../providers/library_provider.dart';
import '../../services/groq_service.dart';
import '../../services/id3_writer_service.dart';

class MetadataEditorScreen extends ConsumerStatefulWidget {
  final SongModel song;

  const MetadataEditorScreen({super.key, required this.song});

  @override
  ConsumerState<MetadataEditorScreen> createState() =>
      _MetadataEditorScreenState();
}

class _MetadataEditorScreenState extends ConsumerState<MetadataEditorScreen> {
  final _titleController = TextEditingController();
  final _artistController = TextEditingController();
  final _albumController = TextEditingController();
  final _yearController = TextEditingController();
  final _genreController = TextEditingController();

  final _groqService = GroqService();
  final _id3Writer = Id3WriterService();

  bool _isSaving = false;
  bool _isSuggesting = false;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.song.title ?? '';
    _artistController.text = widget.song.artist ?? '';
    _albumController.text = widget.song.album ?? '';
    _yearController.text = widget.song.year ?? '';
    _genreController.text = widget.song.genre ?? '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _albumController.dispose();
    _yearController.dispose();
    _genreController.dispose();
    super.dispose();
  }

  Future<void> _suggestMetadata() async {
    setState(() => _isSuggesting = true);

    try {
      final suggestion = await _groqService.suggestMetadata(widget.song);
      if (!mounted) return;

      if (suggestion != null) {
        setState(() {
          if (suggestion['title'] != null)
            _titleController.text = suggestion['title']!;
          if (suggestion['artist'] != null)
            _artistController.text = suggestion['artist']!;
          if (suggestion['album'] != null)
            _albumController.text = suggestion['album']!;
          if (suggestion['year'] != null)
            _yearController.text = suggestion['year']!;
          if (suggestion['genre'] != null)
            _genreController.text = suggestion['genre']!;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Applied AI suggestions!')),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No suggestions found.')));
      }
    } on GroqNotConfiguredException {
      _showMissingApiDialog();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSuggesting = false);
    }
  }

  Future<void> _saveMetadata() async {
    setState(() => _isSaving = true);

    try {
      final success = await _id3Writer.writeMetadata(
        filePath: widget.song.filePath,
        title: _titleController.text,
        artist: _artistController.text,
        album: _albumController.text,
        year: _yearController.text,
        genre: _genreController.text,
      );

      if (success && mounted) {
        // 1. Update the database record to match the new file metadata
        final updatedSong = widget.song.copyWith(
          title: _titleController.text,
          artist: _artistController.text,
          album: _albumController.text,
          year: _yearController.text,
          genre: _genreController.text,
          isModified: true,
          hasBeenProcessed: true,
          lastModified: DateTime.now(),
        );
        
        await ref.read(libraryProvider.notifier).updateSongMetadata(updatedSong);
        
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tags successfully saved and synced!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMissingApiDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('API Key Missing'),
        content: const Text(
          'To use AI suggestions, you must configure a Groq API Key in the settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Metadata'),
        actions: [
          TextButton.icon(
            onPressed: _isSuggesting ? null : _suggestMetadata,
            icon: _isSuggesting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: const Text('AI Suggest'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _artistController,
              decoration: const InputDecoration(
                labelText: 'Artist',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _albumController,
              decoration: const InputDecoration(
                labelText: 'Album',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _yearController,
              decoration: const InputDecoration(
                labelText: 'Year',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _genreController,
              decoration: const InputDecoration(
                labelText: 'Genre',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _isSaving ? null : _saveMetadata,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save to File'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
