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
    return effectiveReportOptions(s.docs.map(ReportOptionModel.fromDocument));
  }

  Future<String> customizeDefault({
    required String classId,
    required ReportOptionModel defaultOption,
    required String title,
    required bool requiresDetails,
    required String actorId,
  }) async {
    final ref = _db.collection('reportOptions').doc();
    await ref.set({
      'classId': classId,
      'defaultId': defaultOption.id,
      'title': title.trim(),
      'category': defaultOption.category.name,
      'requiresDetails': requiresDetails,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': actorId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<String> create({
    required String classId,
    required String title,
    required ReportCategory category,
    required bool requiresDetails,
    required String actorId,
  }) async {
    final ref = _db.collection('reportOptions').doc();
    await ref.set({
      'classId': classId,
      'title': title.trim(),
      'category': category.name,
      'requiresDetails': requiresDetails,
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
    required bool requiresDetails,
  }) => _db.collection('reportOptions').doc(id).update({
    'title': title.trim(),
    'category': category.name,
    'requiresDetails': requiresDetails,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  Future<void> disable(String id) => _db
      .collection('reportOptions')
      .doc(id)
      .update({'isActive': false, 'updatedAt': FieldValue.serverTimestamp()});
}

List<ReportOptionModel> effectiveReportOptions(
  Iterable<ReportOptionModel> custom,
) {
  final active = custom.where((option) => option.isActive).toList();
  final overridden = active.map((option) => option.defaultId).toSet();
  return [
    ...ReportOptionModel.defaults.where(
      (option) => !overridden.contains(option.id),
    ),
    ...active,
  ];
}
