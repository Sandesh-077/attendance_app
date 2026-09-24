import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/report_option_model.dart';

class ReportOptionRepository {
  ReportOptionRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  Stream<List<ReportOptionModel>> watchClass(String classId) => _db
      .collection('reportOptions')
      .where('classId', isEqualTo: classId)
      .snapshots()
      .map((s) => s.docs.map(ReportOptionModel.fromDocument).toList());

  Future<List<ReportOptionModel>> activeForClass(String classId) async {
    final s = await _db
        .collection('reportOptions')
        .where('classId', isEqualTo: classId)
        .where('isActive', isEqualTo: true)
        .get();
    return [
      ...ReportOptionModel.defaults,
      ...s.docs.map(ReportOptionModel.fromDocument),
    ];
  }

  Future<String> create({
    required String classId,
    required String title,
    required ReportCategory category,
    required String actorId,
  }) async {
    final ref = _db.collection('reportOptions').doc();
    await ref.set({
      'classId': classId,
      'title': title.trim(),
      'category': category.name,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': actorId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> update(
    String id, {
    required String title,
    required ReportCategory category,
  }) => _db.collection('reportOptions').doc(id).update({
    'title': title.trim(),
    'category': category.name,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  Future<void> disable(String id) => _db
      .collection('reportOptions')
      .doc(id)
      .update({'isActive': false, 'updatedAt': FieldValue.serverTimestamp()});
}
