import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/theme/app_theme.dart';
import 'data/hive/hive_setup.dart';
import 'data/repositories/settings_repository.dart';
import 'features/player/providers/player_providers.dart';
import 'services/audio/audio_player_handler.dart';

/// Startup is deliberately defensive: anything that throws or hangs before
/// `runApp` leaves a blank white window with no way to tell what went wrong,
/// so each step is guarded and either degrades or reports itself on screen.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await initHive();
  } catch (error, stackTrace) {
    runApp(_StartupErrorApp(error: error, stackTrace: stackTrace, stage: 'opening the local database'));
    return;
  }

  // The handler works on its own for in-app playback, so build it directly
  // and show the UI straight away.
  final audioHandler = AudioPlayerHandler();

  runApp(
    ProviderScope(
      overrides: [audioHandlerProvider.overrideWithValue(audioHandler)],
      child: const MusicPlayerApp(),
    ),
  );

  // Registering with audio_service adds the notification and lock-screen
  // controls. It binds a foreground service, which some Android skins (MIUI
  // in particular) stall or refuse — so it runs *after* the first frame and
  // is never allowed to hold the app hostage. Worst case the app simply
  // plays without notification controls.
  unawaited(_registerAudioService(audioHandler));

  // Restored after the first frame for the same reason: a preference must
  // never be able to keep the app from appearing.
  unawaited(
    audioHandler
        .setRepeatMode(_repeatModeFromName(SettingsRepository().repeatMode))
        .catchError((Object error) => debugPrint('Could not restore repeat mode: $error')),
  );
}

AudioServiceRepeatMode _repeatModeFromName(String name) => switch (name) {
      'none' => AudioServiceRepeatMode.none,
      'one' => AudioServiceRepeatMode.one,
      _ => AudioServiceRepeatMode.all,
    };

Future<void> _registerAudioService(AudioPlayerHandler handler) async {
  try {
    await AudioService.init(
      builder: () => handler,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.example.music_player.channel.audio',
        androidNotificationChannelName: 'Playback',
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: true,
      ),
    ).timeout(const Duration(seconds: 20));
  } catch (error) {
    debugPrint('audio_service unavailable; in-app playback still works: $error');
  }
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.error, required this.stackTrace, required this.stage});

  final Object error;
  final StackTrace stackTrace;
  final String stage;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                Icon(Icons.error_outline, size: 56, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 16),
                Text("The app couldn't start", style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('Something went wrong while $stage.'),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      '$error\n\n$stackTrace',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
