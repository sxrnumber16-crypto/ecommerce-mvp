import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/error_state.dart';
import '../../shared/widgets/loading_state.dart';
import '../catalog/catalog_api.dart';
import '../catalog/models.dart';
import 'admin_api.dart';
import 'admin_gate.dart';

/// Create + edit form for `POST /admin/products` and
/// `PATCH /admin/products/:id`: `name`, `categoryId`, `priceBdt`,
/// `stock`, `imageUrl`, `isActive` (plus optional `slug`).
/// Edit mode also offers a deactivate button (`DELETE` soft-sets
/// `isActive=false`). Guarded by [AdminGate].
class ProductEditorScreen extends ConsumerStatefulWidget {
  /// `null` → create mode; otherwise edit `GET /products/:id`.
  final int? productId;

  const ProductEditorScreen({super.key, this.productId});

  @override
  ConsumerState<ProductEditorScreen> createState() =>
      _ProductEditorScreenState();
}

class _ProductEditorScreenState extends ConsumerState<ProductEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _slug = TextEditingController();
  final _price = TextEditingController();
  final _stock = TextEditingController();
  final _imageUrl = TextEditingController();
  final _description = TextEditingController();
  int? _categoryId;
  bool _isActive = true;
  bool _loading = false;
  bool _saving = false;
  bool _catTouched = false;
  String? _loadError;
  Product? _product;

  bool get _isEdit => widget.productId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _price.dispose();
    _stock.dispose();
    _imageUrl.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final p =
          await ref.read(catalogApiProvider).product(widget.productId!);
      _product = p;
      _name.text = p.name;
      _slug.text = p.slug;
      _price.text = '${p.priceBdt}';
      _stock.text = '${p.stock}';
      _imageUrl.text = p.imageUrl ?? '';
      _description.text = p.description;
      _categoryId = p.categoryId;
      _isActive = p.isActive;
    } catch (e) {
      _loadError = friendlyError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _body() {
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'categoryId': _categoryId,
      'priceBdt': int.tryParse(_price.text.trim()) ?? 0,
      'stock': int.tryParse(_stock.text.trim()) ?? 0,
      'description': _description.text.trim(),
      'isActive': _isActive,
    };
    if (_imageUrl.text.trim().isNotEmpty) {
      body['imageUrl'] = _imageUrl.text.trim();
    } else if (_isEdit) {
      body['imageUrl'] = '';
    }
    // Omit slug on create when blank so the backend auto-generates it;
    // on edit only send when changed.
    final slug = _slug.text.trim();
    if (!_isEdit) {
      if (slug.isNotEmpty) body['slug'] = slug;
    } else if (slug.isNotEmpty && slug != _product?.slug) {
      body['slug'] = slug;
    }
    return body;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      setState(() => _catTouched = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('ক্যাটাগরি বেছে নিন / Pick a category')));
      return;
    }
    setState(() => _saving = true);
    try {
      final api = ref.read(adminApiProvider);
      if (_isEdit) {
        await api.updateProduct(widget.productId!, _body());
      } else {
        await api.createProduct(_body());
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('সফলভাবে সংরক্ষিত / Saved')));
      context.pop();
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deactivate() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('নিষ্ক্রিয় করবেন? / Deactivate?'),
        content: const Text(
            'পণ্যটি দোকান থেকে লুকানো হবে (soft delete)। / The product will be hidden from the shop.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('বাতিল / Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('নিষ্ক্রিয় / Deactivate')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _saving = true);
    try {
      await ref.read(adminApiProvider).deactivateProduct(widget.productId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('নিষ্ক্রিয় করা হয়েছে / Deactivated')));
      context.pop();
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminGate(
      fallback: const AdminDenied(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEdit
              ? 'পণ্য সম্পাদনা / Edit product'
              : 'নতুন পণ্য / New product'),
        ),
        body: _loading
            ? const LoadingState()
            : _loadError != null
                ? ErrorState(message: _loadError!, onRetry: _load)
                : FutureBuilder<List<Category>>(
                    future: ref.read(catalogApiProvider).categories(),
                    builder: (context, snapshot) {
                      final cats = snapshot.data ?? const <Category>[];
                      return Form(
                        key: _formKey,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            TextFormField(
                              controller: _name,
                              decoration: const InputDecoration(
                                  labelText: 'নাম / Name'),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty
                                      ? 'নাম দিন / Name required'
                                      : null,
                            ),
                            const SizedBox(height: 12),
                            InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'ক্যাটাগরি / Category',
                                errorText: _catTouched && _categoryId == null
                                    ? 'ক্যাটাগরি বেছে নিন / Pick a category'
                                    : null,
                              ),
                              child: DropdownButton<int>(
                                value: cats.any((c) => c.id == _categoryId)
                                    ? _categoryId
                                    : null,
                                isExpanded: true,
                                underline: const SizedBox.shrink(),
                                hint: const Text(
                                    'ক্যাটাগরি বেছে নিন / Pick a category'),
                                items: cats
                                    .map((c) => DropdownMenuItem(
                                        value: c.id,
                                        child: Text(c.name)))
                                    .toList(),
                                onChanged: (v) => setState(() {
                                  _categoryId = v;
                                  _catTouched = true;
                                }),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _price,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                        labelText: 'দাম (৳) / Price'),
                                    validator: (v) {
                                      final n = int.tryParse(v?.trim() ?? '');
                                      if (n == null || n < 1) {
                                        return 'সঠিক দাম দিন / Valid price required';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _stock,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                        labelText: 'স্টক / Stock'),
                                    validator: (v) {
                                      final n = int.tryParse(v?.trim() ?? '');
                                      if (n == null || n < 0) {
                                        return 'সঠিক স্টক দিন / Valid stock required';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _imageUrl,
                              keyboardType: TextInputType.url,
                              decoration: const InputDecoration(
                                labelText: 'ছবির URL / Image URL',
                                hintText: 'https://… (optional)',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _slug,
                              decoration: const InputDecoration(
                                labelText: 'Slug (optional)',
                                hintText: 'blank = auto-generate',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _description,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                  labelText: 'বিবরণ / Description'),
                            ),
                            SwitchListTile(
                              title:
                                  const Text('সক্রিয় / Active'),
                              value: _isActive,
                              onChanged: (v) =>
                                  setState(() => _isActive = v),
                            ),
                            const SizedBox(height: 8),
                            FilledButton(
                              onPressed: _saving ? null : _save,
                              child: Text(_saving
                                  ? 'সংরক্ষণ হচ্ছে… / Saving…'
                                  : 'সংরক্ষণ / Save'),
                            ),
                            if (_isEdit) ...[
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: _saving ? null : _deactivate,
                                icon: const Icon(Icons.visibility_off_outlined),
                                label: const Text(
                                    'নিষ্ক্রিয় / Deactivate (soft delete)'),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
