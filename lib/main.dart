import 'package:flutter/material.dart';
import 'package:mouzika/providers/music_player_provider.dart';
import 'package:mouzika/providers/theme_provider.dart';
import 'package:mouzika/screens/home_navigation.dart';
import 'package:mouzika/services/audio_handler.dart'; // Import your handler
import 'package:audio_service/audio_service.dart';
import 'package:provider/provider.dart';
import 'package:just_audio_background/just_audio_background.dart';

late final AudioHandler audioHandler;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mouzika',
      theme: themeProvider.isDarkMode ? ThemeData.dark() : ThemeData.light(),
      home: const HomeNavigation(),
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('\n\n\n*********Before initAudioHandler____________________\n\n\n');
  audioHandler = await initAudioHandler();
  print('\n\n\n***********After initAudioHandler________________\n\n\n');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (_) => MusicPlayerProvider(audioHandler),
        ),
      ],
      child: const MyApp(),
    ),
  );
}
