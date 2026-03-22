import 'package:flutter/material.dart';

class FotoColors {
  static const background  = Color(0xFFF7F5FB);
  static const surface     = Color(0xFFFFFFFF);
  static const surfaceAlt  = Color(0xFFF0EDF8);
  static const divider     = Color(0xFFEDE9F5);

  static const textPrimary   = Color(0xFF1E1830);
  static const textSecondary = Color(0xFF8B7FA8);
  static const textHint      = Color(0xFFB8AECF);

  static const up    = Color(0xFF5BAF82);
  static const down  = Color(0xFFD97070);
  static const left  = Color(0xFFD4924A);
  static const right = Color(0xFF5A8FCC);

  static const upBg    = Color(0xFFEAF6F0);
  static const downBg  = Color(0xFFFAECEC);
  static const leftBg  = Color(0xFFFAF1E6);
  static const rightBg = Color(0xFFE8EFF8);

  static const List<Color> dirs   = [up, down, left, right];
  static const List<Color> dirBgs = [upBg, downBg, leftBg, rightBg];

  static const warning = Color(0xFFD4924A);
  static const error   = Color(0xFFD97070);
}

class FotoText {
  static const display = TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: FotoColors.textPrimary, height: 1.3);
  static const title   = TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: FotoColors.textPrimary, height: 1.3);
  static const body    = TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: FotoColors.textPrimary, height: 1.5);
  static const caption = TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: FotoColors.textSecondary, height: 1.5);
  static const micro   = TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: FotoColors.textHint, height: 1.4);
}

class FotoSpacing {
  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 16;
  static const double lg  = 24;
  static const double xl  = 32;
  static const double xxl = 48;
}

class FotoRadius {
  static const double sm  = 6;
  static const double md  = 10;
  static const double lg  = 12;
  static const double xl  = 16;
  static const card   = BorderRadius.all(Radius.circular(lg));
  static const button = BorderRadius.all(Radius.circular(md));
  static const chip   = BorderRadius.all(Radius.circular(sm));
}

const kCardShadow = [
  BoxShadow(color: Color(0x0F1E1830), blurRadius: 8, offset: Offset(0, 2)),
];
const kElevatedShadow = [
  BoxShadow(color: Color(0x1A1E1830), blurRadius: 16, offset: Offset(0, 4)),
];
