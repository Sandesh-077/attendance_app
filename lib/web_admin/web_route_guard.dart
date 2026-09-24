import 'web_auth_state.dart';

String? webRedirect(WebAuthStatus status, String location) {
  final isAdminPath = location == '/admin' || location.startsWith('/admin/');
  if (status == WebAuthStatus.loading) return location == '/' ? null : '/';
  if (status == WebAuthStatus.signedOut) {
    return location == '/login' ? null : '/login';
  }
  if (status == WebAuthStatus.admin) {
    return isAdminPath ? null : '/admin';
  }
  return location == '/access-denied' ? null : '/access-denied';
}
