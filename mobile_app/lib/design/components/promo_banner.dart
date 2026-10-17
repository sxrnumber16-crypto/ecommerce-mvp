import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_space.dart';
import '../tokens/app_text.dart';

class PromoBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final String ctaLabel;
  final VoidCallback? onCta;
  final String? imageUrl;

  const PromoBanner(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.ctaLabel,
      this.onCta,
      this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        gradient: const LinearGradient(
          colors: [AppColors.navyCard, AppColors.seed],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          if (imageUrl != null && imageUrl!.isNotEmpty)
            Positioned(
              right: 0, top: 0, bottom: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (c, u, e) => const SizedBox.shrink(),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AppSpace.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title,
                    style: AppText.headline(context)
                        .copyWith(color: Colors.white)),
                const SizedBox(height: AppSpace.xs),
                Text(subtitle,
                    style: AppText.body(context)
                        .copyWith(color: Colors.white70)),
                const SizedBox(height: AppSpace.s),
                ElevatedButton(
                  onPressed: onCta,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.seed,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.pill)),
                  ),
                  child: Text(ctaLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
