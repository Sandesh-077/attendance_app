import 'package:ca_attendance/web_admin/web_auth_state.dart';
import 'package:ca_attendance/web_admin/web_route_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loading hides protected content', () {
    expect(webRedirect(WebAuthStatus.loading, '/admin'), '/');
    expect(webRedirect(WebAuthStatus.loading, '/admin/classes/123'), '/');
  });

  test('signed out users go to login', () {
    expect(webRedirect(WebAuthStatus.signedOut, '/'), '/login');
    expect(webRedirect(WebAuthStatus.signedOut, '/admin'), '/login');
    expect(
      webRedirect(WebAuthStatus.signedOut, '/admin/classes/123'),
      '/login',
    );
    expect(webRedirect(WebAuthStatus.signedOut, '/login'), isNull);
  });

  test('admins may access all admin paths', () {
    expect(webRedirect(WebAuthStatus.admin, '/login'), '/admin');
    expect(webRedirect(WebAuthStatus.admin, '/admin'), isNull);
    expect(webRedirect(WebAuthStatus.admin, '/admin/classes/123'), isNull);
  });

  test('unsupported or invalid profiles never reach admin routes', () {
    const protectedPaths = [
      '/admin',
      '/admin/classes',
      '/admin/classes/abc',
      '/admin/students',
      '/admin/students/abc',
      '/admin/teachers',
      '/admin/teachers/abc',
      '/admin/assignments',
      '/admin/attendance',
      '/admin/attendance/abc',
      '/admin/attendance/abc/history',
      '/admin/reports',
      '/admin/reports/abc',
      '/admin/report-options',
      '/admin/report-options/abc',
      '/admin/profile',
    ];
    for (final status in [
      WebAuthStatus.unsupported,
      WebAuthStatus.missingProfile,
      WebAuthStatus.profileError,
    ]) {
      for (final path in protectedPaths) {
        expect(webRedirect(status, path), '/access-denied');
        expect(webRedirect(WebAuthStatus.signedOut, path), '/login');
        expect(webRedirect(WebAuthStatus.loading, path), '/');
        expect(webRedirect(WebAuthStatus.admin, path), isNull);
      }
      expect(webRedirect(status, '/access-denied'), isNull);
    }
  });

  test('logout returns to login', () {
    expect(webRedirect(WebAuthStatus.signedOut, '/admin'), '/login');
    expect(webRedirect(WebAuthStatus.signedOut, '/access-denied'), '/login');
  });
}
