import 'package:flutter/material.dart';

/// AppColors definition with strictly curated Light and Dark palettes.
///
/// Kept as a single source of truth so both the neomorphic widgets (other
/// features) and the flat Material design (AI provider screens) stay
/// consistent. All names are stable — only values were modernised.
abstract final class AppColors {
  // Base Palette
  static const Color primary = Color(0xFF4F46E5); // indigo
  static const Color oldPaper = Color(0xFFF3F4F6);
  static const Color paper = Color(0xFFFFFFFF); // clean white
  static const Color stage = Color(0xFFF5F6F8); // cool off-white
  static const Color ink = Color(0xFF14161A); // near-black
  static const Color secondary = Color(0xFFEDEFF3); // light cool grey
  static const Color muted = Color(0xFF626B76); // medium grey
  static const Color success = Color(0xFF1E9E5A); // green
  static const Color warning = Color(0xFFD99E00); // amber
  static const Color danger = Color(0xFFDC3C43); // red
  static const Color border = Color(0x14151B24); // ink @ 8 % opacity

  // Light Palette
  static const Color lightStage = Color(0xFFF5F6F8);
  static const Color lightPaper = Color(0xFFFFFFFF);
  static const Color lightInk = Color(0xFF14161A);
  static const Color lightPrimary = Color(0xFF4F46E5);
  static const Color lightSecondary = Color(0xFFEDEFF3);
  static const Color lightMuted = Color(0xFF626B76);
  static const Color lightSuccess = Color(0xFF1E9E5A);
  static const Color lightWarning = Color(0xFFD99E00);
  static const Color lightDanger = Color(0xFFDC3C43);

  // Dark Palette
  static const Color darkStage = Color(0xFF0F1115);
  static const Color darkPaper = Color(0xFF16181E);
  static const Color darkCard = Color(0xFF1B1E25);
  static const Color darkPopover = Color(0xFF23262E);
  static const Color darkInk = Color(0xFFECEEF2);
  static const Color darkPrimary = Color(0xFF949BFA);
  static const Color darkPrimaryForeground = Color(0xFF12141B);
  static const Color darkSecondary = Color(0xFF22252C);
  static const Color darkMuted = Color(0xFF9CA3AE);
  static const Color darkSuccess = Color(0xFF45C878);
  static const Color darkWarning = Color(0xFFF2C14E);
  static const Color darkDanger = Color(0xFFF36D68);
  static const Color darkBorder = Color(0x24ECEEF2); // ink @ 14 % opacity
  static const Color darkInput = Color(0x2EECEEF2); // ink @ 18 % opacity

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
