import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'students_screen.dart';
import 'profile.dart';
import 'teachers_screen.dart';
import 'classes_screen.dart';
import 'admin_reports_screen.dart';
import 'app_info_screen.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key, required this.role});

  final String role;

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int _selectedIndex = 0;
  bool _signingOut = false;

  static const _titles = [
    'Dashboard',
    'Attendance',
    'Classes',
    'Students',
    'Profile',
    'Teachers',
    'Reports',
  ];
  static const _icons = [
    Icons.dashboard_outlined,
    Icons.fact_check_outlined,
    Icons.class_outlined,
    Icons.groups_outlined,
    Icons.person_outline,
    Icons.school_outlined,
    Icons.report_outlined,
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
              ...List.generate(
                widget.role == 'Admin' ? _titles.length : _titles.length - 1,
                (index) => ListTile(
                  leading: Icon(_icons[index]),
                  title: Text(_titles[index]),
                  selected: _selectedIndex == index,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = index);
                  },
                ),
              ),
              const Spacer(),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('App Info'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const AppInfoScreen(),
                    ),
                  );
                },
              ),
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
      body: _selectedIndex == 4
          ? const ProfileScreen()
          : _selectedIndex == 5 && widget.role == 'Admin'
          ? const TeachersScreen()
          : _selectedIndex == 6 && widget.role == 'Admin'
          ? const AdminReportsScreen()
          : _selectedIndex == 2 && widget.role == 'Admin'
          ? const ClassesScreen()
          : _selectedIndex == 1 && widget.role == 'Admin'
          ? const ClassesScreen()
          : _selectedIndex == 3 && widget.role == 'Admin'
          ? const StudentsScreen()
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data();
                final name = (data?['name'] as String?)?.trim();
                final displayName = name != null && name.isNotEmpty
                    ? name
                    : (user.displayName?.isNotEmpty == true
                          ? user.displayName!
                          : 'User');
                final email =
                    (data?['email'] as String?) ??
                    user.email ??
                    'No email available';

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(30),
                  child: _selectedIndex == 0
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Welcome, $displayName',
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
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(email),
                                    const SizedBox(height: 6),
                                    Text('Role: ${widget.role}'),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            ...List.generate(
                              widget.role == 'Admin' ? 6 : 4,
                              (index) => Card(
                                child: ListTile(
                                  leading: Icon(
                                    _icons[index + 1],
                                    color: Colors.blue[700],
                                  ),
                                  title: Text(_titles[index + 1]),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => setState(
                                    () => _selectedIndex = index + 1,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _titles[_selectedIndex],
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Coming soon',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                );
              },
            ),
    );
  }
}
