import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_state.dart';
import '../../shared/widgets/loading_state.dart';
import 'address_api.dart';

/// Address step: `GET /addresses` list with default pre-selected +
/// `POST /addresses` form (`label`/`line1`/`city`/`phone`, `postal` optional).
/// Continue pushes `/cart/checkout?addressId=<id>`.
class AddressScreen extends ConsumerStatefulWidget {
  const AddressScreen({super.key});

  @override
  ConsumerState<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends ConsumerState<AddressScreen> {
  late Future<List<Address>> _future;
  int? _selectedId;

  final _form = GlobalKey<FormState>();
  final _label = TextEditingController(text: 'home');
  final _line1 = TextEditingController();
  final _city = TextEditingController();
  final _postal = TextEditingController();
  final _phone = TextEditingController();
  bool _isDefault = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _label.dispose();
    _line1.dispose();
    _city.dispose();
    _postal.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<List<Address>> _load() async {
    final addresses = await ref.read(addressApiProvider).list();
    // Server orders isDefault first; pre-select it.
    if (_selectedId == null && addresses.isNotEmpty) {
      _selectedId = addresses.first.id;
    }
    return addresses;
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _add() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final created = await ref.read(addressApiProvider).create(
            label: _label.text.trim().isEmpty ? 'home' : _label.text.trim(),
            line1: _line1.text.trim(),
            city: _city.text.trim(),
            postal: _postal.text.trim().isEmpty ? null : _postal.text.trim(),
            phone: _phone.text.trim(),
            isDefault: _isDefault,
          );
      _line1.clear();
      _city.clear();
      _postal.clear();
      _phone.clear();
      setState(() {
        _selectedId = created.id;
        _isDefault = false;
        _future = _load();
        _saving = false;
      });
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ঠিকানা / Address')),
      body: FutureBuilder<List<Address>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingState();
          }
          if (snapshot.hasError) {
            return ErrorState(
              message: friendlyError(snapshot.error!),
              onRetry: _reload,
            );
          }
          final addresses = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('ঠিকানা বেছে নিন / Choose address',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (addresses.isEmpty)
                const EmptyState(
                  message: 'কোনো ঠিকানা নেই — নিচে যোগ করুন / No addresses yet',
                  icon: Icons.location_on_outlined,
                )
                else
                  RadioGroup<int>(
                    groupValue: _selectedId,
                    onChanged: (v) => setState(() => _selectedId = v),
                    child: Column(
                      children: [
                        for (final a in addresses)
                          RadioListTile<int>(
                            value: a.id,
                            title: Text('${a.label} — ${a.line1}'),
                            subtitle: Text(
                                '${a.city}${a.postal != null ? ' ${a.postal}' : ''} • ${a.phone}'),
                            secondary: a.isDefault
                                ? const Chip(
                                    label: Text('ডিফল্ট / Default'))
                                : null,
                          ),
                      ],
                    ),
                  ),
              const Divider(height: 32),
              Text('নতুন ঠিকানা / New address',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Form(
                key: _form,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _label,
                      decoration: const InputDecoration(
                        labelText: 'লেবেল / Label (home)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _line1,
                      decoration: const InputDecoration(
                        labelText: 'ঠিকানা / Line 1',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? 'ঠিকানা দিন / Enter street address'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _city,
                      decoration: const InputDecoration(
                        labelText: 'শহর / City',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? 'শহর দিন / Enter city'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _postal,
                      decoration: const InputDecoration(
                        labelText: 'পোস্টাল / Postal (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'ফোন / Phone',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? 'ফোন দিন / Enter phone'
                          : null,
                    ),
                    CheckboxListTile(
                      value: _isDefault,
                      onChanged: (v) =>
                          setState(() => _isDefault = v ?? false),
                      title: const Text('ডিফল্ট করুন / Make default'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    FilledButton.tonal(
                      onPressed: _saving ? null : _add,
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('ঠিকানা যোগ করুন / Add address'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _selectedId == null
                    ? null
                    : () => context
                        .push('/cart/checkout?addressId=$_selectedId'),
                child: const Text('এগিয়ে যান / Continue'),
              ),
            ],
          );
        },
      ),
    );
  }
}
