import 'package:flutter/material.dart';

import '../tokens/app_radius.dart';
import '../tokens/app_shadow.dart';

/// Surface card with card radius and a soft shadow.
///
/// Has no internal padding so content (e.g. images) can bleed to the
/// card edges; callers add their own padding. Wraps [child] in an
/// [InkWell] when [onTap] is given.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppRadius.card);
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: radius,
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.25),
          width: 1,
        ),
        boxShadow: AppShadow.card,
      ),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: radius,
        child: onTap == null
            ? child
            : InkWell(onTap: onTap, child: child),
      ),
    );
  }
}
