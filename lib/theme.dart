import 'package:flutter/material.dart';

const kBrand = Color(0xFFE8505B); // coral rose
const kInk = Color(0xFF1A1A1A);
const kMuted = Color(0xFF6B6B6B);
const kSoft = Color(0xFFF2EFEE);
const kBg = Color(0xFFFDFCFB);
const kLine = Color(0xFFE6E2E0);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kBrand,
    brightness: Brightness.light,
  ).copyWith(surface: kBg, primary: kBrand, onPrimary: Colors.white);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: kBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: kBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: kInk),
      titleTextStyle: TextStyle(
        color: kInk,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}

InputDecoration inputDeco(String label, {String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: kSoft,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
