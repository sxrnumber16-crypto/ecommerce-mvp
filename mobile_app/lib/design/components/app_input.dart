import 'package:flutter/material.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_space.dart';

/// Text input with an [AppRadius.card] outline border.
///
/// Border colors and text styles come from the app theme; spacing
/// and radius use [AppSpace]/[AppRadius] tokens only.
class AppInput extends StatelessWidget {
  const AppInput({
    super.key,
    this.controller,
    this.label,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  final TextEditingController? controller;
  final String? label;
  final bool obscure;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.card);
    OutlineInputBorder border() =>
        OutlineInputBorder(borderRadius: radius);
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.l,
          vertical: AppSpace.m,
        ),
        border: border(),
        enabledBorder: border(),
        focusedBorder: border(),
      ),
    );
  }
}
