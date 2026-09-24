import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ca_attendance/models/user_model.dart';

class AuthRepository {
  // Firebase auth instance
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String?> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user!;
      try {
        await _firestore.collection('users').doc(user.uid).set({
          ...UserModel(
            uid: user.uid,
            email: user.email ?? email.trim(),
            name: name.trim(),
            role: 'user',
          ).toJson(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {
        try {
          await user.delete();
        } catch (_) {
          await _auth.signOut();
        }
        rethrow;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'An account already exists for this email.';
        case 'invalid-email':
          return 'Enter a valid email address.';
        case 'weak-password':
          return 'Choose a stronger password.';
        case 'operation-not-allowed':
          return 'Email and password signup is not enabled.';
        case 'network-request-failed':
          return 'Check your connection and try again.';
        default:
          return 'Unable to create your account. Please try again.';
      }
    } on FirebaseException catch (_) {
      return 'Unable to save your account information. Please try again.';
    } catch (_) {
      return 'Unable to create your account. Please try again.';
    }
  }

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return switch (e.code) {
        'invalid-email' => 'Enter a valid email address.',
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' => 'Invalid email or password.',
        'too-many-requests' => 'Too many attempts. Please try again later.',
        'network-request-failed' => 'Check your connection and try again.',
        _ => 'Unable to log in. Please try again.',
      };
    } catch (_) {
      return 'Unable to log in. Please try again.';
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      return 'Your account is unavailable. Please sign in again.';
    }
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      return switch (e.code) {
        'wrong-password' ||
        'invalid-credential' => 'Current password is incorrect.',
        'weak-password' => 'Choose a stronger new password.',
        'requires-recent-login' =>
          'Please sign in again and retry changing your password.',
        'too-many-requests' => 'Too many attempts. Please try again later.',
        'network-request-failed' => 'Check your connection and try again.',
        _ => 'Unable to change password. Please try again.',
      };
    } catch (_) {
      return 'Unable to change password. Please try again.';
    }
  }
}
