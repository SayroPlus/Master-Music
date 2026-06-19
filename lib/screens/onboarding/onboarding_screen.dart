import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/permissions/permission_handler.dart';
import '../../main.dart';
import '../../app.dart';

/// Onboarding screen shown on first launch.
///
/// Contains 3 swipeable pages:
///   1. Welcome — app icon, title, subtitle
///   2. Feature highlights — 4 icons with labels
///   3. Permission request — explanation + grant button
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isRequestingPermission = false;

  static const int _totalPages = 3;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ── Navigation helpers ──────────────────────────────────────────────────

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _skipToPermission() {
    _pageController.animateToPage(
      _totalPages - 1,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  // ── Permission flow ─────────────────────────────────────────────────────

  Future<void> _requestPermissionAndProceed() async {
    setState(() => _isRequestingPermission = true);

    try {
      // Step 1: Request base audio/storage permission
      final baseGranted = await AppPermissionHandler.checkAndRequestPermissions();
      if (!mounted) return;

      if (!baseGranted) {
        // Check if permanently denied
        final permanentlyDenied =
            await AppPermissionHandler.isPermissionPermanentlyDenied();
        if (!mounted) return;

        if (permanentlyDenied) {
          _showPermanentlyDeniedDialog();
        } else {
          _showDeniedDialog();
        }
        setState(() => _isRequestingPermission = false);
        return;
      }

      // Step 2: Request MANAGE_EXTERNAL_STORAGE
      final manageGranted = await AppPermissionHandler.requestManageStorage();
      if (!mounted) return;

      if (!manageGranted) {
        // Show explanation but still allow proceeding with limited access
        _showManageStorageDialog();
        setState(() => _isRequestingPermission = false);
        return;
      }

      // All permissions granted — complete onboarding
      await _completeOnboarding();
    } catch (e) {
      if (mounted) {
        setState(() => _isRequestingPermission = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Permission error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kOnboardingCompleteKey, true);

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.folderPicker);
  }

  // ── Dialogs ─────────────────────────────────────────────────────────────

  void _showDeniedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 28),
            SizedBox(width: 12),
            Text('Permission Required'),
          ],
        ),
        content: const Text(
          'Music Organizer needs storage access to scan and organize your '
          'music files. Without this permission, the app cannot function.\n\n'
          'Please grant the permission when prompted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _requestPermissionAndProceed();
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  void _showPermanentlyDeniedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.block_rounded, color: AppColors.error, size: 28),
            SizedBox(width: 12),
            Text('Permission Blocked'),
          ],
        ),
        content: const Text(
          'Storage permission was permanently denied. You need to enable it '
          'manually in the app settings.\n\n'
          'Go to Settings → Permissions → Storage → Allow',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              AppPermissionHandler.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showManageStorageDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 28),
            SizedBox(width: 12),
            Expanded(child: Text('Full Access Needed')),
          ],
        ),
        content: const Text(
          'For the best experience, Music Organizer needs full file access '
          'to move and rename your music files across folders.\n\n'
          'You can use the app with limited access, but some features like '
          'file organization and backup will be unavailable.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _completeOnboarding();
            },
            child: const Text('Continue Anyway'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _requestPermissionAndProceed();
            },
            child: const Text('Grant Access'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Skip button (pages 1 & 2 only) ──────────────────────────
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: AnimatedOpacity(
                  opacity: _currentPage < _totalPages - 1 ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: TextButton(
                    onPressed: _currentPage < _totalPages - 1
                        ? _skipToPermission
                        : null,
                    child: const Text('Skip'),
                  ),
                ),
              ),
            ),

            // ── Page content ────────────────────────────────────────────
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: [
                  _buildWelcomePage(context),
                  _buildFeaturesPage(context),
                  _buildPermissionPage(context),
                ],
              ),
            ),

            // ── Dot indicators ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_totalPages, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? AppColors.primary
                          : AppColors.textHint.withAlpha(80),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),

            // ── Bottom action button ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(left: 32, right: 32, bottom: 48),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: _currentPage == _totalPages - 1
                    ? ElevatedButton.icon(
                        onPressed: _isRequestingPermission
                            ? null
                            : _requestPermissionAndProceed,
                        icon: _isRequestingPermission
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.lock_open_rounded),
                        label: Text(
                          _isRequestingPermission
                              ? 'Requesting...'
                              : 'Grant Storage Access',
                        ),
                      )
                    : ElevatedButton(
                        onPressed: _nextPage,
                        child: const Text('Next'),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Page 1: Welcome
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildWelcomePage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // App icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withAlpha(80),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.library_music_rounded,
              size: 56,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 48),
          Text(
            'Music Organizer',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 16),
          Text(
            'Clean your music library automatically',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Page 2: Feature highlights
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildFeaturesPage(BuildContext context) {
    const features = [
      _Feature(Icons.folder_copy_rounded, 'Organize', 'Auto-sort into folders'),
      _Feature(Icons.fingerprint_rounded, 'Identify', 'Recognize any song'),
      _Feature(Icons.edit_note_rounded, 'Fix Metadata', 'Correct tags & art'),
      _Feature(Icons.bar_chart_rounded, 'Stats', 'Library insights'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Everything you need',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'Powerful tools to manage your music',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 48),
          // Feature grid — 2x2
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.1,
            children: features.map((f) => _buildFeatureCard(context, f)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context, _Feature feature) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(25),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(feature.icon, color: AppColors.primary, size: 26),
          ),
          const SizedBox(height: 12),
          Text(
            feature.label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            feature.description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Page 3: Permission request
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPermissionPage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.warning.withAlpha(20),
              borderRadius: BorderRadius.circular(25),
            ),
            child: const Icon(
              Icons.folder_open_rounded,
              size: 48,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'Storage Access Required',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Text(
            'Music Organizer needs full access to your device storage to:',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          // Reasons list
          _buildReasonItem(
            Icons.search_rounded,
            'Scan all music folders',
          ),
          const SizedBox(height: 12),
          _buildReasonItem(
            Icons.drive_file_move_rounded,
            'Move & rename files for organization',
          ),
          const SizedBox(height: 12),
          _buildReasonItem(
            Icons.backup_rounded,
            'Create backups before changes',
          ),
          const SizedBox(height: 12),
          _buildReasonItem(
            Icons.audio_file_rounded,
            'Read & fix metadata tags',
          ),
          const SizedBox(height: 32),
          // Privacy note
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_rounded,
                    color: AppColors.success, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your files never leave your device. Everything runs locally.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonItem(IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                ),
          ),
        ),
      ],
    );
  }
}

/// Data class for a feature card on page 2.
class _Feature {
  final IconData icon;
  final String label;
  final String description;

  const _Feature(this.icon, this.label, this.description);
}
