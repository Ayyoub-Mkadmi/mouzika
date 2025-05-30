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
import '../widgets/mini_player_widget.dart'; // Import the mini player widget
import 'package:mouzika/services/audio_player_manager.dart'; // To check player state
import 'package:just_audio/just_audio.dart'; // For PlayerState

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
  final PanelController _panelController = PanelController(); // Controller for the panel
  final AudioPlayer _audioPlayer = AudioPlayerManager().audioPlayer; // Get audio player instance
  
  static const List<String> _titles = [
    'Search',
    'Library',
    'Playlists',
    // 'Now Playing', // Title is handled by the panel now
  ];
  
  static const List<IconData> _icons = [
    Icons.search_rounded,
    Icons.library_music_rounded,
    Icons.queue_music_rounded,
    // Icons.music_note_rounded, // Now Playing is accessed via panel
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
    // _panelController is implicitly handled by SlidingUpPanel
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
    final bottomNavBarHeight = 80.0; // Approximate height of your custom bottom nav bar
    final miniPlayerHeight = 65.0;
    
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

    // Screens for the main body (excluding Now Playing)
    final _screens = [
      const SearchScreen(),
      const MusicLibraryScreen(),
      const PlaylistScreen(),
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
      child: StreamBuilder<SequenceState?>(
        // Listen to sequence state to determine if mini-player should show
        stream: _audioPlayer.sequenceStateStream,
        builder: (context, sequenceSnapshot) {
          final bool showMiniPlayer = sequenceSnapshot.hasData && sequenceSnapshot.data?.currentSource != null;
          final double currentMinHeight = showMiniPlayer ? miniPlayerHeight : 0;

          return SlidingUpPanel(
            controller: _panelController,
            minHeight: currentMinHeight, // Show mini-player only if playing
            maxHeight: screenHeight, // Full screen height
            panel: Builder(
              builder: (context) => NowPlayingScreen(
                key: ValueKey(sequenceSnapshot.data?.currentSource), // Forces rebuild on track change
              ),
            ),
            collapsed: Builder(
              builder: (context) => MiniPlayerWidget(
                key: ValueKey(sequenceSnapshot.data?.currentSource), // Forces rebuild on track change
                onTap: openNowPlayingPanel,
              ),
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
            backdropEnabled: true,
            backdropOpacity: 0.5,
            parallaxEnabled: true,
            parallaxOffset: 0.1,
            // Body of the Scaffold, wrapped by the panel
            body: Scaffold(
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
                    _titles[_selectedIndex], // Title based on selected tab
                    key: ValueKey<String>(_titles[_selectedIndex]),
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 20,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                centerTitle: true,
                // Removed leading button, panel handles Now Playing access
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
              ),
              // Main content area, changes based on selected tab
              body: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _screens[_selectedIndex],
              ),
              // Bottom Navigation Bar
              bottomNavigationBar: Container(
                // Add padding to the bottom to account for the mini-player height when visible
                padding: EdgeInsets.only(bottom: showMiniPlayer ? miniPlayerHeight : 0),
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
                  // Prevent SafeArea from adding padding when mini-player is shown
                  bottom: !showMiniPlayer, 
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
                            _icons.length, // Use the length of the icons list (3 tabs now)
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
        },
      ),
    );
  }
  
  // Build individual navigation items
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
