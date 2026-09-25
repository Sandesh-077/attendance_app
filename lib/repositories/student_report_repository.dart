import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/report_option_model.dart';
import '../models/student_report_model.dart';

class StudentReportRepository {
  StudentReportRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;
  CollectionReference<Map<String, dynamic>> get _reports =>
      _db.collection('studentReports');
  List<StudentReportModel> _map(QuerySnapshot<Map<String, dynamic>> s) =>
      s.docs.map(StudentReportModel.fromDocument).toList();

  Future<String> create({
    required String studentId,
    required String classId,
    required String attendanceDateKey,
    required ReportOptionModel option,
    required ReportSeverity severity,
    required String details,
    required String actorId,
  }) async {
    final ref = _reports.doc();
    await ref.set({
      'studentId': studentId,
      'classId': classId,
      'attendanceDateKey': attendanceDateKey,
      'optionId': option.id,
      'category': option.category.name,
      'titleSnapshot': option.title,
      'severity': severity.name,
      'details': details.trim(),
      'reportedBy': actorId,
      'reportedAt': FieldValue.serverTimestamp(),
      'status': ReportStatus.open.name,
    });
    return ref.id;
  }

  Future<List<StudentReportModel>> forStudent(String studentId) async => _map(
    await _reports
        .where('studentId', isEqualTo: studentId)
        .orderBy('reportedAt', descending: true)
        .get(),
  );
  Future<List<StudentReportModel>> forClass(String classId) async => _map(
    await _reports
        .where('classId', isEqualTo: classId)
        .orderBy('reportedAt', descending: true)
        .get(),
  );
  Future<List<StudentReportModel>> unresolvedForClass(String classId) async =>
      _map(
        await _reports
            .where('classId', isEqualTo: classId)
            .where('status', isEqualTo: 'open')
            .orderBy('reportedAt', descending: true)
            .get(),
      );
  Future<List<StudentReportModel>> recentForClass(
    String classId, {
    int limit = 20,
  }) async => _map(
    await _reports
        .where('classId', isEqualTo: classId)
        .orderBy('reportedAt', descending: true)
        .limit(limit)
        .get(),
  );
  Future<List<StudentReportModel>> adminUnresolved() async => _map(
    await _reports
        .where('status', isEqualTo: 'open')
        .orderBy('reportedAt', descending: true)
        .get(),
  );
  Future<List<StudentReportModel>> adminRecent({int limit = 50}) async => _map(
    await _reports.orderBy('reportedAt', descending: true).limit(limit).get(),
  );

  // Small-school admin overview: one read covers open reports and all history.
  Future<List<StudentReportModel>> adminAll() async =>
      _map(await _reports.orderBy('reportedAt', descending: true).get());

  Future<StudentReportModel?> get(String id) async {
    final doc = await _reports.doc(id).get();
    return doc.exists ? StudentReportModel.fromDocument(doc) : null;
  }

  Future<void> resolve(
    String id, {
    required String actorId,
    required String resolutionNote,
  }) => _reports.doc(id).update({
    'status': ReportStatus.resolved.name,
    'resolvedAt': FieldValue.serverTimestamp(),
    'resolvedBy': actorId,
    'resolutionNote': resolutionNote.trim(),
  });
}
