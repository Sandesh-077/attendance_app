import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

enum WebAuthStatus {
  loading,
  signedOut,
  admin,
  unsupported,
  missingProfile,
  profileError,
}

/// Auth and the signed-in user's profile are one route-guard input.
class WebAuthState extends ChangeNotifier {
  WebAuthState({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance {
    _authSubscription = _auth.authStateChanges().listen(
      _onUser,
      onError: (_) {
        _setStatus(WebAuthStatus.profileError);
      },
    );
  }

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _profileSubscription;
  WebAuthStatus status = WebAuthStatus.loading;
  String? name;
  int _generation = 0;

  void _setStatus(WebAuthStatus next) {
    status = next;
    notifyListeners();
  }

  void _onUser(User? user) {
    _generation++;
    final generation = _generation;
    _profileSubscription?.cancel();
    _profileSubscription = null;
    name = null;
    if (user == null) {
      _setStatus(WebAuthStatus.signedOut);
      return;
    }
    _setStatus(WebAuthStatus.loading);
    _profileSubscription = _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen(
          (snapshot) {
            if (generation != _generation) return;
            final data = snapshot.data();
            if (data == null) {
              _setStatus(WebAuthStatus.missingProfile);
              return;
            }
            final role = data['role'];
            final profileName = data['name'];
            name = profileName is String && profileName.trim().isNotEmpty
                ? profileName.trim()
                : null;
            _setStatus(
              role == 'Admin' ? WebAuthStatus.admin : WebAuthStatus.unsupported,
            );
          },
          onError: (_) {
            if (generation == _generation) {
              _setStatus(WebAuthStatus.profileError);
            }
          },
        );
  }

  Future<void> signOut() async {
    _generation++;
    await _profileSubscription?.cancel();
    _profileSubscription = null;
    name = null;
    _setStatus(WebAuthStatus.loading);
    try {
      await _auth.signOut();
    } catch (_) {
      _onUser(_auth.currentUser);
      rethrow;
    }
  }

  @override
  void dispose() {
    _generation++;
    _profileSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
}
