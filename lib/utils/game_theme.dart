import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GameTheme {
  static final ValueNotifier<String> currentTheme = ValueNotifier<String>('Netflix');

  static Map<String, dynamic> getThemeColors([String? themeName]) {
    final theme = themeName ?? currentTheme.value;
    
    switch (theme) {
      case 'Cyberpunk':
        return {
          'bg': const Color(0xFF0D0221),
          'card': const Color(0xFF1B065E).withOpacity(0.8),
          'accent': const Color(0xFFFF0060),
          'secondary': const Color(0xFF00D2FF),
          'font': GoogleFonts.orbitron,
        };
      case 'Casino':
        return {
          'bg': const Color(0xFF0A2E1D),
          'card': const Color(0xFF1B4D3E).withOpacity(0.8),
          'accent': const Color(0xFFFFD700),
          'secondary': const Color(0xFFFFFFFF),
          'font': GoogleFonts.playfairDisplay,
        };
      case 'Netflix':
      default:
        return {
          'bg': Colors.black,
          'card': const Color(0xFF141414).withOpacity(0.8),
          'accent': const Color(0xFFE50914),
          'secondary': Colors.white70,
          'font': GoogleFonts.poppins,
        };
    }
  }
}
