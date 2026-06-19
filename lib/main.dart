import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app.dart';
import 'providers/folder_provider.dart';
import 'services/audio_handler.dart'; // Audio Service

/// Key used to store onboarding completion status in SharedPreferences.
const String kOnboardingCompleteKey = 'onboarding_complete';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize background audio playback service
  try {
    debugPrint('Initializing audio service...');
    await initAudioService();
    debugPrint('Audio service initialized successfully');
  } catch (e, stack) {
    debugPrint('Audio service init failed: $e');
    debugPrint(stack.toString());
  }

  // Request permissions natively on startup
  try {
    if (Platform.isAndroid) {
      await [
        Permission.storage,
        Permission.notification,
      ].request();
    }
  } catch (e) {
    debugPrint('Permission request failed: $e');
  }

  // Force dark system UI overlays
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Lock to portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Check startup state
  final prefs = await SharedPreferences.getInstance();
  final onboardingComplete = prefs.getBool(kOnboardingCompleteKey) ?? false;

  // If onboarding is done, check if folders have been saved
  bool hasSavedFolders = false;
  if (onboardingComplete) {
    final savedPaths = await FolderNotifier.loadSelectedPaths();
    hasSavedFolders = savedPaths.isNotEmpty;
  }

  runApp(
    ProviderScope(
      child: MusicOrganizerApp(
        showOnboarding: !onboardingComplete,
        hasSavedFolders: hasSavedFolders,
      ),
    ),
  );
}
