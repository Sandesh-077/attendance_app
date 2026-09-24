import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'profile.dart';
import 'teacher_classes_screen.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  int _selectedIndex = 0;
  bool _signingOut = false;

  static const _titles = ['Dashboard', 'My Classes', 'Attendance', 'Profile'];
  static const _icons = [
    Icons.dashboard_outlined,
    Icons.class_outlined,
    Icons.fact_check_outlined,
    Icons.person_outline,
  ];

  Future<void> _logout() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      if (!mounted) return;
      setState(() => _signingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to log out. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(_titles[_selectedIndex]),
        actions: [
          IconButton(
            tooltip: 'Log out',
            onPressed: _signingOut ? null : _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(20),
                child: Image(image: AssetImage('assets/logo.png'), height: 80),
              ),
              for (var index = 0; index < _titles.length; index++)
                ListTile(
                  leading: Icon(_icons[index]),
                  title: Text(_titles[index]),
                  selected: _selectedIndex == index,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = index);
                  },
                ),
              const Spacer(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Log out'),
                enabled: !_signingOut,
                onTap: _logout,
              ),
            ],
          ),
        ),
      ),
      body: switch (_selectedIndex) {
        0 => _TeacherHome(
          onSelect: (index) => setState(() => _selectedIndex = index),
        ),
        1 => TeacherClassesScreen(teacherId: user.uid),
        2 => TeacherClassesScreen(teacherId: user.uid, attendanceMode: true),
        3 => const ProfileScreen(),
        _ => Center(child: Text('${_titles[_selectedIndex]} is coming soon.')),
      },
    );
  }
}

class _TeacherHome extends StatelessWidget {
  const _TeacherHome({required this.onSelect});
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(30),
    children: [
      Text(
        'Teacher Dashboard',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.blue[700],
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Choose a section to get started.',
        style: TextStyle(color: Colors.grey),
      ),
      const SizedBox(height: 24),
      for (final (index, icon, title) in [
        (1, Icons.class_outlined, 'My Classes'),
        (2, Icons.fact_check_outlined, 'Attendance'),
        (3, Icons.person_outline, 'Profile'),
      ])
        Card(
          child: ListTile(
            leading: Icon(icon, color: Colors.blue[700]),
            title: Text(title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onSelect(index),
          ),
        ),
    ],
  );
}
