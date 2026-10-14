import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../catalog/models.dart';

/// One cart line: a product snapshot (for offline-friendly display) + qty.
///
/// Prices shown from the snapshot are a preview only — the server
/// recalculates `subtotal`/`deliveryFee`/`total` at `POST /checkout`.
class CartLine {
  final Product product;
  final int qty;

  const CartLine({required this.product, required this.qty});

  CartLine copyWith({Product? product, int? qty}) =>
      CartLine(product: product ?? this.product, qty: qty ?? this.qty);
}

/// Local cart state. Backend caps checkout qty at 10 per item, so adds and
/// edits clamp to `[1, min(stock, 10)]`.
class CartStore extends StateNotifier<List<CartLine>> {
  CartStore() : super(const []);

  /// Total unit count for the bottom-nav badge.
  int get count => state.fold(0, (sum, l) => sum + l.qty);

  static int clampQty(Product product, int qty) {
    final cap = product.stock >= 10 ? 10 : product.stock;
    if (cap < 1) return 0;
    return qty.clamp(1, cap);
  }

  void add(Product product, int qty) {
    if (!product.inStock) return;
    final idx = state.indexWhere((l) => l.product.id == product.id);
    if (idx == -1) {
      final q = clampQty(product, qty);
      if (q < 1) return;
      state = [...state, CartLine(product: product, qty: q)];
    } else {
      final q = clampQty(product, state[idx].qty + qty);
      state = [
        for (var i = 0; i < state.length; i++)
          if (i == idx) state[i].copyWith(product: product, qty: q) else state[i],
      ];
    }
  }

  void setQty(int productId, int qty) {
    final idx = state.indexWhere((l) => l.product.id == productId);
    if (idx == -1) return;
    final q = clampQty(state[idx].product, qty);
    if (q < 1) {
      remove(productId);
      return;
    }
    state = [
      for (var i = 0; i < state.length; i++)
        if (i == idx) state[i].copyWith(qty: q) else state[i],
    ];
  }

  void remove(int productId) {
    state = state.where((l) => l.product.id != productId).toList();
  }

  void clear() => state = const [];
}

final cartStoreProvider =
    StateNotifierProvider<CartStore, List<CartLine>>((ref) => CartStore());

/// Badge count selector for the bottom nav.
final cartCountProvider = Provider<int>((ref) {
  return ref.watch(cartStoreProvider).fold(0, (sum, l) => sum + l.qty);
});
