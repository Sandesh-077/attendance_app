import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';

class TeacherRepository {
  TeacherRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<List<UserModel>> watchAll() => _db
      .collection('users')
      .where('role', isEqualTo: 'user')
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => UserModel.fromJson(doc.data())).toList(),
      );
}
