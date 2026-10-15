import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/components/app_button.dart';
import '../../design/components/app_card.dart';
import '../../design/components/app_chip.dart';
import '../../design/components/app_input.dart';
import '../../design/components/state_views.dart';
import '../../design/tokens/app_colors.dart';
import '../../design/tokens/app_space.dart';
import '../../design/tokens/app_text.dart';
import '../../shared/widgets/error_state.dart' show friendlyError;
import 'address_api.dart';

/// Address step navy restyle (Orvix dark-navy concept).
///
/// Data flow is identical to the legacy screen: `GET /addresses` list
/// with the default (server-ordered first) pre-selected, `POST
/// /addresses` form (`label`/`line1`/`city`/`phone`, `postal` optional),
/// and continue via `push('/cart/checkout?addressId=<id>')`. The
/// [RadioGroup]/[RadioListTile] selection pattern is kept (blue active
/// states via tokens). New look only: address [AppCard]s, an [AppCard]
/// form with [AppInput] fields, and blue [AppButton] actions.
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
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorView(
              message: friendlyError(snapshot.error!),
              onRetry: _reload,
            );
          }
          final addresses = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(AppSpace.l),
            children: [
              Text('ঠিকানা বেছে নিন / Choose address',
                  style: AppText.title(context)),
              const SizedBox(height: AppSpace.s),
              if (addresses.isEmpty)
                const EmptyView(
                  message:
                      'কোনো ঠিকানা নেই — নিচে যোগ করুন / No addresses yet',
                )
              else
                RadioGroup<int>(
                  groupValue: _selectedId,
                  onChanged: (v) => setState(() => _selectedId = v),
                  child: Column(
                    children: [
                      for (final a in addresses)
                        Padding(
                          padding: const EdgeInsets.only(
                              bottom: AppSpace.s),
                          child: AppCard(
                            child: RadioListTile<int>(
                              value: a.id,
                              activeColor: AppColors.seed,
                              title: Text(
                                '${a.label} — ${a.line1}',
                                style: AppText.title(context),
                              ),
                              subtitle: Text(
                                '${a.city}${a.postal != null ? ' ${a.postal}' : ''} • ${a.phone}',
                                style: AppText.body(context),
                              ),
                              secondary: a.isDefault
                                  ? const AppChip(
                                      label: 'ডিফল্ট / Default',
                                      selected: true,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpace.m),
              Text('নতুন ঠিকানা / New address',
                  style: AppText.title(context)),
              const SizedBox(height: AppSpace.s),
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.l),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppInput(
                          controller: _label,
                          label: 'লেবেল / Label (home)',
                        ),
                        const SizedBox(height: AppSpace.m),
                        AppInput(
                          controller: _line1,
                          label: 'ঠিকানা / Line 1',
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? 'ঠিকানা দিন / Enter street address'
                              : null,
                        ),
                        const SizedBox(height: AppSpace.m),
                        AppInput(
                          controller: _city,
                          label: 'শহর / City',
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? 'শহর দিন / Enter city'
                              : null,
                        ),
                        const SizedBox(height: AppSpace.m),
                        AppInput(
                          controller: _postal,
                          label: 'পোস্টাল / Postal (optional)',
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: AppSpace.m),
                        AppInput(
                          controller: _phone,
                          label: 'ফোন / Phone',
                          keyboardType: TextInputType.phone,
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? 'ফোন দিন / Enter phone'
                              : null,
                        ),
                        CheckboxListTile(
                          value: _isDefault,
                          activeColor: AppColors.seed,
                          onChanged: (v) =>
                              setState(() => _isDefault = v ?? false),
                          title:
                              const Text('ডিফল্ট করুন / Make default'),
                          contentPadding: EdgeInsets.zero,
                        ),
                        AppButton(
                          label: 'ঠিকানা যোগ করুন / Add address',
                          loading: _saving,
                          onPressed: _saving ? null : _add,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.l),
              AppButton(
                label: 'এগিয়ে যান / Continue',
                onPressed: _selectedId == null
                    ? null
                    : () => context
                        .push('/cart/checkout?addressId=$_selectedId'),
              ),
            ],
          );
        },
      ),
    );
  }
}
