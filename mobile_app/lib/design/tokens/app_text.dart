import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppText {
  static TextStyle display(BuildContext context) =>
      GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w700);
  static TextStyle headline(BuildContext context) =>
      GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w700);
  static TextStyle title(BuildContext context) =>
      GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600);
  static TextStyle body(BuildContext context) =>
      GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w400);
  static TextStyle label(BuildContext context) =>
      GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w500);
  static TextStyle price(BuildContext context) =>
      GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800);
}
