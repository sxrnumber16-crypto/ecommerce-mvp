import 'package:flutter/material.dart';

abstract final class AppShadow {
  static const card = [
    BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 6)),
  ];
  static const sheet = [
    BoxShadow(color: Color(0x29000000), blurRadius: 24, offset: Offset(0, -6)),
  ];
}
