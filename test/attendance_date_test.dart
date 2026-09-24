import 'package:ca_attendance/models/attendance_model.dart';
import 'package:ca_attendance/screens/attendance_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('date key uses fixed width Gregorian calendar date', () {
    expect(attendanceDateKey(DateTime(2026, 1, 9)), '2026-01-09');
    expect(attendanceDateKey(DateTime(2026, 12, 31)), '2026-12-31');
  });

  test('attendance ID is deterministic for student and school date', () {
    expect(
      AttendanceModel.documentId('student1', '2026-01-09'),
      'student1_2026-01-09',
    );
  });
}
