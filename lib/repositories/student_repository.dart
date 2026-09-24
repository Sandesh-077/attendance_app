import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student_model.dart';

class StudentRepository {
  StudentRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  Future<StudentModel?> get(String id) async {
    final doc = await _db.collection('students').doc(id).get();
    return doc.exists ? StudentModel.fromDocument(doc) : null;
  }

  Stream<List<StudentModel>> watchClass(String classId) => _db
      .collection('students')
      .where('classId', isEqualTo: classId)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(StudentModel.fromDocument).toList());

  Stream<List<StudentModel>> watchActiveClass(String classId) => _db
      .collection('students')
      .where('classId', isEqualTo: classId)
      .where('isArchived', isEqualTo: false)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(StudentModel.fromDocument).toList());

  Future<List<StudentModel>> activeClass(String classId) async {
    final snapshot = await _db
        .collection('students')
        .where('classId', isEqualTo: classId)
        .where('isArchived', isEqualTo: false)
        .get(const GetOptions(source: Source.server));
    return snapshot.docs.map(StudentModel.fromDocument).toList();
  }

  Stream<List<StudentModel>> watchAll() => _db
      .collection('students')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(StudentModel.fromDocument).toList());

  Future<String> create({
    required String name,
    required String rollNumber,
    required String classId,
  }) async {
    final doc = _db.collection('students').doc();
    await doc.set({
      'name': name,
      'rollNumber': rollNumber,
      'classId': classId,
      'isArchived': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> update(
    String id, {
    required String name,
    required String rollNumber,
    required String classId,
  }) => _db.collection('students').doc(id).update({
    'name': name,
    'rollNumber': rollNumber,
    'classId': classId,
  });

  Future<void> archive(String id) =>
      _db.collection('students').doc(id).update({'isArchived': true});
}
