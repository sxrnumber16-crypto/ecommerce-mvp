import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/config.dart';
import '../../features/catalog/models.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_space.dart';
import '../tokens/app_text.dart';
import 'app_card.dart';

/// v2 product tile built on [AppCard] (the legacy
/// `shared/widgets/product_card.dart` stays: it is still imported by
/// `mobile_app/test/widget_test.dart`, so Task 8 keeps it).
///
/// Image bleeds to the card edges; [Config.bdt] price in primary color.
/// Taps navigate to `/product/:id`. The wishlist heart is local-only
/// ([wished]/[onWish], no backend calls). A null/empty [Product.imageUrl]
/// renders the error icon instead of attempting a network fetch.
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.wished = false,
    this.onWish,
  });

  final Product product;
  final bool wished;
  final VoidCallback? onWish;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = product.imageUrl?.trim() ?? '';
    final inStock = product.inStock;
    final lowStock = inStock && product.stock <= 5;
    final badgeLabel = !inStock
        ? 'স্টক নেই / Out'
        : lowStock
            ? 'কম স্টক / Low'
            : 'স্টক আছে / In stock';
    final badgeColor = !inStock
        ? AppColors.error
        : lowStock
            ? AppColors.price
            : AppColors.success;
    return AppCard(
      onTap: () => context.go('/product/${product.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: url.isEmpty
                    ? Container(
                        color: scheme.surfaceContainerHighest,
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          size: 48,
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Shimmer.fromColors(
                          baseColor: scheme.surfaceContainerHighest,
                          highlightColor: scheme.surface,
                          child: Container(
                            color: scheme.surfaceContainerHighest,
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: scheme.surfaceContainerHighest,
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            size: 48,
                          ),
                        ),
                      ),
              ),
              Positioned(
                top: AppSpace.s,
                right: AppSpace.s,
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius:
                        BorderRadius.circular(AppRadius.pill),
                  ),
                  child: IconButton(
                    iconSize: 20,
                    onPressed: onWish,
                    tooltip: wished
                        ? 'উইশলিস্টে আছে / Wishlisted'
                        : 'উইশলিস্ট / Wishlist',
                    icon: Icon(
                      wished ? Icons.favorite : Icons.favorite_border,
                    ),
                    color: wished ? AppColors.error : scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpace.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.title(context),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  Config.bdt(product.priceBdt),
                  style: AppText.price(context)
                      .copyWith(color: scheme.primary),
                ),
                const SizedBox(height: AppSpace.s),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s,
                    vertical: AppSpace.xs,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius:
                        BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    badgeLabel,
                    style: AppText.label(context).copyWith(
                      color: badgeColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
