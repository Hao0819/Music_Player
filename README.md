# Music Player

A local audio player for Android, built with Flutter. It plays the audio files
already on your device — no streaming service, no account, no cloud library.

One optional feature breaks the "purely local" rule: a built-in **downloader**
that pulls audio off a link using a copy of yt-dlp embedded in the APK. It is
the only part of the app that touches the network, it only ever downloads, and
nothing about your library is uploaded anywhere. See
[Downloading](#downloading) for what it does and the conditions attached.

Its main idea is that **organizing your music never touches your files**. You
group tracks into folders inside the app; those groupings live in a local
database keyed by file path, so removing a track from a folder only removes the
link — the file itself is untouched.

---

## Features

### Library
- Scans on-device audio via MediaStore (m4a, mp3, wav, flac and others),
  including folders like `Download/MusicDownload` and secondary volumes
- Search box and the same filter panel the Search tab uses
- One-tap chips: **All / In a folder / Not in a folder**
- Songs filed into folders show the folder names on their row (Favorites is
  left out, since the heart already shows it)
- Sort by title, artist, album, date added or duration, ascending or descending
- Total song count above the list
- A–Z index down the right edge — tap or drag a letter to jump straight to
  that section instead of scrolling a long library
- Pull down to rescan
- Album art, with a clearly-marked "no cover" placeholder when a track has none
- WhatsApp voice notes and audio are filtered out

### Folders
- Create, rename and delete folders
- Long-press any track to multi-select, then batch-add to a folder
- Drag tracks by their ☰ handle to reorder them inside a folder (only in
  "Custom order" mode). The handle drags; long-press on the row still selects
- Per-folder sort: custom / title / artist / album / date added / duration
- Removing a track from a folder unlinks it only — the file and the main
  library entry are untouched
- **Favorites** is a built-in folder that can't be renamed or deleted; every
  track row has a heart toggle
- Entries whose file the current scan can't find are **counted, not hidden**:
  the folder list shows "N not found" and the folder itself says so above the
  tracks. They stay in the folder, so they come back if the files do

### Auto-collections
Pinned above your own folders in the Folders tab, built from the play log
rather than created by hand:
- **Recently played** — most recent first, one entry per track
- **Most played** — ordered by play count, with the count shown on each row
- Both support tap-to-play, the heart toggle, and long-press multi-select to
  file tracks into a folder
- "Clear history" empties the log without touching folders, favorites or files

### Search & filter
- Global search across title, artist and album — multi-word queries match
  across fields in any order ("beatles yesterday" works)
- Per-folder search inside any folder
- Filters, combinable: format · duration range · in-a-folder vs unfiled ·
  recently added / recently played
- The Library tab and the Search tab keep independent search text and
  filters, so changing one doesn't disturb the other

### Playback
- Play, pause, previous, next, seek
- Shuffle, and repeat all / one / off — **repeat all is the default**, so a
  folder loops back to its first song, and your choice is remembered
- Queue view: reorder by dragging, remove items, jump to any track
- Mini player docked above the navigation bar, expanding to a full player.
  It also appears inside folders, history and new-audio screens
- Next / previous start playback, so skipping from a paused or just-restored
  player plays the track you skipped to
- Play and Shuffle buttons at the top of every folder
- The row of the currently playing track is highlighted in every list
- Background playback with notification and lock-screen controls
- **Resumes where you left off**: reopening the app brings back the last queue,
  song and position, paused. Saved on every pause, every 5 seconds while
  playing, and whenever the app leaves the screen, so it survives the system
  killing the app

### New audio detection
- Each scan is diffed against a record of files already seen. New arrivals get
  a quiet **New audio** row at the top of the Folders tab — never a popup
- Open it to multi-select and file the new tracks into folders, or "Mark all
  seen" to dismiss
- Your existing library on first install is the baseline, not "new"

### Downloading
- **Search by name** in **Settings → Download audio**, then tap a result to
  download it. No copying links, no browser
- **Or paste a link** into the same box — one field, not two: text that parses
  as an http(s) URL is downloaded, anything else is searched. So when search
  doesn't surface what you want, a link copied from YouTube still works
- Results show thumbnail, channel and duration
- Downloads land in `Music/MusicPlayer/` as tagged audio, indexed by MediaStore
  so they show up in your library like any other track
- Choose **MP3 / M4A / Opus**; the video stream is never downloaded, only the
  best audio-only format
- Live progress, ETA and per-download cancel
- **Update yt-dlp** button — sites change how they serve media often enough to
  break extraction between app releases, so the extractor can be refreshed
  without shipping a new APK
- Download history can be hidden (the choice is remembered), cleared in one go,
  or removed row by row with a left swipe. Anything still downloading is never
  hidden or removable — cancel it first

### Appearance
- Light / dark / follow-system theme, on a blue Material colour scheme. The
  secondary tones are pinned to blue by hand, because even a blue seed leaves
  Material's "vibrant" variant with violet chips and navigation indicators
- Your own folders are a grid of gradient cards, each folder keeping its own
  colour from a hash of its name; folders open on a matching hero header with
  track count, total duration and Play / Shuffle
- The library has a Shuffle-all header, and the mini player is a rounded card
  floating above the navigation bar with a gradient play button
- The Now Playing scrubber is drawn as a waveform. Its shape comes from a hash
  of the track id, **not** from the audio — decoding every file for real
  amplitudes would be far too slow on a phone. It is stable per track, so a
  song always looks the same.

### Settings
- **Rescan device** on demand
- **Clean up missing files** — removes folder links and history entries left
  behind by audio that is no longer on the device, telling you exactly how many
  of each will go. Never touches files or your other folders
- **Folder backup** — writes your folders and the tracks in them to a JSON file
  under `Android/data/com.example.music_player/files/folder_backups`, where a
  file manager can see it. Restoring adds back only what's missing, so it never
  removes, renames or reorders anything and is safe to run twice. The same
  screen reports any saved data the app couldn't read at launch, and where the
  unreadable file was kept
- **Download audio** — see [Downloading](#downloading)
- App version and a note that your library stays on the device

---

## Installing

There is no prebuilt APK to download — you build it yourself. You need a
machine with the [Flutter SDK](https://docs.flutter.dev/get-started/install)
installed, and an Android phone running **Android 6.0 (API 23) or newer**.

```bash
git clone https://github.com/Hao0819/Music_Player.git
cd Music_Player
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build apk --release --split-per-abi
```

If that last step fails on Windows with `An Application Control policy has
blocked this file`, add `--no-tree-shake-icons` — see
[Building an APK](#building-an-apk) for why.

It writes one APK per architecture to `build/app/outputs/flutter-apk/`:

| File | For |
|---|---|
| `app-arm64-v8a-release.apk` | Any phone from roughly 2019 onward — pick this one |
| `app-armeabi-v7a-release.apk` | Older 32-bit devices |

Then either plug the phone in over USB with USB debugging enabled and run
`flutter install --release`, or copy the APK onto the phone and open it,
allowing "install from unknown sources" when prompted.

### After installing

- **Grant the audio permission** on first launch, or the library stays empty.
- **Update by installing the new APK over the old one.** Uninstalling deletes
  your folders and favorites — Android wipes app-private data on uninstall, and
  there is no export yet.
- The APK is signed with Flutter's **debug keys**, which is fine for personal
  use but means a build signed with any other key cannot be installed over it
  later without uninstalling first.
- On **MIUI / HyperOS** (Xiaomi, Redmi, POCO), enable **Autostart** for the app
  and set battery saver to **No restrictions**. Otherwise Android blocks the
  foreground service and you lose the media notification and lock-screen
  controls — playback itself still works.
- The **downloader** unpacks its Python runtime the first time you open the
  download screen, which takes a few seconds. That happens once.

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
| App version in Settings | `package_info_plus` |
| Launcher icon generation | `flutter_launcher_icons` |
| Native splash screen | `flutter_native_splash` |
| Downloader (embedded Python + yt-dlp) | `io.github.junkfood02.youtubedl-android:library` |
| Audio extraction / transcoding for downloads | `io.github.junkfood02.youtubedl-android:ffmpeg` |

Android only — iOS is out of scope. The downloader is doubly so: it runs a
Python build compiled for Android, so it has no equivalent on other platforms.

---

## Architecture

Four layers, each depending only on the ones above it:

```
features/   UI + per-feature Riverpod providers
domain/     app-level models (Track, filter state, sort modes, filtering rules)
data/       Hive models + repositories
services/   audio playback handler, permissions, native MediaStore scan
```

### Key decision: the database stores relationships, never metadata

Hive only ever holds **links and bookkeeping**:

| Box | Holds |
|---|---|
| `folders` | folder id, name, created date, sort mode, system flag |
| `folder_track_links` | folder id ↔ track **file path**, added date, manual order |
| `known_tracks` | files seen in previous scans, for new/deleted diffing |
| `play_history` | append-only play log |
| `settings` | theme mode, library sort preference, repeat mode, download-history visibility |
| `playback_session` | last queue (paths), current track, position |

Titles, artists, artwork and durations are always re-read live from
`on_audio_query` at render time. Nothing is duplicated into the database, so a
rescan can never leave stale metadata behind, and your folders survive any
change to the underlying files.

Tracks are keyed by **file path**, not by MediaStore id, because MediaStore ids
can be reassigned when the system re-indexes.

Because folders are keyed by path and stored in the app's private directory,
they survive an **update** (installing a newer APK over the old one) but not an
**uninstall** — Android deletes app-private data on uninstall. Install over the
top to keep your folders, and export a backup first if you're not sure.

Since `folder_track_links` is the only copy of work the user did by hand, an
unreadable box file is **renamed aside**, never deleted, and the next launch
starts a fresh box beside it. If even the rename fails, the box runs in memory
for that session so the file is left intact for the next attempt. Settings →
Folder backup reports what was set aside and where.

### Startup never blocks on the platform

`main()` shows the UI as soon as Hive is open. Registering with `audio_service`
happens *after* the first frame, because it binds an Android foreground
service and some skins — MIUI especially — stall or refuse that binding. When
it was awaited before `runApp`, a refusal meant a permanently white,
unresponsive window with nothing on screen to explain it.

Now the worst case is an app that plays audio without notification or
lock-screen controls. Hive failures are caught too: a corrupt box is rebuilt
rather than thrown, and anything still fatal renders the actual error on
screen instead of a blank window.

The native MediaStore scan likewise runs on a worker thread — method-channel
handlers run on the main thread, so scanning a real library there froze the UI
before it could paint.

### Scanning uses two sources

`on_audio_query` only queries `MediaStore.Audio` on the primary volume, which
misses audio MediaStore filed into its generic "files" collection — common for
anything a downloader dropped into `Download/`. So the library is the union of:

1. the plugin's query (richer metadata, wins on conflict), and
2. a native query in `MainActivity.kt` over the files collection on every
   volume, keeping rows whose mime type or extension looks like audio.

Results are merged by path, then noise paths (WhatsApp audio and voice notes)
are dropped — see `_excludedPathFragments` in `audio_library_repository.dart`.

Favorites is implemented as a folder with `isSystem: true` rather than a
separate table, so it reuses the same linking code as every other folder.

### Downloads re-enter through MediaStore, not a side door

`YtdlpBridge.kt` runs yt-dlp into a private scratch directory, then **publishes
the finished file into the shared `Music/MusicPlayer/` collection** via a
MediaStore insert (`getExternalFilesDir` on pre-Android-10, which has no insert
API and would otherwise need a storage permission).

That is the whole integration: a downloaded track is an ordinary file the
normal scan finds, so folders, favorites, history and search work on it with no
special-casing anywhere. The Dart side only triggers a library refresh when a
download completes.

Progress arrives on an `EventChannel` keyed by a download id, because a
`MethodChannel` reply can only fire once and a download reports for minutes.

Search goes through yt-dlp's own `ytsearch` prefix rather than the **YouTube
Data API**, for three reasons: the free API quota allows about 100 searches a
day (a `search.list` call costs 100 of 10,000 daily units), an API key cannot
be hidden inside a distributed APK, and the API's terms forbid using data
obtained through it to download media — precisely the pairing this feature
would create. Going through yt-dlp costs no key, no quota and no extra
dependency, and `--flat-playlist` keeps a query to a few seconds by skipping
per-result format resolution.

`--dump-json` field names drift between yt-dlp releases, so `parseSearchOutput`
takes alternatives for each one (`channel` → `uploader` → `uploader_id`,
`thumbnail` → largest of `thumbnails`) and logs the raw output when a parse
yields nothing, rather than failing silently.

### Project layout

```
lib/
  main.dart                     bootstraps Hive + AudioService, runs the app
  app.dart                      MaterialApp, permission gate, tab shell, mini player
  core/                         theme, shared notifiers, formatting/matching helpers
  data/
    hive/                       box setup + @HiveType models
    repositories/               audio library, folders, history, known tracks, settings
  domain/                       Track, sort modes, filter state, filtering rules
  features/
    library/                    scan, sort, search, filter, multi-select, A–Z index
    folders/                    CRUD, folder detail, add-to-folder sheet
    favorites_history/          recently played / most played views
    search/                     search + filter panel
    player/                     player controller, mini player, now playing, queue
    download/                   link input, download queue, history hide/clear
    settings/                   theme, rescan, cleanup, new-audio screen, about
  services/
    audio/                      AudioPlayerHandler (just_audio + audio_service)
    permissions/                permission service + provider
    scanning/                   bridge to the native MediaStore query
    download/                   bridge to the embedded yt-dlp
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
flutter build apk --release --no-tree-shake-icons --split-per-abi
# output: build/app/outputs/flutter-apk/app-<abi>-release.apk
```

Both flags are load-bearing:

- **`--split-per-abi`** produces one APK per architecture (~45 MB each) instead
  of one fat APK (~114 MB). The downloader ships a Python runtime and an FFmpeg
  build *per ABI*, roughly 30 MB apiece, so the ABI list dominates the APK
  size. Install `app-arm64-v8a-release.apk` on any phone from roughly 2019
  onward; `app-armeabi-v7a-release.apk` covers older 32-bit devices.

  Note that `abiFilters` in `build.gradle.kts` will *not* do this: the Flutter
  Gradle plugin assigns that itself from `--target-platform`, anything added
  there only unions with it, and `--target-platform` in turn only governs
  Flutter's own engine — the downloader AAR's other architectures ride along
  regardless. Splitting is what actually drops them.

- **`--no-tree-shake-icons`** is only needed on Windows machines where
  **Smart App Control** or a WDAC policy blocks Flutter's unsigned
  `font-subset.exe`. Release builds run icon tree-shaking through that binary,
  and the block surfaces as
  `Target aot_android_asset_bundle failed: ... An Application Control policy
  has blocked this file`. Skipping tree-shaking ships the full Material icon
  font (~1.6 MB) and sidesteps it. Drop the flag if your machine allows the
  binary to run.

To install straight onto a connected phone: `flutter install --release`.

### App icon and splash screen

Both are generated from `assets/icon/source.jpeg`:

```bash
dart run tool/prep_icons.dart        # source.jpeg -> the four PNGs below
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

`prep_icons.dart` writes `app_icon.png` (legacy launcher icon),
`app_icon_foreground.png` (adaptive-icon foreground, deliberately full-bleed
because `flutter_launcher_icons` applies its own 16% safe-zone inset),
`splash_android12.png` (1152 px with the art inset to 768 px for Android 12's
circular mask) and `splash_logo.png`. It also snaps the near-black JPEG
backdrop to true `#000000`, without which compression noise shows as a faint
square against the black splash and icon backgrounds.

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
  so media buttons reach the handler, and hosts the `music_player/media_store`
  method channel used for the broader audio scan described above.
- **`build.gradle.kts` (root)** patches `on_audio_query_android`, which predates
  current Android Gradle Plugin requirements: it backfills the missing
  `namespace`, pins Java/Kotlin to JVM 17 so the two compilers agree, and raises
  its `compileSdk` through the variant API's `finalizeDsl` (a plain
  `afterEvaluate` is too late — AGP has already locked the value).
- **`gradle.properties`** disables Kotlin incremental compilation, which crashes
  on Windows when the project and the pub cache sit on different drives.
- **The downloader's Gradle setup** needs four things that are easy to miss:
  `useLegacyPackaging = true` (its Python and FFmpeg payloads are unzipped out
  of the APK at first launch, which only works when the native libs are stored
  extractably), `extractNativeLibs="true"` in the manifest for the same reason,
  `keepDebugSymbols` exclusions for `libpython.zip.so` / `libffmpeg.zip.so`
  (they are zip archives named `.so` so they get packaged at all, and the NDK
  strip step errors on them otherwise), and the `INTERNET` permission.
- **`proguard-rules.pro` keeps `org.apache.commons.compress`.** yt-dlp's
  payloads are unzipped with commons-compress, whose `ExtraFieldUtils`
  registers field types reflectively in a static initializer. Without the keep
  rule R8 sees classes like `AsiExtraField` as never instantiated, makes them
  non-concrete, and the unpack dies with `RuntimeException: class ... is not a
  concrete class` — wrapped in an `ExceptionInInitializerError`, which is an
  `Error`, not an `Exception`. `YtdlpBridge` therefore catches `Throwable`
  throughout: letting one escape a pool thread kills the process instead of
  failing one call.
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
6. Recently played / most played views
7. Visual polish pass
8. Settings: rescan, cleanup of records for missing files, about/version

All eight modules from the original plan are built and verified on a device.

Added since: app icon and splash screen, and the yt-dlp downloader
(downloading, cancelling and history hide/clear all verified on a device).

### Known limitations

- The **"recently played" filter** returns nothing until you've actually played
  something — the history log starts empty.
- The scan can only see files **MediaStore has indexed**. Audio copied onto the
  device by a method that never triggers a media scan stays invisible to every
  app that queries MediaStore, this one included.
- **Uninstalling deletes your folders and favorites.** Install a newer APK over
  the old one instead. There is no backup/export yet.
- The release APK is signed with Flutter's **debug keys** and uses the
  placeholder package name `com.example.music_player`. Both need changing
  before distributing the app anywhere.
- Notification artwork isn't shown yet; the notification uses the app icon.
- **Downloading from YouTube violates its Terms of Service**, whatever tool is
  used. That is why apps of this kind are not on Google Play, and it applies to
  this one. Decide for yourself whether to keep the feature.
- **Download history lives in memory only** and is gone when the app is killed.
  Hiding and clearing it work within a session; there is no persisted log.
- **The downloader roughly doubles the APK.** ~45 MB per-ABI versus ~22 MB
  before it existed.
- During yt-dlp's extraction and FFmpeg transcoding phases **no percentage is
  reported** — the progress bar sits at 0% and then at 100% while real work
  continues. On a long track the transcode alone can run for a minute and look
  stalled.
- Extraction **will break eventually** as sites change; use the in-app
  **Update yt-dlp** button rather than waiting for an app release. The same
  applies to search, which runs through the same extractor.
- **Search takes a few seconds.** It scrapes rather than calling an API, so it
  will never feel as immediate as a search box usually does.
- On MIUI (Xiaomi / Redmi / POCO) the media notification and background
  playback need **Autostart** enabled for the app in Security settings, and
  battery saver set to **No restrictions**. Without those, Android blocks the
  foreground service; the app still runs and plays, just without
  notification and lock-screen controls.
