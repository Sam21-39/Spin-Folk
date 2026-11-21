import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

abstract final class Tokens {
  static const Color bgBase = Color(0xFF0B1424);
  static const Color bgSurface = Color(0xFF121E33);
  static const Color bgRaised = Color(0xFF1A2A45);
  static const Color bgSheet = Color(0xFF0F192C);
  static const Color line = Color(0xFF2A3B5E);
  static const Color dot = Color(0xFF3A4D74);
  static const Color taker = Color(0xFF2DD4BF);
  static const Color giver = Color(0xFFFF7A59);
  static const Color textPrimary = Color(0xFFF2F5FA);
  static const Color textSecondary = Color(0xFFA9B6CC);
  static const Color textTertiary = Color(0xFF8191AB);
  static const Color bottleFill = Color(0x29DDE6F2); // 0.16
  static const Color bottleStroke = Color(0xBFE8EEF7); // 0.75
  static const Color scrim = Color(0x80000000);

  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s48 = 48;
  static const double margin = 20;

  static const double r12 = 12;
  static const double r20 = 20;
  static const double r28 = 28;

  static const Duration panelEnter = Duration(milliseconds: 320);
  static const Duration reducedSpin = Duration(milliseconds: 600);
  static const Duration pulse = Duration(milliseconds: 1200);
  static const Cubic spinCurve = Cubic(0.15, 0.60, 0.10, 1.00);

  static const double touch = 44;
  static const double barPrimary = 64;
  static const double barSecondary = 50;
  static const double barGap = 10;
  static const double passWidth = 104;
  static const double pickerHeight = 216;
  static const double maxContentWidth = 480;

  static const TextStyle largeTitle = TextStyle(
    color: textPrimary,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );
  static const TextStyle title2 = TextStyle(
    color: textPrimary,
    fontSize: 22,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle headline = TextStyle(
    color: textPrimary,
    fontSize: 17,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle body = TextStyle(color: textPrimary, fontSize: 17);
  static const TextStyle subhead = TextStyle(
    color: textSecondary,
    fontSize: 15,
  );
  static const TextStyle footnote = TextStyle(
    color: textTertiary,
    fontSize: 13,
  );
  static const TextStyle caption = TextStyle(
    color: textPrimary,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.3,
  );

  /// The only place Nunito is named.
  static TextStyle numeral(double size, {Color color = textPrimary}) =>
      TextStyle(
        color: color,
        fontSize: size,
        fontFamily: 'Nunito',
        fontWeight: FontWeight.w800,
        fontVariations: const [FontVariation('wght', 800)],
        fontFeatures: const [FontFeature.tabularFigures()],
        height: 1.15,
      );
}
