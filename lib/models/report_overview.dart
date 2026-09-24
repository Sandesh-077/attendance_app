import 'student_report_model.dart';

class StudentReportGroup {
  StudentReportGroup(this.studentId, this.reports);
  final String studentId;
  final List<StudentReportModel> reports;

  List<StudentReportModel> get open =>
      reports.where((r) => r.status == ReportStatus.open).toList();
  int get openSerious =>
      open.where((r) => r.severity == ReportSeverity.serious).length;
  int monthlyCount(DateTime now) => reports.where((r) {
    final date = r.reportedAt.toDate();
    return date.year == now.year && date.month == now.month;
  }).length;
  Map<String, int> monthlyFrequency(DateTime now) {
    final counts = <String, int>{};
    for (final report in reports) {
      final date = report.reportedAt.toDate();
      if (date.year == now.year && date.month == now.month) {
        counts.update(report.titleSnapshot, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    return counts;
  }

  DateTime get latest => reports.first.reportedAt.toDate();
}

List<StudentReportGroup> groupStudentReports(
  List<StudentReportModel> reports,
  DateTime now,
) {
  final grouped = <String, List<StudentReportModel>>{};
  for (final report in reports) {
    grouped.putIfAbsent(report.studentId, () => []).add(report);
  }
  final result = [
    for (final entry in grouped.entries)
      StudentReportGroup(
        entry.key,
        entry.value..sort((a, b) => b.reportedAt.compareTo(a.reportedAt)),
      ),
  ];
  result.sort((a, b) {
    var order = b.openSerious.compareTo(a.openSerious);
    if (order != 0) return order;
    order = b.open.length.compareTo(a.open.length);
    if (order != 0) return order;
    order = b.monthlyCount(now).compareTo(a.monthlyCount(now));
    if (order != 0) return order;
    order = b.latest.compareTo(a.latest);
    return order != 0 ? order : a.studentId.compareTo(b.studentId);
  });
  return result;
}
