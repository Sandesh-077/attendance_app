import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/class_model.dart';

class ClassRepository {
  ClassRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  Future<ClassModel?> get(String id) async {
    final doc = await _db.collection('classes').doc(id).get();
    return doc.exists ? ClassModel.fromDocument(doc) : null;
  }

  Stream<List<ClassModel>> watchAll() => _db
      .collection('classes')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(ClassModel.fromDocument).toList());

  Future<String> create({
    required String grade,
    required String section,
    required String academicYear,
  }) async {
    final doc = _db.collection('classes').doc();
    await doc.set({
      'grade': grade,
      'section': section,
      'academicYear': academicYear,
      'isArchived': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> update(
    String id, {
    required String grade,
    required String section,
    required String academicYear,
    required bool isArchived,
  }) => _db.collection('classes').doc(id).update({
    'grade': grade,
    'section': section,
    'academicYear': academicYear,
    'isArchived': isArchived,
  });

  Future<void> updateDetails(
    String id, {
    required String grade,
    required String section,
    required String academicYear,
  }) => _db.collection('classes').doc(id).update({
    'grade': grade,
    'section': section,
    'academicYear': academicYear,
  });

  Future<void> archive(String id) =>
      _db.collection('classes').doc(id).update({'isArchived': true});

  Future<void> unarchive(String id) =>
      _db.collection('classes').doc(id).update({'isArchived': false});
}
