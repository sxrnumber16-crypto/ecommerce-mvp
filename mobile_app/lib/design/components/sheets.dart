import 'package:flutter/material.dart';

import '../tokens/app_radius.dart';
import '../tokens/app_space.dart';
import '../tokens/app_text.dart';
import 'app_button.dart';

/// Generic rounded-top sheet wrapper. Screen-specific sheet content
/// (Tasks 5-8) is built by the [child] passed in.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required Widget child,
}) {
  return showModalBottomSheet<T>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.sheet),
      ),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.l),
        child: child,
      ),
    ),
  );
}

/// Quantity picker sheet. Returns the picked int via pop,
/// or null when dismissed.
Future<int?> showQtySheet(
  BuildContext context, {
  required int initial,
  int max = 10,
}) {
  return showAppSheet<int>(
    context,
    child: _QtySheetBody(initial: initial, max: max),
  );
}

class _QtySheetBody extends StatefulWidget {
  const _QtySheetBody({required this.initial, required this.max});

  final int initial;
  final int max;

  @override
  State<_QtySheetBody> createState() => _QtySheetBodyState();
}

class _QtySheetBodyState extends State<_QtySheetBody> {
  late int _qty;

  @override
  void initState() {
    super.initState();
    final max = widget.max < 1 ? 1 : widget.max;
    _qty = widget.initial.clamp(1, max).toInt();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final max = widget.max < 1 ? 1 : widget.max;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.m),
        Text(
          'পরিমাণ / Quantity',
          textAlign: TextAlign.center,
          style: AppText.title(context),
        ),
        const SizedBox(height: AppSpace.m),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            SizedBox(
              width: 48,
              child: Text(
                '$_qty',
                textAlign: TextAlign.center,
                style: AppText.headline(context),
              ),
            ),
            IconButton(
              onPressed:
                  _qty < max ? () => setState(() => _qty++) : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.l),
        AppButton(
          label: 'নিশ্চিত / Confirm',
          onPressed: () => Navigator.of(context).pop(_qty),
        ),
      ],
    );
  }
}
