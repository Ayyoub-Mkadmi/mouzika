import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mouzika/screens/playlist_screen.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'search_screen.dart';
import 'music_library_screen.dart';
import 'now_playing_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

final GlobalKey<_HomeNavigationState> homeNavKey =
    GlobalKey<_HomeNavigationState>();

class HomeNavigation extends StatefulWidget {
  const HomeNavigation({super.key});

  @override
  State<HomeNavigation> createState() => _HomeNavigationState();
}

class _HomeNavigationState extends State<HomeNavigation> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _animationController;
  
  static const List<String> _titles = [
    'Search',
    'Library',
    'Playlists',
    'Now Playing',
  ];
  
  static const List<IconData> _icons = [
    Icons.search_rounded,
    Icons.library_music_rounded,
    Icons.queue_music_rounded,
    Icons.music_note_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Make this public by removing the underscore
  void goToNowPlaying() {
    setState(() => _selectedIndex = 3); // Updated to match the correct index for Now Playing
    _animationController.reset();
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final primaryColor = Theme.of(context).primaryColor;
    
    // Create gradient colors based on theme
    final List<Color> gradientColors = isDark
        ? [
            primaryColor.withOpacity(0.7),
            primaryColor,
          ]
        : [
            primaryColor.withOpacity(0.6),
            primaryColor,
          ];

    final _screens = [
      const SearchScreen(),
      const MusicLibraryScreen(),
      const PlaylistScreen(),
      const NowPlayingScreen(),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark 
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.grey[900],
              systemNavigationBarIconBrightness: Brightness.light,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.white,
              systemNavigationBarIconBrightness: Brightness.dark,
            ),
      child: Scaffold(
        // Removed extendBodyBehindAppBar to prevent search bar overlap
        appBar: AppBar(
          elevation: 0,
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          title: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.2),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Text(
              _titles[_selectedIndex],
              key: ValueKey<String>(_titles[_selectedIndex]),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 20,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          centerTitle: true,
          leading: _selectedIndex == 3 
              ? IconButton(
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: isDark ? Colors.white70 : Colors.black54,
                    size: 28,
                  ),
                  onPressed: () {
                    setState(() => _selectedIndex = 0);
                    _animationController.reset();
                    _animationController.forward();
                  },
                )
              : null,
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _selectedIndex == 3 ? null : LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: _selectedIndex == 3 
                      ? (isDark ? Colors.amber : Colors.blueGrey) 
                      : Colors.white,
                ),
                onPressed: () {
                  Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
                  HapticFeedback.lightImpact();
                },
              ),
            ),
          ],
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _screens[_selectedIndex],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                spreadRadius: 0,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(
                      _icons.length,
                      (index) => _buildNavItem(index, isDark, primaryColor),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildNavItem(int index, bool isDark, Color primaryColor) {
    final isSelected = _selectedIndex == index;
    
    return InkWell(
      onTap: () {
        if (_selectedIndex != index) {
          HapticFeedback.selectionClick();
          setState(() => _selectedIndex = index);
          _animationController.reset();
          _animationController.forward();
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16.0 : 12.0,
          vertical: 8.0,
        ),
        decoration: BoxDecoration(
          color: isSelected 
              ? (isDark ? primaryColor.withOpacity(0.2) : primaryColor.withOpacity(0.1))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _icons[index],
              color: isSelected ? primaryColor : (isDark ? Colors.grey[400] : Colors.grey[600]),
              size: isSelected ? 24 : 22,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                _titles[index],
                style: GoogleFonts.poppins(
                  color: primaryColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
