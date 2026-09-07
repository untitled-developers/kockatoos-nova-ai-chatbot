import 'package:flutter/material.dart';

@immutable
class NovaTheme {
  final String name;
  final Color primary;
  final Color primaryHover;
  final Color primaryLight;
  final Color primaryText;
  final Color gradientFrom;
  final Color gradientTo;
  final Color userBubbleBg;
  final Color userBubbleText;
  final Color botBubbleBg;
  final Color botBubbleText;

  const NovaTheme({
    required this.name,
    required this.primary,
    required this.primaryHover,
    required this.primaryLight,
    required this.primaryText,
    required this.gradientFrom,
    required this.gradientTo,
    required this.userBubbleBg,
    required this.userBubbleText,
    required this.botBubbleBg,
    required this.botBubbleText,
  });

  static Color hexToColor(String hexString) {
    var cleanHex = hexString.replaceAll('#', '').trim();
    if (cleanHex.length == 3) {
      cleanHex = cleanHex.split('').map((c) => '$c$c').join();
    }
    if (cleanHex.length == 6) {
      cleanHex = 'FF$cleanHex';
    }
    final val = int.tryParse(cleanHex, radix: 16) ?? 0xFFF05A2B;
    return Color(val);
  }

  static const NovaTheme defaultKockatoos = NovaTheme(
    name: 'Kockatoos Brand',
    primary: Color(0xFFF05A2B),
    primaryHover: Color(0xD94A1F00),
    primaryLight: Color(0x14F05A2B),
    primaryText: Color(0xFFF05A2B),
    gradientFrom: Color(0xFFF05A2B),
    gradientTo: Color(0xFFF05A2B),
    userBubbleBg: Color(0xFFF05A2B),
    userBubbleText: Colors.white,
    botBubbleBg: Color(0xFFF1F5F9),
    botBubbleText: Color(0xFF1E293B),
  );

  static const Map<String, NovaTheme> presets = {
    'indigo': defaultKockatoos,
    'emerald': NovaTheme(
      name: 'Emerald & Teal',
      primary: Color(0xFF059669),
      primaryHover: Color(0xFF047857),
      primaryLight: Color(0xFFECFDF5),
      primaryText: Color(0xFF047857),
      gradientFrom: Color(0xFF059669),
      gradientTo: Color(0xFF0D9488),
      userBubbleBg: Color(0xFF059669),
      userBubbleText: Colors.white,
      botBubbleBg: Color(0xFFF1F5F9),
      botBubbleText: Color(0xFF1E293B),
    ),
    'ocean': NovaTheme(
      name: 'Royal Ocean & Cyan',
      primary: Color(0xFF2563EB),
      primaryHover: Color(0xFF1D4ED8),
      primaryLight: Color(0xFFEFF6FF),
      primaryText: Color(0xFF1D4ED8),
      gradientFrom: Color(0xFF2563EB),
      gradientTo: Color(0xFF06B6D4),
      userBubbleBg: Color(0xFF2563EB),
      userBubbleText: Colors.white,
      botBubbleBg: Color(0xFFF1F5F9),
      botBubbleText: Color(0xFF1E293B),
    ),
    'rose': NovaTheme(
      name: 'Rose & Crimson',
      primary: Color(0xFFE11D48),
      primaryHover: Color(0xFFBE123C),
      primaryLight: Color(0xFFFFF1F2),
      primaryText: Color(0xFFBE123C),
      gradientFrom: Color(0xFFE11D48),
      gradientTo: Color(0xFFC026D3),
      userBubbleBg: Color(0xFFE11D48),
      userBubbleText: Colors.white,
      botBubbleBg: Color(0xFFF1F5F9),
      botBubbleText: Color(0xFF1E293B),
    ),
    'amber': NovaTheme(
      name: 'Warm Amber',
      primary: Color(0xFFD97706),
      primaryHover: Color(0xFFB45309),
      primaryLight: Color(0xFFFFFBEB),
      primaryText: Color(0xFFB45309),
      gradientFrom: Color(0xFFD97706),
      gradientTo: Color(0xFFEA580C),
      userBubbleBg: Color(0xFFD97706),
      userBubbleText: Colors.white,
      botBubbleBg: Color(0xFFF1F5F9),
      botBubbleText: Color(0xFF1E293B),
    ),
    'violet': NovaTheme(
      name: 'Violet & Fuchsia',
      primary: Color(0xFF7C3AED),
      primaryHover: Color(0xFF6D28D9),
      primaryLight: Color(0xFFF5F3FF),
      primaryText: Color(0xFF6D28D9),
      gradientFrom: Color(0xFF7C3AED),
      gradientTo: Color(0xFFD946EF),
      userBubbleBg: Color(0xFF7C3AED),
      userBubbleText: Colors.white,
      botBubbleBg: Color(0xFFF1F5F9),
      botBubbleText: Color(0xFF1E293B),
    ),
    'slate': NovaTheme(
      name: 'Slate & Charcoal',
      primary: Color(0xFF334155),
      primaryHover: Color(0xFF1E293B),
      primaryLight: Color(0xFFF1F5F9),
      primaryText: Color(0xFF1E293B),
      gradientFrom: Color(0xFF334155),
      gradientTo: Color(0xFF0F172A),
      userBubbleBg: Color(0xFF334155),
      userBubbleText: Colors.white,
      botBubbleBg: Color(0xFFF1F5F9),
      botBubbleText: Color(0xFF1E293B),
    ),
  };

  static NovaTheme fromThemeKeyOrHex(String? themeKeyOrHex, {String? customPrimary, String? customSecondary}) {
    if (customPrimary != null && customPrimary.trim().isNotEmpty) {
      final pColor = hexToColor(customPrimary);
      final sColor = customSecondary != null && customSecondary.trim().isNotEmpty
          ? hexToColor(customSecondary)
          : pColor;
      return NovaTheme(
        name: 'Custom ($customPrimary)',
        primary: pColor,
        primaryHover: pColor.withValues(alpha: 0.85),
        primaryLight: pColor.withValues(alpha: 0.08),
        primaryText: pColor,
        gradientFrom: pColor,
        gradientTo: sColor,
        userBubbleBg: pColor,
        userBubbleText: Colors.white,
        botBubbleBg: const Color(0xFFF1F5F9),
        botBubbleText: const Color(0xFF1E293B),
      );
    }

    if (themeKeyOrHex != null) {
      final key = themeKeyOrHex.toLowerCase().trim();
      if (presets.containsKey(key)) {
        return presets[key]!;
      }
      if (key.startsWith('#') || key.length == 6 || key.length == 3) {
        final pColor = hexToColor(key);
        return NovaTheme(
          name: 'Custom ($themeKeyOrHex)',
          primary: pColor,
          primaryHover: pColor.withValues(alpha: 0.85),
          primaryLight: pColor.withValues(alpha: 0.08),
          primaryText: pColor,
          gradientFrom: pColor,
          gradientTo: pColor,
          userBubbleBg: pColor,
          userBubbleText: Colors.white,
          botBubbleBg: const Color(0xFFF1F5F9),
          botBubbleText: const Color(0xFF1E293B),
        );
      }
    }

    return defaultKockatoos;
  }
}
