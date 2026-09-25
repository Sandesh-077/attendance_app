import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/class_model.dart';
import '../models/teacher_assignment_model.dart';
import '../models/user_model.dart';
import '../repositories/class_repository.dart';
import '../repositories/teacher_assignment_repository.dart';
import '../repositories/teacher_repository.dart';

String _className(ClassModel item) =>
    'Grade ${item.grade} - ${item.section} (${item.academicYear})';

class WebTeachersPage extends StatefulWidget {
  const WebTeachersPage({super.key});

  @override
  State<WebTeachersPage> createState() => _WebTeachersPageState();
}

class _WebTeachersPageState extends State<WebTeachersPage> {
  final _teachers = TeacherRepository().watchAll();

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
      return ListView(
        padding: const EdgeInsets.all(32),
        children: [
          Text('Teachers', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text('View teachers and manage their class assignments.'),
          const SizedBox(height: 24),
          if (teachers.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No teacher accounts yet.'),
              ),
            ),
          for (final teacher in teachers)
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(
                  teacher.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  teacher.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go(
                  '/admin/teachers/${Uri.encodeComponent(teacher.uid)}',
                ),
              ),
            ),
        ],
      );
    },
  );
}

class WebTeacherDetailPage extends StatefulWidget {
  const WebTeacherDetailPage({super.key, required this.teacherId});
  final String teacherId;

  @override
  State<WebTeacherDetailPage> createState() => _WebTeacherDetailPageState();
}

class _WebTeacherDetailPageState extends State<WebTeacherDetailPage> {
  final _assignmentRepository = TeacherAssignmentRepository();
  late final _teachers = TeacherRepository().watchAll();
  late final _classes = ClassRepository().watchAll();
  late final _assignments = _assignmentRepository.watchTeacher(
    widget.teacherId,
  );
  bool _saving = false;

