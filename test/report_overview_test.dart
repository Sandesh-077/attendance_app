import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ca_attendance/models/report_option_model.dart';
import 'package:ca_attendance/models/report_overview.dart';
import 'package:ca_attendance/models/student_report_model.dart';

StudentReportModel report(
  String id,
  String student,
  DateTime date, {
  ReportSeverity severity = ReportSeverity.minor,
  ReportStatus status = ReportStatus.open,
  String title = 'Equipment',
}) => StudentReportModel(
  id: id,
  studentId: student,
  classId: 'class',
  attendanceDateKey: '2026-09-01',
  optionId: 'option',
  category: ReportCategory.equipment,
  titleSnapshot: title,
  severity: severity,
  details: '',
  reportedBy: 'teacher',
  reportedAt: Timestamp.fromDate(date),
  status: status,
);

void main() {
  final now = DateTime(2026, 9, 25);
  test('open serious, open count, monthly count, and recency order groups', () {
    final groups = groupStudentReports([
      report('a', 'a', DateTime(2026, 9, 24)),
      report('b', 'b', DateTime(2026, 8, 24), severity: ReportSeverity.serious),
      report('c1', 'c', DateTime(2026, 9, 20)),
      report('c2', 'c', DateTime(2026, 9, 21)),
      report('d', 'd', DateTime(2026, 9, 23), status: ReportStatus.resolved),
    ], now);
    expect(groups.map((g) => g.studentId), ['b', 'c', 'a', 'd']);
    expect(groups.last.open, isEmpty);
    expect(groups.last.reports, hasLength(1));
  });

  test(
    'resolved history remains and monthly frequency counts actual reasons',
    () {
      final group = groupStudentReports([
        report('1', 'a', DateTime(2026, 9, 1), status: ReportStatus.resolved),
        report('2', 'a', DateTime(2026, 9, 2), status: ReportStatus.resolved),
        report('3', 'a', DateTime(2026, 8, 2), title: 'Dress'),
      ], now).single;
      expect(group.reports, hasLength(3));
      expect(group.open, hasLength(1));
      expect(group.monthlyCount(now), 2);
      expect(group.monthlyFrequency(now), {'Equipment': 2});
    },
  );

  test('local resolution keeps original report facts', () {
    final original = report('1', 'a', DateTime(2026, 9, 1));
    final resolved = original.resolvedLocally(
      actorId: 'admin',
      note: '  Reviewed  ',
    );
    expect(resolved.status, ReportStatus.resolved);
    expect(resolved.resolvedBy, 'admin');
    expect(resolved.resolutionNote, 'Reviewed');
    expect(resolved.id, original.id);
    expect(resolved.reportedAt, original.reportedAt);
    expect(resolved.reportedBy, original.reportedBy);
    expect(resolved.studentId, original.studentId);
    expect(resolved.classId, original.classId);
  });
}
