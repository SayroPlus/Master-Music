# 🎶 Music Master App — Smart Local Music Library Manager

A feature-rich Flutter (Android) application that brings AI-powered intelligence to managing your local music collection. Music Organizer scans your device for audio files, identifies songs using acoustic fingerprinting and online databases, fixes missing metadata with AI, and organizes your library into clean folder structures — all offline-first and privacy-respecting.

## ✨ Key Features

- **🔍 Smart File Scanner** — Recursively scans device storage for audio files (MP3, FLAC, AAC, WAV, M4A, OGG, OPUS, WMA) with intelligent exclusion of system folders (WhatsApp, Telegram, recordings, etc.)
- **🤖 AI-Powered Metadata Fixing** — Uses Groq API (Llama 3.3 70B) to extract and suggest accurate metadata (title, artist, album, genre, year) from file names and existing tags
- **🎵 AcoustID Audio Fingerprinting** — Identifies songs by their actual audio content using Chromaprint fingerprinting, independent of file names or tags
- **📀 MusicBrainz Integration** — Looks up rich metadata and album art from the MusicBrainz open music database with confidence scoring
- **📁 Smart Folder Organization** — Automatically reorganizes files into structured directories (Artist/Album/Song, Genre/Artist/Song, or Flat) with real file system operations
- **🔄 Duplicate Detection & Resolution** — Multi-pass duplicate finder using exact hash matching, acoustic fingerprint comparison, and metadata similarity analysis with smart quality-based keep recommendations
- **✏️ Metadata Editor** — Per-song metadata editor with ID3 tag writing back to actual audio files via native Android channels
- **🎧 Built-in Music Player** — Full-featured audio player with background playback support via `audio_service` and `just_audio`
- **📊 Library Statistics** — Visual analytics dashboard with charts (powered by `fl_chart`) showing library composition, format distribution, and organization health
- **💾 Backup & Restore** — Snapshot-based metadata backup system with up to 3 rolling backups and granular single-song restore capability
- **🎨 Modern UI** — Material 3 dark theme with Google Fonts, shimmer loading effects, swipeable song tiles, and smooth animations

## 🏗️ Architecture

- **Framework:** Flutter (Dart) with Android native (Kotlin) for platform channels
- **State Management:** Riverpod (flutter_riverpod)
- **Database:** SQLite (sqflite) for local library persistence
- **AI Backend:** Groq API (Llama 3.3 70B Versatile)
- **Music Identification:** AcoustID API + Chromaprint + MusicBrainz API
- **Audio Playback:** just_audio + audio_service (background playback)
- **Native Channels:** Kotlin MethodChannels for ID3 tag writing, file hashing, and audio fingerprint generation

## 📱 Screenshots & UI

*(Add screenshots here)*

## 🛠️ Tech Stack

| Category | Technology |
|----------|-----------|
| Frontend | Flutter 3.x, Dart |
| Native | Kotlin (Android) |
| State | Riverpod |
| Database | SQLite (sqflite) |
| AI/LLM | Groq API (Llama 3.3 70B) |
| Audio ID | AcoustID, Chromaprint, MusicBrainz |
| Playback | just_audio, audio_service |
| Charts | fl_chart |
| Networking | Dio, http |
| UI | Material 3, Google Fonts, Shimmer |

## 🚀 Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/obaidrana4303/Music_Master_App.git
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run the app:
   ```bash
   flutter run
   ```

Note: Some features require API keys (Groq, AcoustID) which can be configured in the app settings.
