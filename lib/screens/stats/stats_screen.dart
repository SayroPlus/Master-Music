import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/stats_provider.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(statsProvider);

    if (state.isLoading && state.totalSongs == 0) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library Stats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Stats',
            onPressed: () {
              ref.read(statsProvider.notifier).refreshStats();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Settings',
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(statsProvider.notifier).refreshStats(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopSummaryGrid(context, state),
              const SizedBox(height: 24),
              _buildMetadataCompletenessCard(context, state),
              const SizedBox(height: 24),
              _buildIdentificationStatusCard(context, state),
              const SizedBox(height: 24),
              _buildGenreDistributionCard(context, state),
              const SizedBox(height: 24),
              _buildDuplicatesCard(context, state),
              const SizedBox(height: 24),
              _buildRecentlyFixedCard(context, state),
              const SizedBox(height: 24),
              _buildProblemsCard(context, state),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top Summary Grid ─────────────────────────────────────────────────────

  Widget _buildTopSummaryGrid(BuildContext context, StatsState state) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(context, 'Total Songs', state.totalSongs.toString(), Icons.music_note, Colors.purple),
        _buildStatCard(context, 'Total Artists', state.totalArtists.toString(), Icons.person, Colors.blue),
        _buildStatCard(context, 'Total Albums', state.totalAlbums.toString(), Icons.album, Colors.teal),
        _buildStatCard(context, 'Storage Used', state.formattedStorage, Icons.storage, Colors.orange),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 0,
      color: color.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ── Metadata Completeness Card ───────────────────────────────────────────

  Widget _buildMetadataCompletenessCard(BuildContext context, StatsState state) {
    final theme = Theme.of(context);
    final total = state.totalSongs == 0 ? 1 : state.totalSongs; // Prevent div by 0

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Metadata Completeness', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 120,
                  width: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: state.completenessPercent / 100,
                        strokeWidth: 12,
                        backgroundColor: theme.dividerColor,
                        color: AppColors.primary,
                      ),
                      Text(
                        '${state.completenessPercent.toStringAsFixed(0)}%',
                        style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildCompletionRow('Songs with title', state.withTitle, total),
            _buildCompletionRow('Songs with artist', state.withArtist, total),
            _buildCompletionRow('Songs with album', state.withAlbum, total),
            _buildCompletionRow('Songs with cover art', state.withCoverArt, total),
            _buildCompletionRow('Songs with genre', state.withGenre, total),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionRow(String label, int value, int total) {
    final percent = ((value / total) * 100).toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text('$value ($percent%)', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ── Identification Status Card ───────────────────────────────────────────

  Widget _buildIdentificationStatusCard(BuildContext context, StatsState state) {
    final theme = Theme.of(context);
    final total = state.totalSongs == 0 ? 1 : state.totalSongs;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Identification Status', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.center,
                  maxY: total.toDouble(),
                  minY: 0,
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  barGroups: [
                    BarChartGroupData(
                      x: 0,
                      barRods: [
                        BarChartRodData(
                          toY: total.toDouble(),
                          width: MediaQuery.of(context).size.width - 72,
                          borderRadius: BorderRadius.circular(8),
                          rodStackItems: [
                            BarChartRodStackItem(0, state.highConfidence.toDouble(), Colors.green),
                            BarChartRodStackItem(state.highConfidence.toDouble(), (state.highConfidence + state.mediumConfidence).toDouble(), Colors.orange),
                            BarChartRodStackItem((state.highConfidence + state.mediumConfidence).toDouble(), (state.highConfidence + state.mediumConfidence + state.lowConfidence).toDouble(), AppColors.error),
                            BarChartRodStackItem((state.highConfidence + state.mediumConfidence + state.lowConfidence).toDouble(), total.toDouble(), Colors.grey),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildLegendRow('High Confidence', state.highConfidence, total, Colors.green),
            _buildLegendRow('Medium Confidence', state.mediumConfidence, total, Colors.orange),
            _buildLegendRow('Low Confidence', state.lowConfidence, total, AppColors.error),
            _buildLegendRow('Unidentified', state.unidentified, total, Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendRow(String label, int value, int total, Color color) {
    final percent = ((value / total) * 100).toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text('$value ($percent%)', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ── Genre Distribution Card ──────────────────────────────────────────────

  Widget _buildGenreDistributionCard(BuildContext context, StatsState state) {
    final theme = Theme.of(context);
    final topGenres = state.genreDistribution.entries.take(5).toList();
    
    // Fallback if empty
    if (topGenres.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Top Genres', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              const Center(child: Text('Not enough genre data')),
            ],
          ),
        ),
      );
    }

    final colors = [
      AppColors.primary,
      Colors.pink,
      Colors.amber,
      Colors.cyan,
      Colors.purple,
    ];

    List<PieChartSectionData> sections = [];
    for (int i = 0; i < topGenres.length; i++) {
      sections.add(
        PieChartSectionData(
          value: topGenres[i].value.toDouble(),
          color: colors[i % colors.length],
          title: '', // Hide inline labels to keep it clean
          radius: 50,
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Top Genres', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Column(
              children: List.generate(topGenres.length, (i) {
                return _buildLegendRow(topGenres[i].key, topGenres[i].value, state.totalSongs, colors[i % colors.length]);
              }),
            ),
          ],
        ),
      ),
    );
  }

  // ── Duplicates Card ──────────────────────────────────────────────────────

  Widget _buildDuplicatesCard(BuildContext context, StatsState state) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.copy_all, color: Colors.purple),
                const SizedBox(width: 8),
                Text('Duplicates', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Text('${state.duplicateGroups} duplicate groups found', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Storage can be freed by resolving these.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodySmall?.color)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  // TODO: Navigate to Organize tab -> Open Duplicates
                },
                child: const Text('Resolve Duplicates'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Recently Fixed Card ──────────────────────────────────────────────────

  Widget _buildRecentlyFixedCard(BuildContext context, StatsState state) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recently Fixed', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (state.recentlyFixedSongs.isEmpty)
              const Text('No songs have been modified yet.')
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.recentlyFixedSongs.length > 10 ? 10 : state.recentlyFixedSongs.length,
                separatorBuilder: (ctx, i) => const Divider(height: 16),
                itemBuilder: (context, index) {
                  final song = state.recentlyFixedSongs[index];
                  // Extract time correctly 
                  final timeLabel = '${song.lastModified.hour.toString().padLeft(2, '0')}:${song.lastModified.minute.toString().padLeft(2, '0')}';
                  return Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(song.title ?? song.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(song.artist ?? 'Unknown Artist', style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                      Text(timeLabel, style: theme.textTheme.bodySmall),
                    ],
                  );
                },
              ),
            if (state.recentlyFixedSongs.isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {},
                  child: const Text('View All'),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  // ── Problems Requiring Attention Card ────────────────────────────────────

  Widget _buildProblemsCard(BuildContext context, StatsState state) {
    final theme = Theme.of(context);
    final missingArtist = state.totalSongs - state.withArtist;
    final missingAlbum = state.totalSongs - state.withAlbum;
    final missingCover = state.totalSongs - state.withCoverArt;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.error),
                const SizedBox(width: 8),
                Text('Needs Attention', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            _buildProblemRow(missingArtist, 'songs missing artist'),
            _buildProblemRow(missingAlbum, 'songs missing album'),
            _buildProblemRow(missingCover, 'songs have no cover art'),
            _buildProblemRow(state.unidentified, 'songs unidentified'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Navigate to Organize tab -> Fix Metadata
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Fix All Problems'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProblemRow(int count, String label) {
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 8, color: AppColors.error),
          const SizedBox(width: 8),
          Text('$count', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
    );
  }
}
