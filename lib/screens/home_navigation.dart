import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mouzika/screens/playlist_screen.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'search_screen.dart'; // Assuming this is the correct path now
import 'music_library_screen.dart';
// Use the fixed NowPlayingScreen for the panel content
import 'now_playing_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart'; // Import the panel package
// *** IMPORT THE MINI PLAYER WITHOUT PROGRESS BAR ***
import '../widgets/mini_player_widget.dart'; // Import the mini player without progress bar
import 'package:mouzika/services/audio_player_manager.dart'; // To check player state
import 'package:just_audio/just_audio.dart'; // For PlayerState

final GlobalKey<_HomeNavigationState> homeNavKey =
    GlobalKey<_HomeNavigationState>();

class HomeNavigation extends StatefulWidget {
  const HomeNavigation({super.key});

  @override
  State<HomeNavigation> createState() => _HomeNavigationState();
}

class _HomeNavigationState extends State<HomeNavigation>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _animationController;
  final PanelController _panelController =
      PanelController(); // Controller for the panel
  final AudioPlayer _audioPlayer =
      AudioPlayerManager().audioPlayer; // Get audio player instance

  static const List<String> _titles = ['Search', 'Library', 'Playlists'];

  static const List<IconData> _icons = [
    Icons.search_rounded,
    Icons.library_music_rounded,
    Icons.queue_music_rounded,
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

  // Function to open the Now Playing panel
  void openNowPlayingPanel() {
    if (_panelController.isAttached && !_panelController.isPanelOpen) {
      _panelController.open();
    }
  }

  // Function to navigate to a specific tab
  void _navigateToTab(int index) {
    if (_selectedIndex != index) {
      HapticFeedback.selectionClick();
      setState(() => _selectedIndex = index);
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final primaryColor = Theme.of(context).primaryColor;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenPadding = MediaQuery.of(context).padding;
    final appBarHeight = AppBar().preferredSize.height;
    // *** USE HEIGHT OF MINI PLAYER WITHOUT PROGRESS BAR ***
    final miniPlayerHeight = 65.0;

    // Estimate the bottom navigation bar height (SafeArea + nav bar)
    final bottomNavBarHeight =
        kBottomNavigationBarHeight +
        screenPadding.bottom +
        24; // 24 is your nav bar's vertical padding

    // Panel should fill the space below the AppBar and above the bottom navigation/system areas
    final panelMaxHeight =
        screenHeight - appBarHeight - screenPadding.top - bottomNavBarHeight;

    // Create gradient colors based on theme
    final List<Color> gradientColors =
        isDark
            ? [primaryColor.withOpacity(0.7), primaryColor]
            : [primaryColor.withOpacity(0.6), primaryColor];

    // Screens for the main body (excluding Now Playing)
    final screens = [
      const SearchScreen(),
      const MusicLibraryScreen(),
      const PlaylistScreen(),
    ];

    // Define the AppBar separately to easily access its height
    final appBar = AppBar(
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
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: Colors.white,
            ),
            onPressed: () {
              Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
              HapticFeedback.lightImpact();
            },
          ),
        ),
      ],
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value:
          isDark
              ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarIconBrightness: Brightness.light,
              )
              : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarIconBrightness: Brightness.dark,
              ),
      child: Scaffold(
        appBar: appBar, // Use the defined AppBar
        body: StreamBuilder<SequenceState?>(
          stream: _audioPlayer.sequenceStateStream,
          builder: (context, sequenceSnapshot) {
            final bool showMiniPlayer =
                sequenceSnapshot.hasData &&
                sequenceSnapshot.data?.currentSource != null;
            final double contentBottomPadding =
                showMiniPlayer ? miniPlayerHeight : 0;

            return Stack(
              children: [
                // Main content area
                Padding(
                  padding: EdgeInsets.only(bottom: contentBottomPadding),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: screens[_selectedIndex],
                  ),
                ),
                // SlidingUpPanel
                SlidingUpPanel(
                  controller: _panelController,
                  minHeight: showMiniPlayer ? miniPlayerHeight : 0,
                  // *** USE CALCULATED MAX HEIGHT ***
                  maxHeight: panelMaxHeight,
                  panel: Builder(
                    builder:
                        (context) => NowPlayingScreen(
                          key: ValueKey(sequenceSnapshot.data?.currentSource),
                        ),
                  ),
                  collapsed: Builder(
                    builder:
                        (context) => MiniPlayerWidget(
                          key: ValueKey(sequenceSnapshot.data?.currentSource),
                          onTap: openNowPlayingPanel,
                        ),
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24.0),
                  ),
                  backdropEnabled: true,
                  backdropOpacity: 0.5,
                  parallaxEnabled: true,
                  parallaxOffset: 0.1,
                  body: null,
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: StreamBuilder<SequenceState?>(
          stream: _audioPlayer.sequenceStateStream,
          builder: (context, sequenceSnapshot) {
            // Bottom Nav Bar remains the same
            return Container(
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
                top: false,
                left: false,
                right: false,
                bottom: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 8.0,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[850] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 8.0,
                      ),
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
            );
          },
        ),
      ),
    );
  }

  // Build individual navigation items (no changes needed here)
  Widget _buildNavItem(int index, bool isDark, Color primaryColor) {
    final isSelected = _selectedIndex == index;

    return InkWell(
      onTap: () => _navigateToTab(index),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16.0 : 12.0,
          vertical: 8.0,
        ),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? (isDark
                      ? primaryColor.withOpacity(0.3)
                      : primaryColor.withOpacity(
                        0.1,
                      )) // Increased opacity for dark mode background
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _icons[index],
              color:
                  isSelected
                      ? (isDark
                          ? Colors.white
                          : primaryColor) // White in dark mode, purple in light
                      : (isDark ? Colors.grey[400] : Colors.grey[600]),
              size: isSelected ? 24 : 22,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                _titles[index],
                style: GoogleFonts.poppins(
                  color:
                      isDark
                          ? Colors.white
                          : primaryColor, // White in dark mode, purple in light
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
