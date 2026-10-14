import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_space.dart';
import '../tokens/app_text.dart';
import 'app_button.dart';

Color _muted(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkMuted
        : AppColors.lightMuted;

/// Two-column shimmer placeholder grid (6 cells) for loading states.
class LoadingGrid extends StatelessWidget {
  const LoadingGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpace.m,
        crossAxisSpacing: AppSpace.m,
        childAspectRatio: 0.7,
      ),
      itemCount: 6,
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: scheme.surfaceContainerHighest,
        highlightColor: scheme.surface,
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
        ),
      ),
    );
  }
}

/// Centered empty state with an optional action button.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: _muted(context),
            ),
            const SizedBox(height: AppSpace.m),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppText.body(context)
                  .copyWith(color: _muted(context)),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: AppSpace.l),
              AppButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

/// Centered error state with an 'আবার চেষ্টা / Retry' button.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: AppSpace.m),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppText.body(context)
                  .copyWith(color: _muted(context)),
            ),
            const SizedBox(height: AppSpace.l),
            AppButton(
              label: 'আবার চেষ্টা / Retry',
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
