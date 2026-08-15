import 'package:flutter/material.dart';

/// AppColors definition with strictly curated Light and Dark Neomorphic palettes.
abstract final class AppColors {
  // Base Palette
  static const Color primary = Color(0xFFC2703D); // muted orange/brown
  static const Color oldPaper = Color(0xFFC9A66B);
  static const Color paper = Color(0xFFFBF9F6); // warm white
  static const Color stage = Color(0xFFF1EEE7); // warm off-white
  static const Color ink = Color(0xFF2B2724); // dark grey
  static const Color secondary = Color(0xFFEAE5DC); // light warm grey
  static const Color muted = Color(0xFF8C8782); // medium grey
  static const Color success = Color(0xFF4F9D5C); // green
  static const Color warning = Color(0xFFD9A93B); // amber
  static const Color danger = Color(0xFFC4422E); // red
  static const Color border = Color(0x142B2724); // ink @ 8 % opacity

  // Light Palette
  static const Color lightStage = Color(0xFFF0EEEB);
  static const Color lightPaper = Color(0xFFFDFAF4);
  static const Color lightInk = Color(0xFF181310);
  static const Color lightPrimary = Color(0xFFE57C20);
  static const Color lightSecondary = Color(0xFFEBE7E1);
  static const Color lightMuted = Color(0xFF76706C);
  static const Color lightSuccess = Color(0xFF46B250);
  static const Color lightWarning = Color(0xFFF3BA25);
  static const Color lightDanger = Color(0xFFEA3037);

  // Dark Palette
  static const Color darkStage = Color(0xFF1F1B18);
  static const Color darkPaper = Color(0xFF2B2723);
  static const Color darkCard = Color(0xFF322D28);
  static const Color darkPopover = Color(0xFF3A342E);
  static const Color darkInk = Color(0xFFF3EDDF);
  static const Color darkPrimary = Color(0xFFEE9C21);
  static const Color darkPrimaryForeground = Color(0xFF211D18);
  static const Color darkSecondary = Color(0x4F4A423A);
  static const Color darkMuted = Color(0xFFAFA79D);
  static const Color darkSuccess = Color(0xFF67BD54);
  static const Color darkWarning = Color(0xFFF9DC56);
  static const Color darkDanger = Color(0xFFEC5855);
  static const Color darkBorder = Color(0x1FF3EDDF);
  static const Color darkInput = Color(0x29F3EDDF);

  // Context-aware convenience getters
  static Color getStage(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? darkStage : lightStage;
  }

  static Color getPaper(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? darkPaper : lightPaper;
  }

  static Color getCard(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? darkCard : lightPaper;
  }

  static Color getInk(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? darkInk : lightInk;
  }

  static Color getPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? darkPrimary : lightPrimary;
  }

  static Color getMuted(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? darkMuted : lightMuted;
  }

  static Color getBorder(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? darkBorder : border;
  }
}
