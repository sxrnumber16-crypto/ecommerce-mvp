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
    this.suffixIcon,
    this.autofillHints,
  });

  final TextEditingController? controller;
  final String? label;
  final bool obscure;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppRadius.card);
    OutlineInputBorder border({Color? color}) => OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: color ?? scheme.outline),
        );
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      autofillHints: autofillHints,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.l,
          vertical: AppSpace.m,
        ),
        border: border(),
        enabledBorder: border(),
        focusedBorder: border(color: scheme.primary),
      ),
    );
  }
}
