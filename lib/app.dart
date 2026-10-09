import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'core/theme/app_theme.dart';
import 'features/download/screens/download_screen.dart';
import 'features/folders/screens/folders_screen.dart';
import 'features/library/screens/library_screen.dart';
import 'features/player/providers/playback_session_provider.dart';
import 'features/player/widgets/mini_player.dart';
import 'features/settings/providers/theme_mode_provider.dart';
import 'features/settings/screens/settings_screen.dart';
import 'services/permissions/permission_provider.dart';
import 'widgets/permission_gate_screen.dart';

class MusicPlayerApp extends ConsumerWidget {
  const MusicPlayerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'FUNNY Music',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const _RootShell(),
    );
  }
}

class _RootShell extends ConsumerStatefulWidget {
  const _RootShell();

  @override
  ConsumerState<_RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<_RootShell> {
  int _index = 0;

  /// Asked once per launch, and only after the audio permission is in hand.
  /// Android itself stops showing the dialog once it has been refused, so this
  /// only guards against asking twice in one session.
  bool _askedAboutNotifications = false;

  /// Whether the Download tab has been opened yet.
  ///
  /// [IndexedStack] builds every child whether it is on screen or not, and
  /// the download screen's first build unpacks the bundled Python runtime —
  /// several seconds of IO that has no business running during launch for a
  /// tab the user may never open. It takes its place in the stack the first
  /// time it is selected, and keeps its state from then on like the others.
  bool _downloadOpened = false;

  static const _downloadTab = 2;

  static const _screens = [
    LibraryScreen(),
    FoldersScreen(),
    DownloadScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final permissionAsync = ref.watch(audioPermissionProvider);

    return permissionAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('Something went wrong: $error'))),
      data: (status) {
        if (!status.isGranted) {
          return const PermissionGateScreen();
        }
        // Brings back last time's song, paused, and keeps saving it.
        ref.watch(playbackSessionProvider);

        // The media notification needs its own runtime permission on Android
        // 13+, and nothing was ever asking for it — so the lock-screen
        // controls could not appear no matter how well the audio session
        // registered. Asked after the first frame, never as a gate: the app
        // works without it.
        if (!_askedAboutNotifications) {
          _askedAboutNotifications = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) ref.read(notificationPermissionProvider.notifier).request();
          });
        }

        return Scaffold(
          body: IndexedStack(
            index: _index,
            children: [
              for (var i = 0; i < _screens.length; i++)
                // A placeholder rather than a shorter list: the index into
                // this stack is the navigation bar's own selection.
                if (i == _downloadTab && !_downloadOpened)
                  const SizedBox.shrink()
                else
                  _screens[i],
            ],
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MiniPlayer(),
              NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() {
                  _index = i;
                  if (i == _downloadTab) _downloadOpened = true;
                }),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.library_music_outlined),
                    selectedIcon: Icon(Icons.library_music),
                    label: 'Library',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.folder_outlined),
                    selectedIcon: Icon(Icons.folder),
                    label: 'Playlists',
                  ),
                  // The tab that used to be here searched the library, which
                  // is what the Library tab's own field already does; the
                  // downloader is the one screen that had no way in but
                  // through Settings.
                  NavigationDestination(
                    icon: Icon(Icons.download_outlined),
                    selectedIcon: Icon(Icons.download),
                    label: 'Download',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: 'Settings',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
