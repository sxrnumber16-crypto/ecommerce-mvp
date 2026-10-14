import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_store.dart';
import '../../core/config.dart';
import '../../design/components/app_button.dart';
import '../../design/components/app_input.dart';
import '../../design/components/app_scaffold.dart';
import '../../design/tokens/app_radius.dart';
import '../../design/tokens/app_space.dart';
import '../../design/tokens/app_text.dart';

bool _isValidEmail(String v) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());

/// `POST /auth/login` via [AuthStore]. Bilingual validation + errors,
/// loading state from `AuthState.isLoading`.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final ok = await ref.read(authStoreProvider.notifier).login(
          email: _email.text.trim(),
          password: _password.text,
        );
    if (ok && mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStoreProvider);
    final scheme = Theme.of(context).colorScheme;
    return AppScaffold(
      title: 'লগইন / Login',
      body: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpace.xl),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [scheme.primary, scheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.storefront_outlined,
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
                      'স্বাগতম / Welcome back',
                      style: AppText.body(context).copyWith(
                        color: scheme.onPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.xl),
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
                controller: _password,
                label: 'পাসওয়ার্ড / Password',
                obscure: _obscure,
                autofillHints: const [AutofillHints.password],
                suffixIcon: IconButton(
                  icon: Icon(_obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
                validator: (v) => (v ?? '').isEmpty
                    ? 'পাসওয়ার্ড দিন / Enter your password'
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
                label: 'লগইন / Login',
                loading: auth.isLoading,
                onPressed: _submit,
              ),
              TextButton(
                onPressed: () => context.go('/register'),
                child: const Text(
                    'অ্যাকাউন্ট নেই? রেজিস্টার করুন / Create account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
