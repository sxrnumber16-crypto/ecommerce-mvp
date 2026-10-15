import 'package:flutter/material.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_space.dart';

/// Primary action button with a 52dp minimum height and pill shape.
///
/// Filled with the theme primary (electric-blue) color by default; [outlined] renders
/// an outlined variant. While [loading] the button is disabled and
/// shows a spinner next to the label.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.outlined = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.pill),
    );
    const minSize = Size(64, 52);
    const padding = EdgeInsets.symmetric(
      horizontal: AppSpace.xl,
      vertical: AppSpace.m,
    );
    final VoidCallback? effectiveOnPressed = loading ? null : onPressed;

    Widget child = Text(label);
    if (loading) {
      final spinnerColor = outlined ? scheme.primary : scheme.onPrimary;
      child = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(spinnerColor),
            ),
          ),
          const SizedBox(width: AppSpace.s),
          Text(label),
        ],
      );
    }

    if (outlined) {
      return OutlinedButton(
        onPressed: effectiveOnPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: minSize,
          padding: padding,
          shape: shape,
          side: BorderSide(color: scheme.primary),
          foregroundColor: scheme.primary,
        ),
        child: child,
      );
    }
    return ElevatedButton(
      onPressed: effectiveOnPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: minSize,
        padding: padding,
        shape: shape,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
      child: child,
    );
  }
}
