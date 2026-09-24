import 'package:flutter/material.dart';
import 'dashboard.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) => const Dashboard(role: 'Admin');
}
