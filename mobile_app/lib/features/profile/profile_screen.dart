import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_store.dart';
import '../../design/components/app_button.dart';
import '../../design/components/app_card.dart';
import '../../design/components/app_input.dart';
import '../../design/components/state_views.dart';
import '../../design/tokens/app_colors.dart';
import '../../design/tokens/app_radius.dart';
import '../../design/tokens/app_space.dart';
import '../../design/tokens/app_text.dart';
import '../../shared/widgets/error_state.dart' show friendlyError;
import 'profile_api.dart';

/// Profile tab navy restyle (Orvix dark-navy concept): `GET /profile`
/// (name/phone), `PATCH /profile` edit, logout.
///
/// Data flow is identical to the legacy screen: one
/// `profileApiProvider.get()` future, `_reload` on retry, controller
/// prefill from [ProfileData], `patch(fullName:, phone:)` with the
/// same validator/messages/SnackBars, admin gating via
/// `authStoreProvider.isAdmin` → `go('/admin')`, and logout via
/// `authStoreProvider.notifier.logout()` → `go('/login')`. Bilingual
/// copy verbatim. New look only: navy identity header [AppCard],
/// menu-row [AppCard] (orders/admin/edit rows route exactly as before),
/// an appearance row that reflects the existing system-following theme
/// (no new ThemeMode mechanism invented — see [_ThemeRow]), an edit
/// form with [AppInput]s, and a blue [AppButton] logout. Blue accents
/// via tokens.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late Future<ProfileData> _future;
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = ref.read(profileApiProvider).get();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _reload() =>
      setState(() => _future = ref.read(profileApiProvider).get());

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final updated = await ref.read(profileApiProvider).patch(
            fullName: _name.text.trim().isEmpty ? null : _name.text.trim(),
            phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          );
      _name.text = updated.fullName ?? '';
      _phone.text = updated.phone ?? '';
      if (mounted) {
        setState(() {
          _editing = false;
          _saving = false;
          _future = Future.value(updated);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('সেভ হয়েছে / Profile updated')),
        );
      }
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
    final auth = ref.watch(authStoreProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('প্রোফাইল / Profile')),
      body: FutureBuilder<ProfileData>(
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
          final data = snapshot.data!;
          if (!_editing &&
              (_name.text.isEmpty && _phone.text.isEmpty)) {
            _name.text = data.fullName ?? '';
            _phone.text = data.phone ?? '';
          }
          final displayName = data.fullName?.isNotEmpty == true
              ? data.fullName!
              : (data.email.isNotEmpty
                  ? data.email
                  : 'গ্রাহক / Customer');
          return ListView(
            padding: const EdgeInsets.all(AppSpace.l),
            children: [
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.l),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.seed.withValues(alpha: 0.12),
                        ),
                        child: const Icon(
                          Icons.person_outline,
                          size: 32,
                          color: AppColors.seed,
                        ),
                      ),
                      const SizedBox(width: AppSpace.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.headline(context),
                            ),
                            const SizedBox(height: AppSpace.xs),
                            Text(
                              '${data.email}${data.role.isNotEmpty ? ' • ${data.role}' : ''}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.body(context).copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpace.xs),
                            Row(
                              children: [
                                Icon(
                                  Icons.phone_outlined,
                                  size: 14,
                                  color: scheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: AppSpace.xs),
                                Expanded(
                                  child: Text(
                                    data.phone?.isNotEmpty == true
                                        ? data.phone!
                                        : 'ফোন নেই / No phone',
                                    style: AppText.label(context).copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.m),
              if (_editing)
                AppCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.l),
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppInput(
                            controller: _name,
                            label: 'নাম / Full name',
                            validator: (v) =>
                                v == null || v.trim().isEmpty
                                    ? 'নাম দিন / Enter name'
                                    : null,
                          ),
                          const SizedBox(height: AppSpace.m),
                          AppInput(
                            controller: _phone,
                            label: 'ফোন / Phone',
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: AppSpace.m),
                          AppButton(
                            label: 'সেভ / Save',
                            loading: _saving,
                            onPressed: _saving ? null : _save,
                          ),
                          const SizedBox(height: AppSpace.s),
                          TextButton(
                            onPressed: _saving
                                ? null
                                : () => setState(() => _editing = false),
                            child: const Text('বাতিল / Cancel'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                AppCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MenuRow(
                        icon: Icons.edit_outlined,
                        label: 'এডিট / Edit profile',
                        onTap: () => setState(() => _editing = true),
                      ),
                      _divider(),
                      _MenuRow(
                        icon: Icons.receipt_long_outlined,
                        label: 'আমার অর্ডার / My orders',
                        onTap: () => context.go('/orders'),
                      ),
                      if (auth.isAdmin) ...[
                        _divider(),
                        _MenuRow(
                          icon: Icons.admin_panel_settings_outlined,
                          label: 'অ্যাডমিন / Admin',
                          onTap: () => context.go('/admin'),
                        ),
                      ],
                      _divider(),
                      const _ThemeRow(),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpace.m),
              AppButton(
                label: 'লগআউট / Logout',
                onPressed: () async {
                  await ref.read(authStoreProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _divider() => Divider(
        height: 1,
        indent: AppSpace.l,
        endIndent: AppSpace.l,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      );
}

/// Single menu row: leading icon, bilingual label, trailing chevron.
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.l,
          vertical: AppSpace.m,
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.seed),
            const SizedBox(width: AppSpace.m),
            Expanded(
              child: Text(label, style: AppText.title(context)),
            ),
            Icon(
              Icons.chevron_right,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Appearance row reflecting the EXISTING theme mechanism.
///
/// Verified by search: the codebase has no `ThemeMode`/toggle
/// provider — `MyApp` wires `buildLightTheme()`/`buildDarkTheme()`
/// so the app follows the system brightness. Per the brief ("keep
/// existing mechanism, do not invent a new one") this row is
/// display-only: it shows the current mode and notes it follows the
/// system, without adding any new theme state.
class _ThemeRow extends StatelessWidget {
  const _ThemeRow();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.l,
        vertical: AppSpace.m,
      ),
      child: Row(
        children: [
          Icon(
            dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
            color: AppColors.seed,
          ),
          const SizedBox(width: AppSpace.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('থিম / Theme', style: AppText.title(context)),
                Text(
                  dark
                      ? 'ডার্ক (সিস্টেম) / Dark (system)'
                      : 'লাইট (সিস্টেম) / Light (system)',
                  style: AppText.body(context).copyWith(
                    color: scheme.onSurfaceVariant,
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
