import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/class_model.dart';
import '../models/attendance_model.dart';
import '../models/student_model.dart';
import '../models/student_report_model.dart';
import '../repositories/class_repository.dart';
import '../repositories/attendance_repository.dart';
import '../repositories/student_repository.dart';
import '../repositories/student_report_repository.dart';
import 'student_month_calendar.dart';

String _classLabel(ClassModel? item) => item == null
    ? 'Class unavailable'
    : 'Grade ${item.grade} - ${item.section} (${item.academicYear})';

class StudentsPage extends StatefulWidget {
  const StudentsPage({super.key, this.initialClassId});
  final String? initialClassId;

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  final _studentsRepository = StudentRepository();
  final _classesRepository = ClassRepository();
  late final _students = _studentsRepository.watchAll();
  late final _classes = _classesRepository.watchAll();
  late String? _classId = widget.initialClassId;
  String _search = '';
  bool _archived = false;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<ClassModel>>(
    stream: _classes,
    builder: (context, classSnapshot) => StreamBuilder<List<StudentModel>>(
      stream: _students,
      builder: (context, studentSnapshot) {
        if (classSnapshot.hasError || studentSnapshot.hasError) {
          return const Center(
            child: Text(
              'Unable to load students or classes. Please try again.',
            ),
          );
        }
        if (!classSnapshot.hasData || !studentSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final classes = [...classSnapshot.data!]
          ..sort((a, b) => _classLabel(a).compareTo(_classLabel(b)));
        final classById = {for (final item in classes) item.id: item};
        final query = _search.trim().toLowerCase();
        final students =
            studentSnapshot.data!
                .where(
                  (student) =>
                      student.isArchived == _archived &&
                      (_classId == null || student.classId == _classId) &&
                      (query.isEmpty ||
                          student.name.toLowerCase().contains(query)),
                )
                .toList()
              ..sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
              );
        return LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth < 600 ? 16.0 : 32.0;
            final availableWidth = constraints.maxWidth - horizontalPadding * 2;
            return ListView(
              padding: EdgeInsets.all(horizontalPadding),
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 180),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Students',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${students.length} ${_archived ? 'archived' : 'active'} students',
                                ),
                              ],
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: () => _openForm(
                              context,
                              repository: _studentsRepository,
                              classes: classes,
                              initialClassId: _classId,
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Add student'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: availableWidth < 320 ? availableWidth : 320,
                            child: TextField(
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.search),
                                labelText: 'Search student name',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) =>
                                  setState(() => _search = value),
                            ),
                          ),
                          SizedBox(
                            width: availableWidth < 280 ? availableWidth : 280,
                            child: DropdownButtonFormField<String?>(
                              isExpanded: true,
                              initialValue: classById.containsKey(_classId)
                                  ? _classId
                                  : null,
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
                                  DropdownMenuItem(
                                    value: item.id,
                                    child: Text(
                                      '${_classLabel(item)}${item.isArchived ? ' • Archived' : ''}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (value) =>
                                  setState(() => _classId = value),
                            ),
                          ),
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                value: false,
                                label: Text('Active'),
                              ),
                              ButtonSegment(
                                value: true,
                                label: Text('Archived'),
                              ),
                            ],
                            selected: {_archived},
                            onSelectionChanged: (values) =>
                                setState(() => _archived = values.first),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: students.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  _archived
                                      ? 'No archived students match these filters.'
                                      : 'No active students match these filters.',
                                ),
                              )
                            : Column(
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 14,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            'NAME',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            'ROLL',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            'CLASS',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 90,
                                          child: Text(
                                            'STATUS',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 1),
                                  for (final student in students) ...[
                                    InkWell(
                                      onTap: () => context.go(
                                        '/admin/students/${Uri.encodeComponent(student.id)}',
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 16,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                student.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(student.rollNumber),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                _classLabel(
                                                  classById[student.classId],
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            SizedBox(
                                              width: 90,
                                              child: Text(
                                                student.isArchived
                                                    ? 'Archived'
                                                    : 'Active',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const Divider(height: 1),
                                  ],
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    ),
  );
}

Future<void> _openForm(
  BuildContext context, {
  required StudentRepository repository,
  required List<ClassModel> classes,
  StudentModel? student,
  String? initialClassId,
}) => showDialog<void>(
  context: context,
  builder: (_) => _StudentFormDialog(
    repository: repository,
    classes: classes,
    student: student,
    initialClassId: initialClassId,
  ),
);

class _StudentFormDialog extends StatefulWidget {
  const _StudentFormDialog({
    required this.repository,
    required this.classes,
    this.student,
    this.initialClassId,
  });
  final StudentRepository repository;
  final List<ClassModel> classes;
  final StudentModel? student;
  final String? initialClassId;
  @override
  State<_StudentFormDialog> createState() => _StudentFormDialogState();
}

class _StudentFormDialogState extends State<_StudentFormDialog> {
  final _key = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.student?.name);
  late final _roll = TextEditingController(text: widget.student?.rollNumber);
  late String? _classId = widget.initialClassId ?? widget.student?.classId;
  bool _saving = false;
  bool _added = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _roll.dispose();
    super.dispose();
  }

  Future<void> _save(List<ClassModel> active) async {
    if (_saving || !_key.currentState!.validate()) return;
    if (_classId == null || !active.any((item) => item.id == _classId)) {
      setState(() => _error = 'Select an active class.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.student == null) {
        await widget.repository.create(
          name: _name.text.trim(),
          rollNumber: _roll.text.trim(),
          classId: _classId!,
        );
        _name.clear();
        _roll.clear();
        setState(() => _added = true);
      } else {
        await widget.repository.update(
          widget.student!.id,
          name: _name.text.trim(),
          rollNumber: _roll.text.trim(),
          classId: _classId!,
        );
        if (mounted) Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to save student. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.classes.where((item) => !item.isArchived).toList();
    return AlertDialog(
      title: Text(widget.student == null ? 'Add student' : 'Edit student'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _name,
                  maxLength: 200,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: 'Student name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => _required(value, 200),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _roll,
                  maxLength: 40,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: 'Roll number',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => _required(value, 40),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: active.any((item) => item.id == _classId)
                      ? _classId
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Class',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final item in active)
                      DropdownMenuItem(
                        value: item.id,
                        child: Text(
                          _classLabel(item),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _classId = value),
                ),
                if (active.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text('Add an active class before adding students.'),
                  ),
                if (_added)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'Student added. Enter another student or select Done.',
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(_added ? 'Done' : 'Cancel'),
        ),
        FilledButton(
          onPressed: _saving || active.isEmpty ? null : () => _save(active),
          child: Text(_saving ? 'Saving…' : 'Save student'),
        ),
      ],
    );
  }
}

String? _required(String? value, int max) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'This field is required.';
  if (text.length > max) return 'Use $max characters or fewer.';
  return null;
}

class StudentDetailPage extends StatefulWidget {
  const StudentDetailPage({super.key, required this.studentId, this.classId});
  final String studentId;
  final String? classId;
  @override
  State<StudentDetailPage> createState() => _StudentDetailPageState();
}

class _StudentDetailPageState extends State<StudentDetailPage> {
  final _students = StudentRepository();
  final _classes = ClassRepository();
  final _reports = StudentReportRepository();
  final _attendance = AttendanceRepository();
  final _roster = StudentRepository();
  late Future<List<StudentModel>>? _classRoster = widget.classId == null
      ? null
      : _roster.watchClass(widget.classId!).first;
  late Future<StudentModel?> _student = _students.get(widget.studentId);
  late Future<List<StudentReportModel>> _history = _reports.forStudent(
    widget.studentId,
  );
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  late Future<List<AttendanceModel>> _monthAttendance = _attendance
      .studentMonth(widget.studentId, _month);

  @override
  void didUpdateWidget(covariant StudentDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.studentId != widget.studentId) _reload();
    if (oldWidget.classId != widget.classId) {
      _classRoster = widget.classId == null
          ? null
          : _roster.watchClass(widget.classId!).first;
    }
  }

  void _changeMonth(DateTime month) => setState(() {
    _month = month;
    _monthAttendance = _attendance.studentMonth(widget.studentId, month);
  });
  bool _archiving = false;

  void _reload() => setState(() {
    _student = _students.get(widget.studentId);
    _history = _reports.forStudent(widget.studentId);
    _monthAttendance = _attendance.studentMonth(widget.studentId, _month);
  });

  Future<void> _archive(StudentModel student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Archive student?'),
        content: Text(
          '${student.name} will leave the active student list. Historical attendance will remain intact.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _archiving = true);
    try {
      await _students.archive(student.id);
      if (mounted) _reload();
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
  Widget build(BuildContext context) => FutureBuilder<StudentModel?>(
    future: _student,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: TextButton(
            onPressed: _reload,
            child: const Text('Unable to load student. Retry'),
          ),
        );
      }
      if (!snapshot.hasData &&
          snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      final student = snapshot.data;
      if (student == null) {
        return Center(
          child: TextButton(
            onPressed: () => context.go('/admin/students'),
            child: const Text('Student not found. Back to students'),
          ),
        );
      }
      return ListView(
        padding: const EdgeInsets.all(32),
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: () => context.go(
                    widget.classId == null
                        ? '/admin/students'
                        : '/admin/classes/${Uri.encodeComponent(widget.classId!)}',
                  ),
                  icon: const Icon(Icons.arrow_back),
                  label: Text(
                    widget.classId == null ? 'Students' : 'Class students',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.name,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          Text(
                            student.isArchived
                                ? 'Archived student'
                                : 'Active student',
                          ),
                        ],
                      ),
                    ),
                    if (!student.isArchived)
                      OutlinedButton.icon(
                        onPressed: _archiving
                            ? null
                            : () async {
                                final classes = await _classes.watchAll().first;
                                if (!context.mounted) return;
                                await _openForm(
                                  context,
                                  repository: _students,
                                  classes: classes,
                                  student: student,
                                );
                                if (mounted) _reload();
                              },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit'),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                FutureBuilder<ClassModel?>(
                  future: _classes.get(student.classId),
                  builder: (context, classSnapshot) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Wrap(
                        spacing: 64,
                        runSpacing: 20,
                        children: [
                          _Fact(
                            label: 'Roll number',
                            value: student.rollNumber,
                          ),
                          _Fact(
                            label: 'Class',
                            value: classSnapshot.hasError
                                ? 'Unable to load class'
                                : !classSnapshot.hasData
                                ? 'Loading…'
                                : _classLabel(classSnapshot.data),
                          ),
                          _Fact(
                            label: 'Status',
                            value: student.isArchived ? 'Archived' : 'Active',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (widget.classId == student.classId)
                  FutureBuilder<List<StudentModel>>(
                    future: _classRoster,
                    builder: (context, rosterSnapshot) {
                      if (!rosterSnapshot.hasData) {
                        return const SizedBox.shrink();
                      }
                      final roster = [...rosterSnapshot.data!]
                        ..sort(
                          (a, b) => _compareRoll(a.rollNumber, b.rollNumber),
                        );
                      final index = roster.indexWhere(
                        (item) => item.id == student.id,
                      );
                      if (index < 0) return const SizedBox.shrink();
                      void open(StudentModel next) => context.go(
                        '/admin/students/${Uri.encodeComponent(next.id)}?classId=${Uri.encodeComponent(student.classId)}',
                      );
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragEnd: (details) {
                          final speed = details.primaryVelocity ?? 0;
                          if (speed < -150 && index + 1 < roster.length) {
                            open(roster[index + 1]);
                          } else if (speed > 150 && index > 0) {
                            open(roster[index - 1]);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            children: [
                              IconButton(
                                tooltip: 'Previous student by roll number',
                                onPressed: index > 0
                                    ? () => open(roster[index - 1])
                                    : null,
                                icon: const Icon(Icons.chevron_left),
                              ),
                              Expanded(
                                child: Text(
                                  'Student ${index + 1} of ${roster.length} • Roll ${student.rollNumber}',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Next student by roll number',
                                onPressed: index + 1 < roster.length
                                    ? () => open(roster[index + 1])
                                    : null,
                                icon: const Icon(Icons.chevron_right),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 24),
                FutureBuilder<List<AttendanceModel>>(
                  future: _monthAttendance,
                  builder: (context, attendanceSnapshot) =>
                      FutureBuilder<List<StudentReportModel>>(
                        future: _history,
                        builder: (context, reportsSnapshot) {
                          if (attendanceSnapshot.hasError ||
                              reportsSnapshot.hasError) {
                            return Card(
                              child: ListTile(
                                title: const Text('Unable to load calendar.'),
                                trailing: TextButton(
                                  onPressed: _reload,
                                  child: const Text('Retry'),
                                ),
                              ),
                            );
                          }
                          if (!attendanceSnapshot.hasData ||
                              !reportsSnapshot.hasData) {
                            return const LinearProgressIndicator();
                          }
                          return StudentMonthCalendar(
                            attendance: attendanceSnapshot.data!,
                            reports: reportsSnapshot.data!,
                            month: _month,
                            onMonthChanged: _changeMonth,
                          );
                        },
                      ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Report history',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: _reload,
                      tooltip: 'Refresh reports',
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                FutureBuilder<List<StudentReportModel>>(
                  future: _history,
                  builder: (context, reportsSnapshot) {
                    if (reportsSnapshot.hasError) {
                      return const Card(
                        child: ListTile(title: Text('Unable to load reports.')),
                      );
                    }
                    if (!reportsSnapshot.hasData) {
                      return const LinearProgressIndicator();
                    }
                    if (reportsSnapshot.data!.isEmpty) {
                      return const Card(
                        child: ListTile(title: Text('No reports')),
                      );
                    }
                    return Card(
                      child: Column(
                        children: [
                          for (final report in reportsSnapshot.data!) ...[
                            ListTile(
                              title: Text(report.titleSnapshot),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${report.attendanceDateKey} • ${report.severity.name.toUpperCase()} • ${report.status.name}',
                                  ),
                                  if (report.details.trim().isNotEmpty)
                                    Text(report.details),
                                  if (report.resolutionNote
                                          ?.trim()
                                          .isNotEmpty ??
                                      false)
                                    Text(
                                      'Resolution: ${report.resolutionNote}',
                                    ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                          ],
                        ],
                      ),
                    );
                  },
                ),
                if (!student.isArchived) ...[
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _archiving ? null : () => _archive(student),
                      icon: const Icon(Icons.archive_outlined),
                      label: Text(
                        _archiving ? 'Archiving…' : 'Archive student',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    },
  );
}

int _compareRoll(String first, String second) {
  final firstNumber = int.tryParse(first.trim());
  final secondNumber = int.tryParse(second.trim());
  if (firstNumber != null && secondNumber != null) {
    return firstNumber.compareTo(secondNumber);
  }
  return first.toLowerCase().compareTo(second.toLowerCase());
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );
}
