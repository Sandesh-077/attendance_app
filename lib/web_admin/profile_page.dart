import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../repositories/auth_repository.dart';

class WebProfilePage extends StatefulWidget {
  const WebProfilePage({super.key});
  @override
  State<WebProfilePage> createState() => _WebProfilePageState();
}

class _WebProfilePageState extends State<WebProfilePage> {
  final _name = TextEditingController();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  final _auth = AuthRepository();
  bool _editing = false, _changingPassword = false, _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _saveName(String uid, String currentName) async {
    final name = _name.text.trim();
    if (name.isEmpty || name.length > 200) {
      setState(() => _error = 'Enter a name of 1 to 200 characters.');
      return;
    }
    if (name == currentName) {
      setState(() {
        _editing = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'name': name,
      });
      if (mounted) {
        setState(() => _editing = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile saved.')));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to save profile. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _savePassword() async {
    final current = _current.text, next = _next.text, confirm = _confirm.text;
    String? error;
    if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
      error = 'Fill in all password fields.';
    } else if (next.length < 6) {
      error = 'New password must be at least 6 characters.';
    } else if (next != confirm) {
      error = 'New passwords do not match.';
    } else if (next == current) {
      error = 'Choose a different new password.';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await _auth.changePassword(
      currentPassword: current,
      newPassword: next,
    );
    if (!mounted) return;
    _current.clear();
    _next.clear();
    _confirm.clear();
    setState(() {
      _saving = false;
      _error = result;
      if (result == null) _changingPassword = false;
    });
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully.')),
      );
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
        if (snapshot.hasError) {
          return const Center(
            child: Text('Unable to load profile. Please try again.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
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
        return ListView(
          padding: const EdgeInsets.all(32),
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Account information',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 20),
                          if (_editing)
                            TextField(
                              controller: _name,
                              enabled: !_saving,
                              maxLength: 200,
                              decoration: const InputDecoration(
                                labelText: 'Name',
                                border: OutlineInputBorder(),
                              ),
                            )
                          else
                            _ProfileField(label: 'Name', value: name),
                          const SizedBox(height: 16),
                          _ProfileField(label: 'Email', value: email),
                          const SizedBox(height: 16),
                          const _ProfileField(label: 'Role', value: 'Admin'),
                          const SizedBox(height: 24),
                          if (_editing)
                            Wrap(
                              spacing: 12,
                              children: [
                                FilledButton(
                                  onPressed: _saving
                                      ? null
                                      : () => _saveName(user.uid, name),
                                  child: Text(
                                    _saving ? 'Saving…' : 'Save name',
                                  ),
                                ),
                                TextButton(
                                  onPressed: _saving
                                      ? null
                                      : () => setState(() {
                                          _editing = false;
                                          _error = null;
                                        }),
                                  child: const Text('Cancel'),
                                ),
                              ],
                            )
                          else
                            OutlinedButton.icon(
                              onPressed: () => setState(() {
                                _name.text = name;
                                _editing = true;
                                _error = null;
                              }),
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Edit name'),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Password',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          if (_changingPassword) ...[
                            TextField(
                              controller: _current,
                              enabled: !_saving,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Current password',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _next,
                              enabled: !_saving,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'New password',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _confirm,
                              enabled: !_saving,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Confirm new password',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: 12,
                              children: [
                                FilledButton(
                                  onPressed: _saving ? null : _savePassword,
                                  child: Text(
                                    _saving ? 'Saving…' : 'Save password',
                                  ),
                                ),
                                TextButton(
                                  onPressed: _saving
                                      ? null
                                      : () => setState(() {
                                          _current.clear();
                                          _next.clear();
                                          _confirm.clear();
                                          _changingPassword = false;
                                          _error = null;
                                        }),
                                  child: const Text('Cancel'),
                                ),
                              ],
                            ),
                          ] else
                            OutlinedButton.icon(
                              onPressed: () => setState(() {
                                _changingPassword = true;
                                _error = null;
                              }),
                              icon: const Icon(Icons.lock_outline),
                              label: const Text('Change password'),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium),
      const SizedBox(height: 4),
      Text(value, style: Theme.of(context).textTheme.bodyLarge),
    ],
  );
}
