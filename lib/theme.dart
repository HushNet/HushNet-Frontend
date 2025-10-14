import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

final hushNetTheme = FlexThemeData.dark(
  scheme: FlexScheme.blue,
  primary: const Color(0xFF3A8DFF),
  primaryLightRef: const Color(0xFF3A8DFF),
  secondary: const Color(0xFF1E1E1E),
  surface: const Color(0xFF0D0D0D),
  scaffoldBackground: const Color(0xFF0D0D0D),
  appBarStyle: FlexAppBarStyle.background,
  appBarElevation: 0,
  fontFamily: GoogleFonts.inter().fontFamily,
  useMaterial3: true,
).copyWith(
  textTheme: GoogleFonts.interTextTheme().apply(
    bodyColor: Colors.white,
    displayColor: Colors.white,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF3A8DFF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF1E1E1E),
    hintStyle: TextStyle(color: Colors.grey[500]),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  ),
);
