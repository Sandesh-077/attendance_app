import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ca_attendance/repositories/auth_repository.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authRepository = AuthRepository();
  bool _editing = false;
  bool _saving = false;
  bool _changingPassword = false;
  bool _passwordSaving = false;
  String? _validationError;
  String? _passwordError;

  @override
  void dispose() {
    _nameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _clearPasswords() {
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
  }

  Future<void> _changePassword() async {
    if (_passwordSaving) return;
    final current = _currentPasswordController.text;
    final next = _newPasswordController.text;
    final confirmation = _confirmPasswordController.text;
    String? error;
    if (current.isEmpty || next.isEmpty || confirmation.isEmpty) {
      error = 'Fill in all password fields.';
    } else if (next.length < 6) {
      error = 'New password must be at least 6 characters.';
    } else if (next != confirmation) {
      error = 'New passwords do not match.';
    } else if (next == current) {
      error = 'Choose a different new password.';
    }
    if (error != null) {
      setState(() => _passwordError = error);
      return;
    }
    setState(() {
      _passwordSaving = true;
      _passwordError = null;
    });
    final result = await _authRepository.changePassword(
      currentPassword: current,
      newPassword: next,
    );
    if (!mounted) return;
    _clearPasswords();
    setState(() {
      _passwordSaving = false;
      _passwordError = result;
      if (result == null) _changingPassword = false;
    });
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully.')),
      );
    }
  }

  Future<void> _save(String uid, String currentName) async {
    if (_saving) return;
    final name = _nameController.text.trim();
    if (name.isEmpty || name.length > 200) {
      setState(() => _validationError = 'Enter a name of 1 to 200 characters.');
      return;
    }
    if (name == currentName) {
      setState(() {
        _editing = false;
        _validationError = null;
      });
      return;
    }
    setState(() {
      _saving = true;
      _validationError = null;
    });
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'name': name,
      });
      if (!mounted) return;
      setState(() => _editing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile saved.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to save profile. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Your account is unavailable.'));
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData && !snapshot.hasError) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(
            child: Text('Unable to load profile. Please try again.'),
          );
        }
        final data = snapshot.data?.data();
        if (data == null) {
          return const Center(
            child: Text('Your account profile is unavailable.'),
          );
        }
        final name = (data['name'] as String?)?.trim() ?? '';
        final email =
            user.email ?? (data['email'] as String?) ?? 'No email available';
        final role = data['role'] == 'Admin' ? 'Admin' : 'Teacher';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Profile',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
              const SizedBox(height: 20),
              if (_editing) ...[
                TextField(
                  controller: _nameController,
                  enabled: !_saving,
                  maxLength: 200,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    border: const OutlineInputBorder(),
                    errorText: _validationError,
                  ),
                ),
              ] else
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Name'),
                  subtitle: Text(name),
                ),
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('Email'),
                subtitle: Text(email),
              ),
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('Role'),
                subtitle: Text(role),
              ),
              const SizedBox(height: 20),
              if (_editing)
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: _saving ? null : () => _save(user.uid, name),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => setState(() {
                              _editing = false;
                              _validationError = null;
                            }),
                      child: const Text('Cancel'),
                    ),
                  ],
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() {
                      _nameController.text = name;
                      _validationError = null;
                      _editing = true;
                    }),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit name'),
                  ),
                ),
              const SizedBox(height: 28),
              const Divider(),
              const SizedBox(height: 12),
              if (_changingPassword) ...[
                Text(
                  'Change password',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _currentPasswordController,
                  enabled: !_passwordSaving,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(
                    labelText: 'Current password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _newPasswordController,
                  enabled: !_passwordSaving,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: const InputDecoration(
                    labelText: 'New password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPasswordController,
                  enabled: !_passwordSaving,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm new password',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_passwordError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _passwordError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: _passwordSaving ? null : _changePassword,
                      child: _passwordSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save password'),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: _passwordSaving
                          ? null
                          : () {
                              _clearPasswords();
                              setState(() {
                                _changingPassword = false;
                                _passwordError = null;
                              });
                            },
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ] else
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _changingPassword = true;
                      _passwordError = null;
                    }),
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('Change password'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
