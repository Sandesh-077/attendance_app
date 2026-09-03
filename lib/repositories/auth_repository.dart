import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository {
  // Firebase auth instance
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Login
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      // SignIn user using firebase email and password authentication
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // Fetching the user's role from firestore
      DocumentSnapshot userDoc = await _firestore
          .collection("users")
          .doc(userCredential.user!.uid)
          .get();
      return userDoc['role'];
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> getUserRole(String uid) async {
    final document = await _firestore.collection('users').doc(uid).get();
    return document.data()?['role'] as String?;
  }
}
