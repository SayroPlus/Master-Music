/// Centralized string constants for the Music Organizer app.
class AppStrings {
  AppStrings._();

  // ── App ───────────────────────────────────────────────────────────────────
  static const String appName = 'Music Organizer';
  static const String appVersion = '1.0.0';

  // ── Onboarding ────────────────────────────────────────────────────────────
  static const String onboardingTitle = 'Welcome to Music Organizer';
  static const String onboardingSubtitle =
      'Organize your music library with AI-powered intelligence';
  static const String onboardingPermissionTitle = 'Storage Access Required';
  static const String onboardingPermissionBody =
      'Music Organizer needs access to your storage to scan and organize your music files.';
  static const String onboardingGetStarted = 'Get Started';
  static const String onboardingGrantAccess = 'Grant Storage Access';

  // ── Navigation ────────────────────────────────────────────────────────────
  static const String navLibrary = 'Library';
  static const String navOrganize = 'Organize';
  static const String navStats = 'Stats';
  static const String navPlayer = 'Player';

  // ── Library ───────────────────────────────────────────────────────────────
  static const String libraryTitle = 'Your Library';
  static const String libraryEmpty = 'No songs found';
  static const String libraryScanning = 'Scanning your music...';
  static const String libraryScanComplete = 'Scan complete!';

  // ── Organize ──────────────────────────────────────────────────────────────
  static const String organizeTitle = 'Smart Organize';
  static const String organizeDescription =
      'AI-powered music file organization using metadata analysis.';
  static const String organizeScan = 'Scan & Analyze';
  static const String organizeApply = 'Apply Changes';
  static const String organizePreview = 'Preview';

  // ── Stats ─────────────────────────────────────────────────────────────────
  static const String statsTitle = 'Dashboard';
  static const String statsTotalSongs = 'Total Songs';
  static const String statsOrganized = 'Organized';
  static const String statsDuplicates = 'Duplicates';
  static const String statsStorage = 'Storage Used';

  // ── Player ────────────────────────────────────────────────────────────────
  static const String playerTitle = 'Now Playing';
  static const String playerNoSong = 'No song selected';

  // ── Folder Picker ─────────────────────────────────────────────────────────
  static const String folderPickerTitle = 'Select Music Folders';
  static const String folderPickerSubtitle =
      'Choose the folders containing your music files.';
  static const String folderPickerAdd = 'Add Folder';
  static const String folderPickerContinue = 'Continue';

  // ── Errors ────────────────────────────────────────────────────────────────
  static const String errorGeneric = 'Something went wrong. Please try again.';
  static const String errorNetwork = 'Network error. Check your connection.';
  static const String errorPermission = 'Storage permission is required.';
  static const String errorNoFiles = 'No audio files found in selected folders.';

  // ── API ───────────────────────────────────────────────────────────────────
  static const String musicBrainzBaseUrl = 'https://musicbrainz.org/ws/2';
  static const String acoustIdBaseUrl = 'https://api.acoustid.org/v2';
  static const String groqBaseUrl = 'https://api.groq.com/openai/v1';
  static const String groqModel = 'llama-3.3-70b-versatile';
}
