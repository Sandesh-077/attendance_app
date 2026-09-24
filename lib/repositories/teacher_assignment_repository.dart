import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/teacher_assignment_model.dart';

class TeacherAssignmentRepository {
  TeacherAssignmentRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  Future<TeacherAssignmentModel?> get(String teacherId, String classId) async {
    final doc = await _db
        .collection('teacherAssignments')
        .doc(TeacherAssignmentModel.documentId(teacherId, classId))
        .get();
    return doc.exists ? TeacherAssignmentModel.fromDocument(doc) : null;
  }

  Stream<List<TeacherAssignmentModel>> watchTeacher(String teacherId) => _db
      .collection('teacherAssignments')
      .where('teacherId', isEqualTo: teacherId)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map(TeacherAssignmentModel.fromDocument).toList(),
      );

  Future<void> assign({
    required String teacherId,
    required String classId,
    String? subject,
  }) async {
    final normalizedSubject = subject?.trim();
    final ref = _db
        .collection('teacherAssignments')
        .doc(TeacherAssignmentModel.documentId(teacherId, classId));
    await _db.runTransaction((transaction) async {
      final existing = await transaction.get(ref);
      if (existing.exists) {
        if (existing.data()?['isActive'] == true) {
          throw StateError('This teacher is already assigned to this class.');
        }
        transaction.update(ref, {
          'isActive': true,
          'subject': normalizedSubject == null || normalizedSubject.isEmpty
              ? FieldValue.delete()
              : normalizedSubject,
        });
      } else {
        transaction.set(ref, {
          'teacherId': teacherId,
          'classId': classId,
          if (normalizedSubject != null && normalizedSubject.isNotEmpty)
            'subject': normalizedSubject,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> setActive(String teacherId, String classId, bool isActive) => _db
      .collection('teacherAssignments')
      .doc(TeacherAssignmentModel.documentId(teacherId, classId))
      .update({'isActive': isActive});
}
