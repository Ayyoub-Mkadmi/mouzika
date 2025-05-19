import 'package:flutter/material.dart';
import 'package:mouzika/providers/music_player_provider.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_navigation.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => MusicPlayerProvider()),
      ],
      child: MyApp(),
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
