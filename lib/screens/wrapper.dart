import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'login.dart';
import 'admin_dashboard.dart';
import 'user_dashboard.dart';
import 'update_gate.dart';

class Wrapper extends StatelessWidget {
  const Wrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = authSnapshot.data;
        if (user == null) return const LoginScreen();
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          key: ValueKey(user.uid),
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (profileSnapshot.hasError) {
              return const _ProfileProblem(
                message: 'Unable to load your account. Please try again.',
              );
            }
            final role = profileSnapshot.data?.data()?['role'];
            if (role == 'Admin') {
              return const UpdateGate(child: AdminDashboard());
            }
            if (role == 'user') return const UpdateGate(child: UserDashboard());
            return const _ProfileProblem(
              message: 'Your account profile is unavailable.',
            );
          },
        );
      },
    );
  }
}

class _ProfileProblem extends StatelessWidget {
  const _ProfileProblem({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              try {
                await FirebaseAuth.instance.signOut();
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Unable to log out. Please try again.'),
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to login'),
          ),
        ],
      ),
    ),
  );
}