  Future<void> _assign(
    List<ClassModel> classes,
    List<TeacherAssignmentModel> assignments,
  ) async {
    final activeIds = assignments
        .where((item) => item.isActive)
        .map((item) => item.classId)
        .toSet();
    final available =
        classes
            .where((item) => !item.isArchived && !activeIds.contains(item.id))
            .toList()
          ..sort((a, b) => _className(a).compareTo(_className(b)));
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No unassigned active classes available.'),
        ),
      );
      return;
    }
    String selectedId = available.first.id;
    final subject = TextEditingController();
    try {
      final result = await showDialog<(String, String)>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Assign class'),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Class'),
                    items: [
                      for (final item in available)
                        DropdownMenuItem(
                          value: item.id,
                          child: Text(
                            _className(item),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedId = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: subject,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      labelText: 'Subject (optional)',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, (selectedId, subject.text)),
                child: const Text('Assign'),
              ),
            ],
          ),
        ),
      );
      if (result == null || !mounted) return;
      setState(() => _saving = true);
      try {
        await _assignmentRepository.assign(
          teacherId: widget.teacherId,
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
                error is StateError ? error.message : 'Unable to assign class.',
              ),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    } finally {
      subject.dispose();
    }
  }

  Future<void> _remove(TeacherAssignmentModel assignment) async {
    setState(() => _saving = true);
    try {
      await _assignmentRepository.setActive(
        widget.teacherId,
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
  Widget build(BuildContext context) => StreamBuilder<List<UserModel>>(
    stream: _teachers,
    builder: (context, teacherSnapshot) {
      if (teacherSnapshot.hasError) {
        return const Center(child: Text('Unable to load teacher.'));
      }
      if (!teacherSnapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      UserModel? teacher;
      for (final item in teacherSnapshot.data!) {
        if (item.uid == widget.teacherId) {
          teacher = item;
          break;
        }
      }
      if (teacher == null) {
        return const Center(child: Text('Teacher not found.'));
      }
      return StreamBuilder<List<ClassModel>>(
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
                final byId = {for (final item in classes) item.id: item};
                final active =
                    assignmentSnapshot.data!
                        .where((item) => item.isActive)
                        .toList()
                      ..sort(
                        (a, b) =>
                            (byId[a.classId] == null
                                    ? a.classId
                                    : _className(byId[a.classId]!))
                                .compareTo(
                                  byId[b.classId] == null
                                      ? b.classId
                                      : _className(byId[b.classId]!),
                                ),
                      );
                return ListView(
                  padding: const EdgeInsets.all(32),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => context.go('/admin/teachers'),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Teachers'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      teacher!.name,
                      style: Theme.of(context).textTheme.headlineMedium,
                      softWrap: true,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(teacher.email),
                    const SizedBox(height: 28),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 16,
                      runSpacing: 12,
                      children: [
                        Text(
                          'Assigned classes (${active.length})',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        FilledButton.icon(
                          onPressed: _saving
                              ? null
                              : () =>
                                    _assign(classes, assignmentSnapshot.data!),
                          icon: const Icon(Icons.add),
                          label: const Text('Assign class'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (active.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No classes assigned.'),
                        ),
                      ),
                    for (final assignment in active)
                      Card(
                        child: ListTile(
                          title: Text(
                            byId[assignment.classId] == null
                                ? 'Class unavailable (${assignment.classId})'
                                : _className(byId[assignment.classId]!),
                            softWrap: true,
                          ),
                          subtitle: assignment.subject == null
                              ? null
                              : Text(
                                  'Subject: ${assignment.subject}',
                                  softWrap: true,
                                ),
                          trailing: IconButton(
                            tooltip: 'Remove assignment',
                            onPressed: _saving
                                ? null
                                : () => _remove(assignment),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
      );
    },
  );
}

class WebAssignmentsPage extends StatefulWidget {
  const WebAssignmentsPage({super.key});
  @override
  State<WebAssignmentsPage> createState() => _WebAssignmentsPageState();
}

class _WebAssignmentsPageState extends State<WebAssignmentsPage> {
  final _teachers = TeacherRepository().watchAll();
  final _classes = ClassRepository().watchAll();
  final _assignments = TeacherAssignmentRepository().watchAll();

  @override
  Widget build(BuildContext context) => StreamBuilder<List<UserModel>>(
    stream: _teachers,
    builder: (context, teacherSnapshot) => StreamBuilder<List<ClassModel>>(
      stream: _classes,
      builder: (context, classSnapshot) => StreamBuilder<List<TeacherAssignmentModel>>(
        stream: _assignments,
        builder: (context, assignmentSnapshot) {
          if (teacherSnapshot.hasError ||
              classSnapshot.hasError ||
              assignmentSnapshot.hasError) {
            return const Center(child: Text('Unable to load assignments.'));
          }
          if (!teacherSnapshot.hasData ||
              !classSnapshot.hasData ||
              !assignmentSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final teachers = [...teacherSnapshot.data!]
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );
          final classes = {
            for (final item in classSnapshot.data!) item.id: item,
          };
          final assignments = assignmentSnapshot.data!
              .where((item) => item.isActive)
              .toList();
          return ListView(
            padding: const EdgeInsets.all(32),
            children: [
              Text(
                'Teacher/class assignments',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text('Open a teacher to assign or remove classes.'),
              const SizedBox(height: 24),
              if (teachers.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No teacher accounts yet.'),
                  ),
                ),
              for (final teacher in teachers)
                Builder(
                  builder: (context) {
                    final assigned =
                        assignments
                            .where((item) => item.teacherId == teacher.uid)
                            .toList()
                          ..sort(
                            (a, b) =>
                                (classes[a.classId] == null
                                        ? a.classId
                                        : _className(classes[a.classId]!))
                                    .compareTo(
                                      classes[b.classId] == null
                                          ? b.classId
                                          : _className(classes[b.classId]!),
                                    ),
                          );
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.person_outline),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        teacher.name,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                        softWrap: true,
                                      ),
                                      Text(teacher.email, softWrap: true),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => context.go(
                                    '/admin/teachers/${Uri.encodeComponent(teacher.uid)}',
                                  ),
                                  child: const Text('Manage'),
                                ),
                              ],
                            ),
                            const Divider(),
                            if (assigned.isEmpty)
                              const Text('No classes assigned.'),
                            for (final assignment in assigned)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Text(
                                  '• ${classes[assignment.classId] == null ? 'Class unavailable (${assignment.classId})' : _className(classes[assignment.classId]!)}${assignment.subject == null ? '' : ' — ${assignment.subject}'}',
                                  softWrap: true,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    ),
  );
}
