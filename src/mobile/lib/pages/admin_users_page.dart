import 'package:flutter/material.dart';

import '../api/client.dart';
import '../api/types.dart';
import '../state/async_data.dart';
import '../theme/app_theme.dart';
import '../widgets/section_label.dart';
import '../widgets/status_states.dart';

/// Admin: the people in this company.
///
/// Reuses [AsyncData] rather than hand-rolling loading state — it already has
/// the background-refresh and error semantics every other page in the app uses.
/// The fallback is an empty list: for an admin screen, inventing demo users
/// would be actively misleading.
class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  late final AsyncData<List<OperatorUser>> _users = AsyncData(
    fetcher: api.getUsers,
    fallback: () => const <OperatorUser>[],
  )..addListener(_onChanged);

  @override
  void dispose() {
    _users.removeListener(_onChanged);
    _users.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _openCreateSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.gray10,
      shape: const RoundedRectangleBorder(),
      builder: (_) => const _CreateUserSheet(),
    );
    if (created == true) _users.refetch();
  }

  @override
  Widget build(BuildContext context) {
    final users = _users.data ?? const <OperatorUser>[];

    return Scaffold(
      backgroundColor: AppColors.gray10,
      body: RefreshIndicator(
        color: AppColors.blue60,
        onRefresh: () async {
          _users.refetch();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
          children: [
            const SectionLabel('Administration'),
            const SizedBox(height: 8),
            Text('Team',
                style: AppText.serif(size: 30, weight: FontWeight.w600, letterSpacing: -0.5)),
            const SizedBox(height: 8),
            Text(
              'Everyone who can sign in to this company, and what they are allowed to do.',
              style: AppText.serif(
                size: 15, color: AppColors.gray70, fontStyle: FontStyle.italic, height: 1.5),
            ),
            const SizedBox(height: 20),
            const Hairline(),
            const SizedBox(height: 24),

            if (_users.loading)
              const LoadingBlock(label: 'Loading team')
            else if (_users.error != null && users.isEmpty)
              ErrorBlock(message: _users.error!, onRetry: _users.refetch)
            else if (users.isEmpty)
              const EmptyBlock(message: 'No users yet. Add the first crew member below.')
            else
              for (final user in users) _UserRow(user: user),

            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _openCreateSheet,
              icon: const Icon(Icons.person_add_alt, size: 18),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.blue60,
                side: const BorderSide(color: AppColors.gray30),
                shape: const RoundedRectangleBorder(),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              label: Text('Add a team member',
                  style: AppText.sans(size: 14, weight: FontWeight.w600, color: AppColors.blue60)),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.user});

  final OperatorUser user;

  @override
  Widget build(BuildContext context) {
    final isAdmin = user.role == UserRole.admin;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.gray20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.fullName, style: AppText.serif(size: 17, weight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(user.email, style: AppText.mono(size: 12, color: AppColors.gray60)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isAdmin ? AppColors.blue20 : AppColors.gray10,
              border: Border.all(color: isAdmin ? AppColors.blue60 : AppColors.gray30),
            ),
            child: Text(
              user.role.label,
              style: AppText.sans(
                size: 11,
                weight: FontWeight.w600,
                color: isAdmin ? AppColors.blue70 : AppColors.gray70,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateUserSheet extends StatefulWidget {
  const _CreateUserSheet();

  @override
  State<_CreateUserSheet> createState() => _CreateUserSheetState();
}

class _CreateUserSheetState extends State<_CreateUserSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  UserRole _role = UserRole.field;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await api.createUser(
        email: _email.text.trim(),
        fullName: _name.text.trim(),
        password: _password.text,
        role: _role,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (err) {
      setState(() => _error = err is ApiError ? err.message : 'Could not create the user.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionLabel('New team member'),
              const SizedBox(height: 16),
              _input(_name, 'Full name',
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required.' : null),
              const SizedBox(height: 14),
              _input(_email, 'Work email',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email.' : null),
              const SizedBox(height: 14),
              // The backend enforces 10 characters too; this just says so
              // before a round trip.
              _input(_password, 'Temporary password',
                  validator: (v) =>
                      (v == null || v.length < 10) ? 'At least 10 characters.' : null),
              const SizedBox(height: 18),
              const SectionLabel('Role'),
              const SizedBox(height: 8),
              SegmentedButton<UserRole>(
                segments: const [
                  ButtonSegment(value: UserRole.field, label: Text('Field crew')),
                  ButtonSegment(value: UserRole.admin, label: Text('Administrator')),
                ],
                selected: {_role},
                onSelectionChanged: (selection) => setState(() => _role = selection.first),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: AppText.sans(size: 13, color: AppColors.riskCritical)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.blue60,
                    shape: const RoundedRectangleBorder(),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
                      : Text('Create account',
                          style: AppText.sans(
                              size: 15, weight: FontWeight.w600, color: AppColors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _input(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: AppText.sans(size: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppText.sans(size: 13, color: AppColors.gray60),
        filled: true,
        fillColor: AppColors.white,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.gray20),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.gray20),
        ),
      ),
    );
  }
}
