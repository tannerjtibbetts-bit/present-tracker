import 'package:flutter/material.dart';

Color hex(String h) => Color(int.parse('FF${h.replaceFirst('#', '')}', radix: 16));

const displayFont = 'Georgia';
const displayFallback = ['serif', 'Times New Roman', 'Noto Serif'];

TextStyle display(double size, Color color, {FontWeight weight = FontWeight.w600, FontStyle? style}) => TextStyle(
      fontFamily: displayFont,
      fontFamilyFallback: displayFallback,
      fontSize: size,
      color: color,
      fontWeight: weight,
      fontStyle: style,
      height: 1.05,
    );

/// A coloured band behind a person's name: background, text colour, and plaid (Christmas).
class Band {
  const Band(this.bg, this.ink, [this.plaid]);
  final Color bg;
  final Color ink;
  final String? plaid;
}

class Occ {
  const Occ({
    required this.key,
    required this.label,
    required this.eyebrow,
    required this.bg,
    required this.panel,
    required this.surface,
    required this.surface2,
    required this.ink,
    required this.muted,
    required this.line,
    required this.accent,
    required this.accentInk,
    required this.accent2,
    required this.accent2Ink,
    required this.gold,
    required this.bands,
    required this.motifs,
  });

  final String key, label, eyebrow;
  final Color bg, panel, surface, surface2, ink, muted, line, accent, accentInk, accent2, accent2Ink, gold;
  final List<Band> bands;
  final int motifs;

  String get scene => 'assets/art/scene_$key.svg';
  String get wall => 'assets/art/wall_$key.svg';
  String motif(int i) => 'assets/art/motif_${key}_${i % motifs}.svg';
  double get sceneAspect => key == 'christmas' ? 720 / 300 : 600 / 250;
  Band band(int i) => bands[i % bands.length];
}

const occasionOrder = ['christmas', 'birthday', 'easter', 'valentines', 'special'];

final Map<String, Occ> occasions = {
  'christmas': Occ(
    key: 'christmas', label: 'Christmas', eyebrow: 'NORTH POLE TOY WORKSHOP',
    bg: hex('#E2B985'), panel: hex('#FFF6E6'), surface: hex('#FFFDF8'), surface2: hex('#F8E9D2'),
    ink: hex('#3A1A14'), muted: hex('#7E6253'), line: hex('#EBD3B0'),
    accent: hex('#C8102E'), accentInk: hex('#FCE7A8'), accent2: hex('#1E7B4A'), accent2Ink: hex('#FCE7A8'), gold: hex('#B3202E'),
    bands: [Band(hex('#B3202E'), hex('#F7D774'), 'assets/art/plaid_red.svg'), Band(hex('#1E6B43'), hex('#F7D774'), 'assets/art/plaid_green.svg')],
    motifs: 7,
  ),
  'birthday': Occ(
    key: 'birthday', label: 'Birthdays', eyebrow: "LET'S PARTY",
    bg: hex('#F4F8FF'), panel: hex('#FFF5FA'), surface: hex('#FFFFFF'), surface2: hex('#EEF3FF'),
    ink: hex('#1F2340'), muted: hex('#646A91'), line: hex('#DCE4F6'),
    accent: hex('#FF4F86'), accentInk: hex('#FFFFFF'), accent2: hex('#2EC4B6'), accent2Ink: hex('#FFFFFF'), gold: hex('#7B5CFF'),
    bands: [Band(hex('#FF4F86'), hex('#FFFFFF')), Band(hex('#2EC4B6'), hex('#FFFFFF')), Band(hex('#FFC145'), hex('#3A2A00')), Band(hex('#7B5CFF'), hex('#FFFFFF'))],
    motifs: 5,
  ),
  'easter': Occ(
    key: 'easter', label: 'Easter', eyebrow: 'HOP INTO SPRING',
    bg: hex('#FFFBE8'), panel: hex('#FFF5CF'), surface: hex('#FFFFFF'), surface2: hex('#FFF4C9'),
    ink: hex('#3B3355'), muted: hex('#7A7393'), line: hex('#F1E6B6'),
    accent: hex('#F6C531'), accentInk: hex('#3B3355'), accent2: hex('#A8D8F0'), accent2Ink: hex('#1F3B57'), gold: hex('#C9701F'),
    bands: [Band(hex('#FFE07A'), hex('#3B3355')), Band(hex('#BFE3F5'), hex('#1F3B57')), Band(hex('#FAD1DF'), hex('#5A2440'))],
    motifs: 5,
  ),
  'valentines': Occ(
    key: 'valentines', label: "Valentine's Day", eyebrow: 'WITH LOVE',
    bg: hex('#FFF0F4'), panel: hex('#FFE1E9'), surface: hex('#FFF8FA'), surface2: hex('#FFE3EA'),
    ink: hex('#4A0F22'), muted: hex('#97596B'), line: hex('#F6CDD9'),
    accent: hex('#D7263D'), accentInk: hex('#FFFFFF'), accent2: hex('#FF9DB5'), accent2Ink: hex('#4A0F22'), gold: hex('#D7263D'),
    bands: [Band(hex('#D7263D'), hex('#FFE3EA')), Band(hex('#FFB3C6'), hex('#4A0F22')), Band(hex('#FF6F91'), hex('#FFFFFF'))],
    motifs: 5,
  ),
  'special': Occ(
    key: 'special', label: 'Special Occasions', eyebrow: 'FOR THE MOMENTS THAT MATTER',
    bg: hex('#F5F3FC'), panel: hex('#EFEBFA'), surface: hex('#FFFFFF'), surface2: hex('#EEEBF9'),
    ink: hex('#1F1D3A'), muted: hex('#6B688C'), line: hex('#DFDBF1'),
    accent: hex('#3B3486'), accentInk: hex('#FFFFFF'), accent2: hex('#F1E1AE'), accent2Ink: hex('#3B3486'), gold: hex('#B8903A'),
    bands: [Band(hex('#3B3486'), hex('#F1E1AE')), Band(hex('#F1E1AE'), hex('#3B3486'))],
    motifs: 5,
  ),
};

/// The home screen's own colours.
class HomeColors {
  static final bg = hex('#FBF8F3');
  static final ink = hex('#221C17');
  static final muted = hex('#6E665C');
  static final line = hex('#E6DED0');
  static final gold = hex('#B08A3E');
  static final accent = hex('#2C2620');
}

ThemeData occTheme(Occ o) {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: o.accent, brightness: Brightness.light).copyWith(
      primary: o.accent,
      onPrimary: o.accentInk,
      secondary: o.accent2,
      onSecondary: o.accent2Ink,
      surface: o.surface,
      onSurface: o.ink,
    ),
    scaffoldBackgroundColor: o.bg,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: o.ink, displayColor: o.ink),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: o.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: o.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: o.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: o.gold, width: 2)),
      labelStyle: TextStyle(color: o.muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: o.accent,
        foregroundColor: o.accentInk,
        minimumSize: const Size(44, 46),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: o.ink,
        backgroundColor: o.surface,
        side: BorderSide(color: o.line),
        minimumSize: const Size(44, 46),
        shape: const StadiumBorder(),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      selectedColor: o.accent,
      backgroundColor: o.surface,
      side: BorderSide(color: o.line),
      labelStyle: TextStyle(color: o.ink),
      secondaryLabelStyle: TextStyle(color: o.accentInk),
    ),
  );
}

/// The second-colour button (green at Christmas, pale blue at Easter...).
ButtonStyle altButton(Occ o) => FilledButton.styleFrom(
      backgroundColor: o.accent2,
      foregroundColor: o.accent2Ink,
      minimumSize: const Size(44, 46),
      shape: const StadiumBorder(),
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
    );
