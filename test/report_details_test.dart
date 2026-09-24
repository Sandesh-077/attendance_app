import 'package:ca_attendance/models/student_report_model.dart';
import 'package:ca_attendance/screens/attendance_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serious reports require a meaningful trimmed explanation', () {
    expect(reportDetailsValid(ReportSeverity.serious, '          '), isFalse);
    expect(reportDetailsValid(ReportSeverity.serious, '  short  '), isFalse);
    expect(
      reportDetailsValid(ReportSeverity.serious, '  Repeated disruption  '),
      isTrue,
    );
    expect(reportDetailsValid(ReportSeverity.minor, ''), isTrue);
    expect(reportDetailsValid(ReportSeverity.moderate, ' '), isTrue);
    expect(
      reportDetailsValid(ReportSeverity.minor, ' ', requiresDetails: true),
      isFalse,
    );
    expect(
      reportDetailsValid(
        ReportSeverity.minor,
        ' explanation ',
        requiresDetails: true,
      ),
      isTrue,
    );
    expect(
      reportDetailsValid(
        ReportSeverity.serious,
        'short',
        requiresDetails: false,
      ),
      isFalse,
    );
  });
}
