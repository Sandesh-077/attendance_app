import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/class_model.dart';
import '../models/student_model.dart';
import '../repositories/class_repository.dart';
import '../repositories/student_repository.dart';
import 'student_detail_screen.dart';
import 'student_form_screen.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key, this.initialClassId});

  final String? initialClassId;

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final _studentsRepository = StudentRepository();
  final _classesRepository = ClassRepository();
  late final _students = _studentsRepository.watchAll();
  late final _classes = _classesRepository.watchAll();
  late String? _classId = widget.initialClassId;
  String _search = '';
  bool _showArchived = false;

  String _error(Object? error) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      return 'Your account does not have permission to view students.';
    }
    return 'Unable to load students. Please try again.';
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<ClassModel>>(
    stream: _classes,
    builder: (context, classesSnapshot) => StreamBuilder<List<StudentModel>>(
      stream: _students,
      builder: (context, studentsSnapshot) {
        if ((classesSnapshot.connectionState == ConnectionState.waiting &&
                !classesSnapshot.hasData) ||
            (studentsSnapshot.connectionState == ConnectionState.waiting &&
                !studentsSnapshot.hasData)) {
          return const Center(child: CircularProgressIndicator());
        }
        if (classesSnapshot.hasError || studentsSnapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Text(
                _error(classesSnapshot.error ?? studentsSnapshot.error),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final classes = [...?classesSnapshot.data]
          ..sort(
            (a, b) =>
                '${a.grade} ${a.section}'.compareTo('${b.grade} ${b.section}'),
          );
        final classById = {for (final item in classes) item.id: item};
        final students = [
          ...?studentsSnapshot.data,
        ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        final visible = students.where((student) {
          final matchesClass = _classId == null || student.classId == _classId;
          final query = _search.trim().toLowerCase();
          return student.isArchived == _showArchived &&
              matchesClass &&
              (query.isEmpty || student.name.toLowerCase().contains(query));
        }).toList();

        return ListView(
          padding: const EdgeInsets.all(30),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Students',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StudentFormScreen(
                        repository: _studentsRepository,
                        classRepository: _classesRepository,
                        fixedClassId: widget.initialClassId,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Student'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search student name',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _search = value),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show archived students'),
              value: _showArchived,
              onChanged: (value) => setState(() => _showArchived = value),
            ),
            DropdownButtonFormField<String?>(
              initialValue: classById.containsKey(_classId) ? _classId : null,
              decoration: const InputDecoration(
                labelText: 'Class',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All classes'),
                ),
                for (final item in classes)
                  DropdownMenuItem<String?>(
                    value: item.id,
                    child: Text(
                      'Grade ${item.grade} - ${item.section}${item.isArchived ? ' (Archived)' : ''}',
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _classId = value),
            ),
            const SizedBox(height: 20),
            if (visible.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    students.where((s) => s.isArchived == _showArchived).isEmpty
                        ? (_showArchived
                              ? 'No archived students.'
                              : 'No active students yet. Add a student to get started.')
                        : 'No students match your search or class filter.',
                  ),
                ),
              ),
            for (final student in visible)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(student.name),
                  subtitle: Text(
                    'Roll ${student.rollNumber} • ${classById[student.classId] == null ? 'Class unavailable' : 'Grade ${classById[student.classId]!.grade} - ${classById[student.classId]!.section}'}',
                  ),
                  trailing: student.isArchived
                      ? const Chip(label: Text('Archived'))
                      : const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StudentDetailScreen(
                        student: student,
                        repository: _studentsRepository,
                        classRepository: _classesRepository,
                      ),
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
