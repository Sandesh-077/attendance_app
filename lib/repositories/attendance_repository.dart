import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_model.dart';

class AttendanceRepository {
  AttendanceRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  Future<AttendanceModel?> get(String studentId, String dateKey) async {
    final doc = await _db
        .collection('attendance')
        .doc(AttendanceModel.documentId(studentId, dateKey))
        .get();
    return doc.exists ? AttendanceModel.fromDocument(doc) : null;
  }

  Stream<List<AttendanceModel>> watchClassDay(String classId, String dateKey) =>
      _db
          .collection('attendance')
          .where('classId', isEqualTo: classId)
          .where('dateKey', isEqualTo: dateKey)
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs.map(AttendanceModel.fromDocument).toList(),
          );

  Future<List<AttendanceModel>> classDay(String classId, String dateKey) async {
    final snapshot = await _db
        .collection('attendance')
        .where('classId', isEqualTo: classId)
        .get();
    return snapshot.docs
        .map(AttendanceModel.fromDocument)
        .where((record) => record.dateKey == dateKey)
        .toList();
  }

  Future<List<AttendanceModel>> classHistory(String classId) async {
    final snapshot = await _db
        .collection('attendance')
        .where('classId', isEqualTo: classId)
        .get();
    final records = snapshot.docs.map(AttendanceModel.fromDocument).toList();
    records.sort((a, b) => b.dateKey.compareTo(a.dateKey));
    return records;
  }

  Future<List<AttendanceModel>> studentHistory(
    String classId,
    String studentId,
  ) async {
    final snapshot = await _db
        .collection('attendance')
        .where('classId', isEqualTo: classId)
        .get();
    final records = snapshot.docs
        .map(AttendanceModel.fromDocument)
        .where((record) => record.studentId == studentId)
        .toList();
    records.sort((a, b) => b.dateKey.compareTo(a.dateKey));
    return records;
  }

  Future<List<AttendanceModel>> studentMonth(
    String studentId,
    DateTime month,
  ) async {
    final start =
        '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}-01';
    final next = DateTime(month.year, month.month + 1);
    final end =
        '${next.year.toString().padLeft(4, '0')}-${next.month.toString().padLeft(2, '0')}-01';
    final snapshot = await _db
        .collection('attendance')
        .where('studentId', isEqualTo: studentId)
        .where('dateKey', isGreaterThanOrEqualTo: start)
        .where('dateKey', isLessThan: end)
        .get();
    return snapshot.docs.map(AttendanceModel.fromDocument).toList();
  }

  Future<void> saveClassDay({
    required String classId,
    required String dateKey,
    required Map<String, AttendanceStatus> statuses,
    required Map<String, AttendanceModel> existing,
    required String actorId,
  }) async {
    if (statuses.isEmpty) {
      throw StateError('Attendance requires at least one student.');
    }
    // A single commit is atomic. If Firestore's batch or security-rule limits
    // are exceeded, the entire submission fails without saving a partial day.
    final batch = _db.batch();
    for (final entry in statuses.entries) {
      final ref = _db
          .collection('attendance')
          .doc(AttendanceModel.documentId(entry.key, dateKey));
      final previous = existing[entry.key];
      if (previous == null) {
        batch.set(ref, {
          'studentId': entry.key,
          'classId': classId,
          'dateKey': dateKey,
          'status': entry.value.name,
          'recordedAt': FieldValue.serverTimestamp(),
          'recordedBy': actorId,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': actorId,
        });
      } else if (previous.status != entry.value) {
        batch.update(ref, {
          'status': entry.value.name,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': actorId,
        });
      }
    }
    await batch.commit();
  }

  Future<void> record({
    required String studentId,
    required String classId,
    required String dateKey,
    required AttendanceStatus status,
    required String actorId,
  }) async {
    final ref = _db
        .collection('attendance')
        .doc(AttendanceModel.documentId(studentId, dateKey));
    await _db.runTransaction((transaction) async {
      final existing = await transaction.get(ref);
      if (existing.exists) {
        transaction.update(ref, {
          'status': status.name,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': actorId,
        });
      } else {
        transaction.set(ref, {
          'studentId': studentId,
          'classId': classId,
          'dateKey': dateKey,
          'status': status.name,
          'recordedAt': FieldValue.serverTimestamp(),
          'recordedBy': actorId,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': actorId,
        });
      }
    });
  }
}
