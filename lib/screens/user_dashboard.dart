import 'package:flutter/material.dart';
import 'dashboard.dart';

class UserDashboard extends StatelessWidget {
  const UserDashboard({super.key});

  @override
  Widget build(BuildContext context) => const Dashboard(role: 'User');
}
