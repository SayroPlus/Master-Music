import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';

/// Shared bottom navigation bar used by [MainShell].
///
/// This widget is purely presentational — it receives the current index
/// and an [onTap] callback from its parent rather than handling navigation
/// itself. This enables the IndexedStack pattern in MainShell to preserve
/// screen state across tab switches.
class BottomNav extends StatelessWidget {
  /// The currently active tab index (0–3).
  final int currentIndex;

  /// Callback invoked when a tab is tapped.
  final ValueChanged<int> onTap;

  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
            color: AppColors.divider,
            width: 0.5,
          ),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.music_note_rounded),
            activeIcon: Icon(Icons.music_note_rounded),
            label: AppStrings.navLibrary,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_fix_high_rounded),
            activeIcon: Icon(Icons.auto_fix_high_rounded),
            label: AppStrings.navOrganize,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_rounded),
            activeIcon: Icon(Icons.bar_chart_rounded),
            label: AppStrings.navStats,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.play_circle_rounded),
            activeIcon: Icon(Icons.play_circle_filled_rounded),
            label: AppStrings.navPlayer,
          ),
        ],
      ),
    );
  }
}
