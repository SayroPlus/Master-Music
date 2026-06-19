import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_theme.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/folder_picker/folder_picker_screen.dart';
import 'screens/main_shell/main_shell.dart';
import 'screens/library/library_screen.dart';
import 'screens/organize/organize_screen.dart';
import 'screens/stats/stats_screen.dart';
import 'screens/player/player_screen.dart';
import 'screens/settings/settings_screen.dart';

/// Route names used throughout the app.
class AppRoutes {
  AppRoutes._();
  static const String onboarding = '/onboarding';
  static const String folderPicker = '/folder-picker';
  static const String main = '/main';
  static const String library = '/library';
  static const String organize = '/organize';
  static const String stats = '/stats';
  static const String player = '/player';
  static const String settings = '/settings';
}

/// Root widget for the Music Organizer app.
class MusicOrganizerApp extends ConsumerWidget {
  /// Whether to show the onboarding flow on launch.
  final bool showOnboarding;

  /// Whether folders have been saved previously (skip folder picker).
  final bool hasSavedFolders;

  const MusicOrganizerApp({
    super.key,
    required this.showOnboarding,
    this.hasSavedFolders = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Determine the initial route:
    // 1. First launch → onboarding
    // 2. Onboarding done, no folders saved → folder picker
    // 3. Onboarding done, folders saved → main shell
    final String startRoute;
    if (showOnboarding) {
      startRoute = AppRoutes.onboarding;
    } else if (hasSavedFolders) {
      startRoute = AppRoutes.main;
    } else {
      startRoute = AppRoutes.folderPicker;
    }

    return MaterialApp(
      title: 'Music Organizer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: startRoute,
      routes: {
        AppRoutes.onboarding: (_) => const OnboardingScreen(),
        AppRoutes.folderPicker: (_) => const FolderPickerScreen(),
        AppRoutes.main: (_) => MainShell(loadedFromCache: hasSavedFolders),
        AppRoutes.library: (_) => const LibraryScreen(),
        AppRoutes.organize: (_) => const OrganizeScreen(),
        AppRoutes.stats: (_) => const StatsScreen(),
        AppRoutes.player: (_) => const PlayerScreen(),
        AppRoutes.settings: (_) => const SettingsScreen(),
      },
    );
  }
}
