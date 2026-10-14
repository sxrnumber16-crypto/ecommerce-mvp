import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_store.dart';
import '../../shared/widgets/error_state.dart';
import '../../shared/widgets/loading_state.dart';
import 'profile_api.dart';

/// Profile tab: `GET /profile` (name/phone), `PATCH /profile` edit, logout.
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
    return Scaffold(
      appBar: AppBar(title: const Text('প্রোফাইল / Profile')),
      body: FutureBuilder<ProfileData>(
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
          final data = snapshot.data!;
          if (!_editing &&
              (_name.text.isEmpty && _phone.text.isEmpty)) {
            _name.text = data.fullName ?? '';
            _phone.text = data.phone ?? '';
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                    child: Icon(Icons.person_outline)),
                title: Text(data.fullName?.isNotEmpty == true
                    ? data.fullName!
                    : (data.email.isNotEmpty
                        ? data.email
                        : 'গ্রাহক / Customer')),
                subtitle: Text(
                    '${data.email}${data.role.isNotEmpty ? ' • ${data.role}' : ''}'),
              ),
              const Divider(),
              if (_editing)
                Form(
                  key: _form,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'নাম / Full name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v != null &&
                                    v.trim().isNotEmpty &&
                                    v.trim().length < 1
                                ? 'নাম দিন / Enter name'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'ফোন / Phone',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: _saving ? null : _save,
                              child: _saving
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Text('সেভ / Save'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: _saving
                                ? null
                                : () => setState(() => _editing = false),
                            child: const Text('বাতিল / Cancel'),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.phone_outlined),
                  title: Text(data.phone?.isNotEmpty == true
                      ? data.phone!
                      : 'ফোন নেই / No phone'),
                ),
                FilledButton.tonal(
                  onPressed: () => setState(() => _editing = true),
                  child: const Text('এডিট / Edit profile'),
                ),
              ],
              const SizedBox(height: 8),
              if (auth.isAdmin)
                FilledButton.tonal(
                  onPressed: () => context.go('/admin'),
                  child: const Text('অ্যাডমিন / Admin'),
                ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () async {
                  await ref.read(authStoreProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                },
                child: const Text('লগআউট / Logout'),
              ),
            ],
          );
        },
      ),
    );
  }
}
