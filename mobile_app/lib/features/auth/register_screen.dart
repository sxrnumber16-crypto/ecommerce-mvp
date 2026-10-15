import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_store.dart';
import '../../core/config.dart';
import '../../design/components/app_button.dart';
import '../../design/components/app_input.dart';
import '../../design/components/app_scaffold.dart';
import '../../design/tokens/app_colors.dart';
import '../../design/tokens/app_radius.dart';
import '../../design/tokens/app_space.dart';
import '../../design/tokens/app_text.dart';

bool _isValidEmail(String v) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());

/// `POST /auth/register` via [AuthStore] (backend requires password ≥ 8).
/// Bilingual validation + errors, loading state from `AuthState.isLoading`.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _fullName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final ok = await ref.read(authStoreProvider.notifier).register(
          email: _email.text.trim(),
          password: _password.text,
          fullName:
              _fullName.text.trim().isEmpty ? null : _fullName.text.trim(),
          phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        );
    if (ok && mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStoreProvider);
    final scheme = Theme.of(context).colorScheme;
    return AppScaffold(
      title: 'রেজিস্টার / Register',
      body: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpace.xl),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.navyCard, AppColors.seed],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.person_add_outlined,
                      size: 40,
                      color: scheme.onPrimary,
                    ),
                    const SizedBox(height: AppSpace.m),
                    Text(
                      Config.storeName,
                      style: AppText.headline(context).copyWith(
                        color: scheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpace.s),
                    Text(
                      'নতুন অ্যাকাউন্ট খুলুন / Join us',
                      style: AppText.body(context).copyWith(
                        color: scheme.onPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.xl),
              AppInput(
                controller: _fullName,
                label: 'নাম / Full name (optional)',
              ),
              const SizedBox(height: AppSpace.l),
              AppInput(
                controller: _email,
                label: 'ইমেইল / Email',
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                validator: (v) => _isValidEmail(v ?? '')
                    ? null
                    : 'সঠিক ইমেইল দিন / Enter a valid email',
              ),
              const SizedBox(height: AppSpace.l),
              AppInput(
                controller: _phone,
                label: 'ফোন / Phone (optional)',
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
              ),
              const SizedBox(height: AppSpace.l),
              AppInput(
                controller: _password,
                label: 'পাসওয়ার্ড / Password (≥ 8)',
                obscure: _obscure,
                autofillHints: const [AutofillHints.newPassword],
                suffixIcon: IconButton(
                  icon: Icon(_obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
                validator: (v) => (v ?? '').length < 8
                    ? 'কমপক্ষে ৮ অক্ষর / At least 8 characters'
                    : null,
              ),
              if (auth.error != null) ...[
                const SizedBox(height: AppSpace.m),
                Text(
                  auth.error!,
                  style: TextStyle(color: scheme.error),
                ),
              ],
              const SizedBox(height: AppSpace.xl),
              AppButton(
                label: 'রেজিস্টার / Register',
                loading: auth.isLoading,
                onPressed: _submit,
              ),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text(
                    'অ্যাকাউন্ট আছে? লগইন করুন / Have an account? Log in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
