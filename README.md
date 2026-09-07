# Music Player

A local audio player for Android, built with Flutter. It plays the audio files
already on your device — no streaming, no account, nothing leaves the phone.

Its main idea is that **organizing your music never touches your files**. You
group tracks into folders inside the app; those groupings live in a local
database keyed by file path, so removing a track from a folder only removes the
link — the file itself is untouched.

---

## Features

### Library
- Scans on-device audio via MediaStore (m4a, mp3, wav, flac and others)
- Sort by title, artist, album, date added or duration, ascending or descending
- Pull down to rescan
- Album art with a fallback placeholder

### Folders
- Create, rename and delete folders
- Long-press any track to multi-select, then batch-add to a folder
- Drag to reorder tracks inside a folder (only in "Custom order" mode)
- Per-folder sort: custom / title / artist / album / date added / duration
- Removing a track from a folder unlinks it only — the file and the main
  library entry are untouched
- **Favorites** is a built-in folder that can't be renamed or deleted; every
  track row has a heart toggle

### Search & filter
- Global search across title, artist and album — multi-word queries match
  across fields in any order ("beatles yesterday" works)
- Per-folder search inside any folder
- Filters, combinable: format · duration range · in-a-folder vs unfiled ·
  recently added / recently played

### Playback
- Play, pause, previous, next, seek
- Shuffle, and repeat off / all / one
- Queue view: reorder by dragging, remove items, jump to any track
- Mini player docked above the navigation bar, expanding to a full player
- Background playback with notification and lock-screen controls

### Appearance
- Light and dark themes, following the system or set manually

---

## Tech stack

| Purpose | Package |
|---|---|
| Audio metadata / MediaStore queries | `on_audio_query` |
| Playback engine | `just_audio` |
| Background playback, notification, lock screen | `audio_service` |
| Local database | `hive` / `hive_flutter` |
| State management | `flutter_riverpod` |
| Runtime permissions | `permission_handler` |

Android only — iOS is out of scope.

---

## Architecture

Four layers, each depending only on the ones above it:

```
features/   UI + per-feature Riverpod providers
domain/     app-level models (Track, filter state, sort modes)
data/       Hive models + repositories
services/   audio playback handler, permissions
```

### Key decision: the database stores relationships, never metadata

Hive only ever holds **links and bookkeeping**:

| Box | Holds |
|---|---|
| `folders` | folder id, name, created date, sort mode, system flag |
| `folder_track_links` | folder id ↔ track **file path**, added date, manual order |
| `known_tracks` | files seen in previous scans, for new/deleted diffing |
| `play_history` | append-only play log |
| `settings` | theme mode, library sort preference |

Titles, artists, artwork and durations are always re-read live from
`on_audio_query` at render time. Nothing is duplicated into the database, so a
rescan can never leave stale metadata behind, and your folders survive any
change to the underlying files.

Tracks are keyed by **file path**, not by MediaStore id, because MediaStore ids
can be reassigned when the system re-indexes.

Favorites is implemented as a folder with `isSystem: true` rather than a
separate table, so it reuses the same linking code as every other folder.

### Project layout

```
lib/
  main.dart                     bootstraps Hive + AudioService, runs the app
  app.dart                      MaterialApp, permission gate, tab shell, mini player
  core/                         theme, shared notifiers, formatting/matching helpers
  data/
    hive/                       box setup + @HiveType models
    repositories/               audio library, folders, history, settings
  domain/                       Track, FolderSortMode, LibraryFilterState
  features/
    library/                    scan, sort, multi-select
    folders/                    CRUD, folder detail, add-to-folder sheet
    search/                     search + filter panel
    player/                     player controller, mini player, now playing, queue
    settings/                   theme switch
  services/
    audio/                      AudioPlayerHandler (just_audio + audio_service)
    permissions/                permission service + provider
  widgets/                      shared: artwork, empty state, permission gate
```

---

## Running it

Requires the Flutter SDK and an Android device or emulator.

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generates Hive adapters
flutter run
```

Regenerate adapters (`*.g.dart`) any time you change a `@HiveType` model.

### Building an APK

```bash
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk
```

To install straight onto a connected phone: `flutter install --release`.

### Checks

```bash
flutter analyze
flutter test
```

---

## Android configuration notes

A few non-obvious things live in `android/`, each there for a specific reason:

- **`AndroidManifest.xml`** declares `READ_MEDIA_AUDIO` (Android 13+) with
  `READ_EXTERNAL_STORAGE` capped at API 32 for older devices, plus the
  foreground-service and notification permissions playback needs. It also
  registers `audio_service`'s `AudioService` and `MediaButtonReceiver`.
- **`MainActivity`** extends `AudioServiceActivity` instead of `FlutterActivity`
  so media buttons reach the handler.
- **`build.gradle.kts` (root)** patches `on_audio_query_android`, which predates
  current Android Gradle Plugin requirements: it backfills the missing
  `namespace`, pins Java/Kotlin to JVM 17 so the two compilers agree, and raises
  its `compileSdk` through the variant API's `finalizeDsl` (a plain
  `afterEvaluate` is too late — AGP has already locked the value).
- **`gradle.properties`** disables Kotlin incremental compilation, which crashes
  on Windows when the project and the pub cache sit on different drives.
- **`permission_handler` is pinned to 11.4.0.** Newer versions require
  `compileSdk 37`, which current SDK installs expose only as `android-37.x`
  folders that AGP cannot resolve as a plain `compileSdk = 37`.

---

## Status

Built and verified:

1. Scaffolding, permissions, tab shell, theming
2. Library scanning and sorting
3. Folders, multi-select, reordering, Favorites
4. Search and filters
5. Playback, queue, mini player, background audio

Still to come:

6. Recently played / most played views
7. Visual polish pass
8. Settings: cleaning up records for files that no longer exist, about/version

### Known limitations

- The **"recently played" filter** returns nothing until you've actually played
  something — the history log starts empty.
- The release APK is signed with Flutter's **debug keys** and uses the
  placeholder package name `com.example.music_player`. Both need changing
  before distributing the app anywhere.
- Notification artwork isn't shown yet; the notification uses the app icon.
