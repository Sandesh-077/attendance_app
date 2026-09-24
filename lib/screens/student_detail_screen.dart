import 'package:flutter/material.dart';

import '../models/class_model.dart';
import '../models/student_model.dart';
import '../models/student_report_model.dart';
import '../repositories/class_repository.dart';
import '../repositories/student_repository.dart';
import '../repositories/student_report_repository.dart';
import 'student_form_screen.dart';
import 'attendance_screen.dart';

class StudentDetailScreen extends StatefulWidget {
  const StudentDetailScreen({
    super.key,
    required this.student,
    required this.repository,
    required this.classRepository,
  });

  final StudentModel student;
  final StudentRepository repository;
  final ClassRepository classRepository;

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  late StudentModel _student = widget.student;
  late Future<List<StudentReportModel>> _reports = StudentReportRepository()
      .forStudent(widget.student.id);
  bool _archiving = false;

  void _reloadReports() => setState(() {
    _reports = StudentReportRepository().forStudent(_student.id);
  });

  String _reportDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _edit() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => StudentFormScreen(
          repository: widget.repository,
          classRepository: widget.classRepository,
          student: _student,
        ),
      ),
    );
    if (saved != true) return;
    try {
      final updated = await widget.repository.get(_student.id);
      if (mounted && updated != null) setState(() => _student = updated);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to refresh student details.')),
        );
      }
    }
  }

  Future<void> _archive() async {
    if (_archiving || _student.isArchived) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive student?'),
        content: Text(
          '${_student.name} will leave the active student list. Historical attendance will remain intact.',
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
    setState(() => _archiving = true);
    try {
      await widget.repository.archive(_student.id);
      if (!mounted) return;
      setState(
        () => _student = StudentModel(
          id: _student.id,
          name: _student.name,
          rollNumber: _student.rollNumber,
          classId: _student.classId,
          isArchived: true,
          createdAt: _student.createdAt,
        ),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Student archived.')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to archive student. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _archiving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: const Text('Student Details'),
      actions: [
        IconButton(
          tooltip: 'Edit student',
          onPressed: _student.isArchived || _archiving ? null : _edit,
          icon: const Icon(Icons.edit_outlined),
        ),
      ],
    ),
    body: FutureBuilder<ClassModel?>(
      future: widget.classRepository.get(_student.classId),
      builder: (context, snapshot) => ListView(
        padding: const EdgeInsets.all(30),
        children: [
          Text(
            _student.name,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.blue[700],
            ),
          ),
          if (_student.isArchived)
            const Align(
              alignment: Alignment.centerLeft,
              child: Chip(label: Text('Archived')),
            ),
          const SizedBox(height: 20),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Roll Number'),
                  subtitle: Text(_student.rollNumber),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Class'),
                  subtitle: Text(
                    snapshot.hasError
                        ? 'Unable to load class'
                        : snapshot.connectionState == ConnectionState.waiting
                        ? 'Loading…'
                        : snapshot.data == null
                        ? 'Class unavailable'
                        : 'Grade ${snapshot.data!.grade} - ${snapshot.data!.section} (${snapshot.data!.academicYear})',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: const Icon(Icons.history_outlined),
              title: const Text('Attendance History'),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      StudentAttendanceHistoryScreen(student: _student),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Reports',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Refresh reports',
                onPressed: _reloadReports,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          FutureBuilder<List<StudentReportModel>>(
            future: _reports,
            builder: (context, reportsSnapshot) {
              if (reportsSnapshot.hasError) {
                return Card(
                  child: ListTile(
                    title: const Text('Unable to load reports'),
                    trailing: TextButton(
                      onPressed: _reloadReports,
                      child: const Text('Retry'),
                    ),
                  ),
                );
              }
              if (!reportsSnapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator(),
                );
              }
              final reports = reportsSnapshot.data!;
              if (reports.isEmpty) {
                return const Card(child: ListTile(title: Text('No reports')));
              }
              return Column(
                children: [
                  for (final report in reports)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (report.status == ReportStatus.resolved)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  'Resolved',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            Text(
                              report.titleSnapshot,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_reportDate(report.reportedAt.toDate())} • ${report.severity.name.toUpperCase()}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (report.details.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(report.details),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          if (!_student.isArchived)
            OutlinedButton.icon(
              onPressed: _archiving ? null : _archive,
              icon: const Icon(Icons.archive_outlined),
              label: Text(_archiving ? 'Archiving…' : 'Archive Student'),
            ),
        ],
      ),
    ),
  );
}
