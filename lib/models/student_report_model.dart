import 'package:cloud_firestore/cloud_firestore.dart';
import 'report_option_model.dart';

enum ReportSeverity { minor, moderate, serious }

enum ReportStatus { open, resolved }

class StudentReportModel {
  const StudentReportModel({
    required this.id,
    required this.studentId,
    required this.classId,
    required this.attendanceDateKey,
    required this.optionId,
    required this.category,
    required this.titleSnapshot,
    required this.severity,
    required this.details,
    required this.reportedBy,
    required this.reportedAt,
    required this.status,
    this.resolvedAt,
    this.resolvedBy,
    this.resolutionNote,
  });
  final String id,
      studentId,
      classId,
      attendanceDateKey,
      optionId,
      titleSnapshot,
      details,
      reportedBy;
  final ReportCategory category;
  final ReportSeverity severity;
  final Timestamp reportedAt;
  final ReportStatus status;
  final Timestamp? resolvedAt;
  final String? resolvedBy, resolutionNote;

  StudentReportModel resolvedLocally({
    required String actorId,
    required String note,
  }) => StudentReportModel(
    id: id,
    studentId: studentId,
    classId: classId,
    attendanceDateKey: attendanceDateKey,
    optionId: optionId,
    category: category,
    titleSnapshot: titleSnapshot,
    severity: severity,
    details: details,
    reportedBy: reportedBy,
    reportedAt: reportedAt,
    status: ReportStatus.resolved,
    resolvedBy: actorId,
    resolutionNote: note.trim(),
  );

  factory StudentReportModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d =
        doc.data() ?? (throw StateError('Missing student report ${doc.id}'));
    return StudentReportModel(
      id: doc.id,
      studentId: d['studentId'] as String,
      classId: d['classId'] as String,
      attendanceDateKey: d['attendanceDateKey'] as String,
      optionId: d['optionId'] as String,
      category: ReportCategory.values.byName(d['category'] as String),
      titleSnapshot: d['titleSnapshot'] as String,
      severity: ReportSeverity.values.byName(d['severity'] as String),
      details: d['details'] as String,
      reportedBy: d['reportedBy'] as String,
      reportedAt: d['reportedAt'] as Timestamp,
      status: ReportStatus.values.byName(d['status'] as String),
      resolvedAt: d['resolvedAt'] as Timestamp?,
      resolvedBy: d['resolvedBy'] as String?,
      resolutionNote: d['resolutionNote'] as String?,
    );
  }
}
