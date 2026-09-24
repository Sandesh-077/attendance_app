import 'package:ca_attendance/models/student_model.dart';
import 'package:ca_attendance/repositories/student_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

StudentModel student(
  String id, {
  bool archived = false,
  String classId = 'c',
}) => StudentModel(
  id: id,
  name: 'Name $id',
  rollNumber: id,
  classId: classId,
  isArchived: archived,
  createdAt: Timestamp.fromDate(DateTime(2025)),
);

void main() {
  test(
    'history resolves archived students and retains active classmates',
    () async {
      final lookedUp = <String>[];
      final roster = await resolveAttendanceHistoryRoster(
        'c',
        [student('active')],
        ['active', 'archived', 'archived', 'deleted', 'other-class'],
        (id) async {
          lookedUp.add(id);
          return switch (id) {
            'archived' => student(id, archived: true),
            'other-class' => student(id, classId: 'other'),
            _ => null,
          };
        },
      );

      expect(roster.map((student) => student.id), ['active', 'archived']);
      expect(lookedUp, ['archived', 'deleted', 'other-class']);
    },
  );
}
