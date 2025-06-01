import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mouzika/models/track.dart';
import 'package:mouzika/providers/music_player_provider.dart';
import 'package:mouzika/providers/theme_provider.dart'; // Ensure this path is correct
import 'package:mouzika/screens/home_navigation.dart';
// import 'package:audio_service/audio_service.dart'; // Not used directly here?
import 'package:provider/provider.dart';
// import 'providers/theme_provider.dart'; // Duplicate import removed
// import 'screens/home_navigation.dart'; // Duplicate import removed
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';

// Define your primary color constant
const Color kPrimaryPurple = Color.fromARGB(255, 102, 70, 249);

void main() async {
  // Make main async
  WidgetsFlutterBinding.ensureInitialized(); // Ensure bindings are initialized

  // Initialize ThemeProvider *before* other initializations that might need it,
  // and definitely before runApp.
  final themeProvider = ThemeProvider();
  await themeProvider.init(); // Load the saved theme preference

  // Background audio initialization
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.mouzika.channel.audio',
    androidNotificationChannelName: 'Audio Playback',
    androidNotificationOngoing: true,
  );

  // Hive initialization
  final docs = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(docs.path);
  Hive.registerAdapter(TrackAdapter());
  await Hive.openBox<Track>('tracks');

  runApp(
    MultiProvider(
      providers: [
        // Use ChangeNotifierProvider.value for the pre-initialized themeProvider
        ChangeNotifierProvider.value(value: themeProvider),
        // Keep other providers as they were
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
    // Access the themeProvider instance provided by MultiProvider
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mouzika',
      // Define the light theme explicitly
      theme: ThemeData.light().copyWith(
        primaryColor: kPrimaryPurple,
        colorScheme: ThemeData.light().colorScheme.copyWith(
          primary: kPrimaryPurple,
          secondary: kPrimaryPurple, // Often good to set secondary too
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: kPrimaryPurple,
          thumbColor: kPrimaryPurple,
          overlayColor: kPrimaryPurple.withAlpha(32),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: kPrimaryPurple,
        ),
        // Add other light theme customizations if needed
      ),
      // Define the dark theme explicitly
      darkTheme: ThemeData.dark().copyWith(
        primaryColor: kPrimaryPurple,
        colorScheme: ThemeData.dark().colorScheme.copyWith(
          primary: kPrimaryPurple,
          secondary: kPrimaryPurple, // Often good to set secondary too
          brightness: Brightness.dark, // Ensure brightness is dark
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: kPrimaryPurple,
          thumbColor: kPrimaryPurple,
          overlayColor: kPrimaryPurple.withAlpha(32),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: kPrimaryPurple,
        ),
        // Add other dark theme customizations if needed
        // Example: scaffoldBackgroundColor: Colors.grey[900],
      ),
      // Use themeMode to control which theme is active
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const HomeNavigation(),
    );
  }
}
