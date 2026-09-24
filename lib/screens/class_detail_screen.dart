import 'package:flutter/material.dart';

import '../models/class_model.dart';
import '../repositories/class_repository.dart';
import 'class_form_screen.dart';
import 'students_screen.dart';
import 'attendance_screen.dart';
import 'report_options_screen.dart';

class ClassDetailScreen extends StatefulWidget {
  const ClassDetailScreen({
    super.key,
    required this.schoolClass,
    required this.repository,
  });

  final ClassModel schoolClass;
  final ClassRepository repository;

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  late ClassModel _schoolClass = widget.schoolClass;
  bool _changingArchive = false;

  Future<void> _edit() async {
    final updated = await Navigator.push<ClassModel>(
      context,
      MaterialPageRoute(
        builder: (_) => ClassFormScreen(
          repository: widget.repository,
          schoolClass: _schoolClass,
        ),
      ),
    );
    if (updated != null && mounted) setState(() => _schoolClass = updated);
  }

  Future<void> _setArchived(bool archived) async {
    if (_changingArchive || _schoolClass.isArchived == archived) return;
    if (archived) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Archive class?'),
          content: const Text(
            'This class will move to archived classes. Its records will remain available.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Archive'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _changingArchive = true);
    try {
      if (archived) {
        await widget.repository.archive(_schoolClass.id);
      } else {
        await widget.repository.unarchive(_schoolClass.id);
      }
      if (!mounted) return;
      setState(
        () => _schoolClass = ClassModel(
          id: _schoolClass.id,
          grade: _schoolClass.grade,
          section: _schoolClass.section,
          academicYear: _schoolClass.academicYear,
          isArchived: archived,
          createdAt: _schoolClass.createdAt,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            archived ? 'Class archived.' : 'Class moved to active classes.',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to ${archived ? 'archive' : 'unarchive'} class. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _changingArchive = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: const Text('Class Details'),
      actions: [
        IconButton(
          tooltip: 'Edit class',
          onPressed: _changingArchive ? null : _edit,
          icon: const Icon(Icons.edit_outlined),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(30),
      children: [
        Text(
          'Grade ${_schoolClass.grade} - ${_schoolClass.section}',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.blue[700],
          ),
        ),
        const SizedBox(height: 8),
        Text('Academic Year ${_schoolClass.academicYear}'),
        const SizedBox(height: 8),
        if (_schoolClass.isArchived)
          const Align(
            alignment: Alignment.centerLeft,
            child: Chip(label: Text('Archived')),
          ),
        const SizedBox(height: 20),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.groups_outlined),
                title: const Text('Students'),
                subtitle: const Text('View students in this class'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('Students')),
                      body: StudentsScreen(initialClassId: _schoolClass.id),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.report_outlined),
                title: const Text('Report Options'),
                subtitle: const Text('Manage options for this class'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ReportOptionsScreen(schoolClass: _schoolClass),
                  ),
                ),
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.person_outline),
                title: Text('Assigned Teachers'),
                subtitle: Text('Coming soon'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.fact_check_outlined),
                title: const Text('Attendance'),
                subtitle: const Text('Review and correct daily attendance'),
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AttendanceScreen(schoolClass: _schoolClass),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.history_outlined),
                title: const Text('Attendance History'),
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ClassAttendanceHistoryScreen(schoolClass: _schoolClass),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: _changingArchive
              ? null
              : () => _setArchived(!_schoolClass.isArchived),
          icon: Icon(
            _schoolClass.isArchived
                ? Icons.unarchive_outlined
                : Icons.archive_outlined,
          ),
          label: Text(
            _changingArchive
                ? 'Saving…'
                : _schoolClass.isArchived
                ? 'Unarchive Class'
                : 'Archive Class',
          ),
        ),
      ],
    ),
  );
}
