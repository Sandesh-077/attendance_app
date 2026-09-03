import 'package:ca_attendance/repositories/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'login.dart';
import 'admin_dashboard.dart';
import 'user_dashboard.dart';

class Wrapper extends StatefulWidget {
  const Wrapper({super.key});

  @override
  State<Wrapper> createState() => _WrapperState();
}

class _WrapperState extends State<Wrapper> {
  final AuthRepository _authRepository = AuthRepository();
  String? _roleUserId;
  Future<String?>? _roleFuture;

  Future<String?> _getRole(User user) {
    if (_roleUserId != user.uid) {
      _roleUserId = user.uid;
      _roleFuture = _authRepository.getUserRole(user.uid);
    }

    return _roleFuture!;
  }

  @override
  Widget build(BuildContext context) {
    if (Firebase.apps.isEmpty) {
      return const LoginScreen();
    }

    return Scaffold(
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasData) {
            return FutureBuilder<String?>(
              future: _getRole(snapshot.data!),
              builder: (context, roleSnapshot) {
                if (roleSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (roleSnapshot.hasError) {
                  return Center(
                    child: Text('Unable to load user role: ${roleSnapshot.error}'),
                  );
                }

                final role = roleSnapshot.data;

                if (role == 'Admin') {
                  return const AdminDashboard();
                }

                if (role == 'User') {
                  return const UserDashboard();
                }

                return const Center(child: Text('Invalid user role'));
              },
            );
          }

          return const LoginScreen();
        },
      ),
    );
  }
}
