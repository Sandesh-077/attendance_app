import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final user = FirebaseAuth.instance.currentUser;

  signout()async{
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text(
              'AdminDashboard'
          )
      ),
      body: Center(
          child: Text(
              'Welcome, ${user!.email}! This is admin dashbaord'
          )
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: (()=>signout()),
        child: Icon(Icons.login_rounded),
      ),
    );

  }
}
