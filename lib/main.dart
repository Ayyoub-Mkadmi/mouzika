import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mouzika/models/track.dart';
import 'package:mouzika/providers/music_player_provider.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_navigation.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // background audio
  await JustAudioBackground.init(
    androidNotificationChannelId  : 'com.example.mouzika.channel.audio',
    androidNotificationChannelName: 'Audio Playback',
    androidNotificationOngoing    : true,
  );

  // ---------- Hive ----------
  final docs = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(docs.path);
  Hive.registerAdapter(TrackAdapter());
  await Hive.openBox<Track>('tracks');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => MusicPlayerProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Mouzika',
      theme: themeProvider.isDarkMode ? ThemeData.dark() : ThemeData.light(),
      home: const HomeNavigation(),
    );
  }
}
