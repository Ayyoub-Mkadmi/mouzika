import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences

class ThemeProvider extends ChangeNotifier {
  static const String _themePrefKey = 'isDarkMode'; // Key for SharedPreferences
  bool _isDarkMode = false; // Default value before loading

  bool get isDarkMode => _isDarkMode;

  // Initialize the theme provider by loading the preference
  // This should be called once in main.dart before runApp
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    // Get the stored preference, default to false (light mode) if not found
    _isDarkMode = prefs.getBool(_themePrefKey) ?? false;
    // No need to notifyListeners here if called before runApp
  }

  // Toggle theme and save the preference
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners(); // Notify listeners immediately for UI update
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themePrefKey, _isDarkMode); // Save the new preference
  }
}
