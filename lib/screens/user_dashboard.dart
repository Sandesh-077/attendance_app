import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  final user = FirebaseAuth.instance.currentUser;

  signout()async{
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text(
              'UserDashboard'
          )
      ),
      body: Center(
          child: Text(
              'Welcome, ${user!.email}! This is user dashbaord'
          )
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: (()=>signout()),
        child: Icon(Icons.login_rounded),
      ),
    );

  }
}
