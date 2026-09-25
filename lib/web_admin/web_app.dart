import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../repositories/auth_repository.dart';
import 'admin_pages.dart';
import 'admin_shell.dart';
import 'web_auth_state.dart';
import 'web_route_guard.dart';
import 'students_page.dart';
import 'profile_page.dart';
import 'app_info_page.dart';
import 'teacher_pages.dart';
import 'web_classes.dart';
import 'web_report_options.dart';
import 'attendance_pages.dart';
import 'report_pages.dart';

class WebAdminApp extends StatefulWidget {
  const WebAdminApp({super.key});

  @override
  State<WebAdminApp> createState() => _WebAdminAppState();
}

class _WebAdminAppState extends State<WebAdminApp> {
  late final WebAuthState _auth = WebAuthState();
  late final GoRouter _router = GoRouter(
    refreshListenable: _auth,
    redirect: (_, state) => webRedirect(_auth.status, state.uri.path),
    routes: [
      GoRoute(path: '/', builder: (_, _) => const _LoadingPage()),
      GoRoute(path: '/login', builder: (_, _) => const _LoginPage()),
      ShellRoute(
        builder: (_, state, child) =>
            AdminShell(path: state.uri.path, auth: _auth, child: child),
        routes: [
          GoRoute(
            path: '/admin',
            builder: (_, _) => AdminDashboardPage(name: _auth.name),
          ),
          GoRoute(
            path: '/admin/students',
            builder: (_, state) => StudentsPage(
              initialClassId: state.uri.queryParameters['classId'],
            ),
          ),
          GoRoute(
            path: '/admin/students/:studentId',
            builder: (_, state) => StudentDetailPage(
              studentId: state.pathParameters['studentId']!,
              classId: state.uri.queryParameters['classId'],
            ),
          ),
          GoRoute(
            path: '/admin/profile',
            builder: (_, _) => const WebProfilePage(),
          ),
          GoRoute(
            path: '/admin/app-info',
            builder: (_, _) => const WebAppInfoPage(),
          ),
          GoRoute(
            path: '/admin/teachers',
            builder: (_, _) => const WebTeachersPage(),
          ),
          GoRoute(
            path: '/admin/teachers/:teacherId',
            builder: (_, state) => WebTeacherDetailPage(
              teacherId: state.pathParameters['teacherId']!,
            ),
          ),
          GoRoute(
            path: '/admin/assignments',
            builder: (_, _) => const WebAssignmentsPage(),
          ),
          GoRoute(
            path: '/admin/classes',
            builder: (_, _) => const WebClassesPage(),
          ),
          GoRoute(
            path: '/admin/classes/:classId',
            builder: (_, state) =>
                WebClassDetailPage(classId: state.pathParameters['classId']!),
          ),
          GoRoute(
            path: '/admin/report-options',
            builder: (_, _) => const WebReportClassPicker(),
          ),
          GoRoute(
            path: '/admin/report-options/:classId',
            builder: (_, state) =>
                WebReportOptionsPage(classId: state.pathParameters['classId']!),
          ),
          GoRoute(
            path: '/admin/attendance',
            builder: (_, _) => const WebAttendanceIndex(),
          ),
          GoRoute(
            path: '/admin/attendance/:classId',
            builder: (_, state) => WebClassAttendance(
              classId: state.pathParameters['classId']!,
              dateKey: state.uri.queryParameters['date'],
            ),
          ),
          GoRoute(
            path: '/admin/attendance/:classId/history',
            builder: (_, state) => WebAttendanceHistory(
              classId: state.pathParameters['classId']!,
              dateKey: state.uri.queryParameters['date'],
              studentId: state.uri.queryParameters['studentId'],
            ),
          ),
          GoRoute(
            path: '/admin/reports',
            builder: (_, _) => const WebReportsPage(),
          ),
          GoRoute(
            path: '/admin/reports/:reportId',
            builder: (_, state) =>
                WebReportDetail(reportId: state.pathParameters['reportId']!),
          ),
        ],
      ),
      GoRoute(
        path: '/access-denied',
        builder: (_, _) => _AccessDeniedPage(auth: _auth),
      ),
    ],
  );

  @override
  void dispose() {
    _router.dispose();
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    debugShowCheckedModeBanner: false,
    title: 'CA Attendance',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      useMaterial3: true,
    ),
    routerConfig: _router,
  );
}

class _LoadingPage extends StatelessWidget {
  const _LoadingPage();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _LoginPage extends StatefulWidget {
  const _LoginPage();
  @override
  State<_LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<_LoginPage> {
  final _repository = AuthRepository();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hidden = true;
  String? _error;

  Future<void> _login() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await _repository.login(
      email: _email.text,
      password: _password.text,
    );
    if (mounted) {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email address first.');
      return;
    }
    try {
      await _repository.sendPasswordResetEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('If an account exists, a reset email has been sent.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Unable to send a reset email. Check the address and try again.',
        );
      }
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Form(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Image(image: AssetImage('assets/logo.png'), height: 96),
                const SizedBox(height: 20),
                Text(
                  'CA Attendance',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text('Admin Web sign in', textAlign: TextAlign.center),
                const SizedBox(height: 28),
                TextField(
                  controller: _email,
                  enabled: !_busy,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _password,
                  enabled: !_busy,
                  obscureText: _hidden,
                  onSubmitted: (_) => _login(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _hidden = !_hidden),
                      icon: Icon(
                        _hidden ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _login,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Login'),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _busy ? null : _resetPassword,
                    child: const Text('Forgot password?'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _AccessDeniedPage extends StatelessWidget {
  const _AccessDeniedPage({required this.auth});
  final WebAuthState auth;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Access unavailable',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            const Text(
              'This account does not currently have access to CA Attendance Web.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: auth.signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
          ],
        ),
      ),
    ),
  );
}
