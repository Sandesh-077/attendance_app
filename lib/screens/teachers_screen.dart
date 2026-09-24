import 'package:flutter/material.dart';

import '../models/class_model.dart';
import '../models/teacher_assignment_model.dart';
import '../models/user_model.dart';
import '../repositories/class_repository.dart';
import '../repositories/teacher_assignment_repository.dart';
import '../repositories/teacher_repository.dart';

class TeachersScreen extends StatefulWidget {
  const TeachersScreen({super.key});

  @override
  State<TeachersScreen> createState() => _TeachersScreenState();
}

class _TeachersScreenState extends State<TeachersScreen> {
  final _repository = TeacherRepository();
  late final _teachers = _repository.watchAll();

  @override
  Widget build(BuildContext context) => StreamBuilder<List<UserModel>>(
    stream: _teachers,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(child: Text('Unable to load teachers.'));
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final teachers = [...snapshot.data!]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (teachers.isEmpty) {
        return const Center(child: Text('No teacher accounts yet.'));
      }
      return ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: teachers.length,
        itemBuilder: (context, index) {
          final teacher = teachers[index];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(teacher.name),
              subtitle: Text(teacher.email),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => TeacherDetailScreen(teacher: teacher),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class TeacherDetailScreen extends StatefulWidget {
  const TeacherDetailScreen({super.key, required this.teacher});
  final UserModel teacher;

  @override
  State<TeacherDetailScreen> createState() => _TeacherDetailScreenState();
}

class _TeacherDetailScreenState extends State<TeacherDetailScreen> {
  final _assignmentsRepository = TeacherAssignmentRepository();
  final _classRepository = ClassRepository();
  late final _assignments = _assignmentsRepository.watchTeacher(
    widget.teacher.uid,
  );
  late final _classes = _classRepository.watchAll();
  bool _saving = false;

  String _classLabel(ClassModel item) =>
      'Grade ${item.grade} - ${item.section} (${item.academicYear})';

  Future<void> _assign(
    List<ClassModel> classes,
    List<TeacherAssignmentModel> assignments,
  ) async {
    final activeIds = assignments
        .where((item) => item.isActive)
        .map((item) => item.classId)
        .toSet();
    final available = classes
        .where((item) => !item.isArchived && !activeIds.contains(item.id))
        .toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No unassigned active classes available.'),
        ),
      );
      return;
    }
    String selectedId = available.first.id;
    final subjectController = TextEditingController();
    try {
      final result = await showDialog<(String, String)>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Assign Class'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedId,
                  decoration: const InputDecoration(labelText: 'Class'),
                  isExpanded: true,
                  items: available
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(_classLabel(item)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => selectedId = value);
                  },
                ),
                TextField(
                  controller: subjectController,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'Subject (optional)',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, (
                  selectedId,
                  subjectController.text,
                )),
                child: const Text('Assign'),
              ),
            ],
          ),
        ),
      );
      if (result == null || !mounted) return;
      setState(() => _saving = true);
      try {
        await _assignmentsRepository.assign(
          teacherId: widget.teacher.uid,
          classId: result.$1,
          subject: result.$2,
        );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Class assigned.')));
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                error is StateError
                    ? error.message
                    : 'Unable to assign class. Please try again.',
              ),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    } finally {
      subjectController.dispose();
    }
  }

  Future<void> _deactivate(TeacherAssignmentModel assignment) async {
    setState(() => _saving = true);
    try {
      await _assignmentsRepository.setActive(
        widget.teacher.uid,
        assignment.classId,
        false,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Assignment removed.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to remove assignment.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Teacher Details')),
    body: StreamBuilder<List<ClassModel>>(
      stream: _classes,
      builder: (context, classSnapshot) =>
          StreamBuilder<List<TeacherAssignmentModel>>(
            stream: _assignments,
            builder: (context, assignmentSnapshot) {
              if (classSnapshot.hasError || assignmentSnapshot.hasError) {
                return const Center(
                  child: Text('Unable to load assigned classes.'),
                );
              }
              if (!classSnapshot.hasData || !assignmentSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final classes = classSnapshot.data!;
              final assignments = assignmentSnapshot.data!
                  .where((item) => item.isActive)
                  .toList();
              final byId = {for (final item in classes) item.id: item};
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    widget.teacher.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(widget.teacher.email),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Assigned Classes',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _saving
                            ? null
                            : () => _assign(classes, assignmentSnapshot.data!),
                        icon: const Icon(Icons.add),
                        label: const Text('Assign Class'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (assignments.isEmpty) const Text('No classes assigned.'),
                  for (final assignment in assignments)
                    Card(
                      child: ListTile(
                        title: Text(
                          byId[assignment.classId] == null
                              ? 'Class unavailable'
                              : _classLabel(byId[assignment.classId]!),
                        ),
                        subtitle: assignment.subject == null
                            ? null
                            : Text('Subject: ${assignment.subject}'),
                        trailing: IconButton(
                          tooltip: 'Remove assignment',
                          onPressed: _saving
                              ? null
                              : () => _deactivate(assignment),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
    ),
  );
}
