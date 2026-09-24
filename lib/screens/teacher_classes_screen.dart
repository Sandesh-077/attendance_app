import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/class_model.dart';
import '../models/student_model.dart';
import '../models/teacher_assignment_model.dart';
import '../repositories/class_repository.dart';
import '../repositories/student_repository.dart';
import '../repositories/teacher_assignment_repository.dart';
import 'attendance_screen.dart';

class TeacherClassesScreen extends StatefulWidget {
  const TeacherClassesScreen({
    super.key,
    required this.teacherId,
    this.attendanceMode = false,
  });
  final String teacherId;
  final bool attendanceMode;

  @override
  State<TeacherClassesScreen> createState() => _TeacherClassesScreenState();
}

class _TeacherClassesScreenState extends State<TeacherClassesScreen> {
  late final Stream<List<TeacherAssignmentModel>> _assignments =
      TeacherAssignmentRepository().watchTeacher(widget.teacherId);

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<List<TeacherAssignmentModel>>(
        stream: _assignments,
        builder: (context, snapshot) {
          if (!snapshot.hasData && !snapshot.hasError) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text('Unable to load your classes. Please try again.'),
            );
          }
          final assignments = snapshot.data!.where((a) => a.isActive).toList();
          if (assignments.isEmpty) {
            return const Center(
              child: Text('No classes are assigned to you yet.'),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(30),
            children: [
              Text(
                widget.attendanceMode ? 'Attendance' : 'My Classes',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
              const SizedBox(height: 20),
              if (widget.attendanceMode)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text('Choose a class to mark or review attendance.'),
                ),
              for (final assignment in assignments)
                _AssignedClassTile(
                  key: ValueKey(assignment.classId),
                  assignment: assignment,
                ),
            ],
          );
        },
      );
}

class _AssignedClassTile extends StatefulWidget {
  const _AssignedClassTile({super.key, required this.assignment});
  final TeacherAssignmentModel assignment;

  @override
  State<_AssignedClassTile> createState() => _AssignedClassTileState();
}

class _AssignedClassTileState extends State<_AssignedClassTile> {
  late final Future<ClassModel?> _schoolClass = ClassRepository().get(
    widget.assignment.classId,
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<ClassModel?>(
    future: _schoolClass,
    builder: (context, snapshot) {
      if (!snapshot.hasData &&
          !snapshot.hasError &&
          snapshot.connectionState != ConnectionState.done) {
        return const Card(child: ListTile(title: Text('Loading class…')));
      }
      if (snapshot.hasError) {
        return const Card(
          child: ListTile(title: Text('Unable to load an assigned class.')),
        );
      }
      final schoolClass = snapshot.data;
      if (schoolClass == null) {
        return const Card(
          child: ListTile(title: Text('Assigned class unavailable.')),
        );
      }
      return Card(
        child: ListTile(
          leading: const Icon(Icons.class_outlined),
          title: Text('Grade ${schoolClass.grade} - ${schoolClass.section}'),
          subtitle: Text(
            'Academic Year ${schoolClass.academicYear}'
            '${widget.assignment.subject == null ? '' : ' • ${widget.assignment.subject}'}',
          ),
          trailing: schoolClass.isArchived
              ? const Chip(label: Text('Archived'))
              : const Icon(Icons.chevron_right),
          onTap: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => TeacherClassDetailScreen(classId: schoolClass.id),
            ),
          ),
        ),
      );
    },
  );
}

class TeacherClassDetailScreen extends StatefulWidget {
  const TeacherClassDetailScreen({super.key, required this.classId});
  final String classId;

  @override
  State<TeacherClassDetailScreen> createState() =>
      _TeacherClassDetailScreenState();
}

class _TeacherClassDetailScreenState extends State<TeacherClassDetailScreen> {
  late final Future<ClassModel?> _schoolClass = ClassRepository().get(
    widget.classId,
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Class Details')),
    body: FutureBuilder<ClassModel?>(
      future: _schoolClass,
      builder: (context, snapshot) {
        if (!snapshot.hasData &&
            !snapshot.hasError &&
            snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          final denied =
              snapshot.error is FirebaseException &&
              (snapshot.error as FirebaseException).code == 'permission-denied';
          return Center(
            child: Text(
              denied
                  ? 'You do not have access to this class.'
                  : 'Unable to load class details. Please try again.',
            ),
          );
        }
        final schoolClass = snapshot.data;
        if (schoolClass == null) {
          return const Center(child: Text('This class is unavailable.'));
        }
        return ListView(
          padding: const EdgeInsets.all(30),
          children: [
            Text(
              'Grade ${schoolClass.grade} - ${schoolClass.section}',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
            const SizedBox(height: 8),
            Text('Academic Year ${schoolClass.academicYear}'),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                leading: const Icon(Icons.fact_check_outlined),
                title: const Text('Take Attendance'),
                trailing: const Icon(Icons.chevron_right),
                onTap: schoolClass.isArchived
                    ? null
                    : () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AttendanceScreen(schoolClass: schoolClass),
                        ),
                      ),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.history_outlined),
                title: const Text('Attendance History'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ClassAttendanceHistoryScreen(schoolClass: schoolClass),
                  ),
                ),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.groups_outlined),
                title: const Text('Students'),
                subtitle: const Text('View active students in this class'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        TeacherClassRosterScreen(classId: schoolClass.id),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class TeacherClassRosterScreen extends StatefulWidget {
  const TeacherClassRosterScreen({super.key, required this.classId});
  final String classId;

  @override
  State<TeacherClassRosterScreen> createState() =>
      _TeacherClassRosterScreenState();
}

class _TeacherClassRosterScreenState extends State<TeacherClassRosterScreen> {
  late final Stream<List<StudentModel>> _students = StudentRepository()
      .watchActiveClass(widget.classId);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Class Roster')),
    body: StreamBuilder<List<StudentModel>>(
      stream: _students,
      builder: (context, snapshot) {
        if (!snapshot.hasData && !snapshot.hasError) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          final denied =
              snapshot.error is FirebaseException &&
              (snapshot.error as FirebaseException).code == 'permission-denied';
          return Center(
            child: Text(
              denied
                  ? 'You do not have access to this roster.'
                  : 'Unable to load students. Please try again.',
            ),
          );
        }
        final students = [...snapshot.data!]
          ..sort((a, b) => a.rollNumber.compareTo(b.rollNumber));
        if (students.isEmpty) {
          return const Center(
            child: Text('No active students in this class yet.'),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(30),
          itemCount: students.length,
          itemBuilder: (context, index) {
            final student = students[index];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(student.name),
                subtitle: Text('Roll ${student.rollNumber}'),
                trailing: const Icon(Icons.history_outlined),
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        StudentAttendanceHistoryScreen(student: student),
                  ),
                ),
              ),
            );
          },
        );
      },
    ),
  );
}
