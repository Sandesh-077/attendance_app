import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/attendance_model.dart';
import '../models/class_model.dart';
import '../models/student_model.dart';
import '../models/report_option_model.dart';
import '../models/student_report_model.dart';
import '../repositories/attendance_repository.dart';
import '../repositories/report_option_repository.dart';
import '../repositories/student_repository.dart';
import '../repositories/student_report_repository.dart';

String attendanceDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

bool reportDetailsValid(ReportSeverity severity, String details) =>
    severity != ReportSeverity.serious || details.trim().length >= 10;

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({
    super.key,
    required this.schoolClass,
    this.initialDate,
  });
  final ClassModel schoolClass;
  final DateTime? initialDate;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _repository = AttendanceRepository();
  late DateTime _date = widget.initialDate ?? DateTime.now();
  List<StudentModel>? _students;
  Map<String, AttendanceModel> _existing = {};
  final Map<String, AttendanceStatus> _selected = {};
  final Map<String, int> _sessionReportCounts = {};
  Future<List<ReportOptionModel>>? _reportOptions;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _selected.clear();
    });
    try {
      final students = await StudentRepository().activeClass(
        widget.schoolClass.id,
      );
      final records = await _repository.classDay(
        widget.schoolClass.id,
        attendanceDateKey(_date),
      );
      if (!mounted) return;
      students.sort((a, b) => a.rollNumber.compareTo(b.rollNumber));
      final activeIds = students.map((student) => student.id).toSet();
      setState(() {
        _students = students;
        _existing = {for (final record in records) record.studentId: record};
        for (final record in records) {
          if (activeIds.contains(record.studentId)) {
            _selected[record.studentId] = record.status;
          }
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'Unable to load attendance. Check your access and connection.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _chooseDate() async {
    if (_saving) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null &&
        mounted &&
        attendanceDateKey(picked) != attendanceDateKey(_date)) {
      _date = picked;
      _sessionReportCounts.clear();
      await _load();
    }
  }

  Future<void> _report(StudentModel student) async {
    _reportOptions ??= ReportOptionRepository()
        .activeForClass(widget.schoolClass.id)
        .catchError((Object error) {
          _reportOptions = null;
          throw error;
        });
    final submitted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _StudentReportDialog(
        student: student,
        schoolClass: widget.schoolClass,
        dateKey: attendanceDateKey(_date),
        options: _reportOptions!,
      ),
    );
    if (submitted == true && mounted) {
      setState(
        () => _sessionReportCounts.update(
          student.id,
          (count) => count + 1,
          ifAbsent: () => 1,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report submitted for ${student.name}.')),
      );
    }
  }

  Future<void> _save() async {
    if (_saving ||
        _loading ||
        _students == null ||
        _students!.isEmpty ||
        _selected.length != _students!.length) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save attendance?'),
        content: Text(
          'Save ${_students!.length} students for ${attendanceDateKey(_date)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _saving) return;
    setState(() => _saving = true);
    try {
      final actor = FirebaseAuth.instance.currentUser?.uid;
      if (actor == null) throw StateError('Sign in required.');
      await _repository.saveClassDay(
        classId: widget.schoolClass.id,
        dateKey: attendanceDateKey(_date),
        statuses: Map.of(_selected),
        existing: _existing,
        actorId: actor,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Attendance saved.')));
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Save incomplete or failed. Reload this date before retrying.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        'Grade ${widget.schoolClass.grade} - ${widget.schoolClass.section} Attendance',
      ),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(child: Text('Date: ${attendanceDateKey(_date)}')),
              OutlinedButton.icon(
                onPressed: _saving ? null : _chooseDate,
                icon: const Icon(Icons.calendar_today),
                label: const Text('Change date'),
              ),
            ],
          ),
        ),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          Expanded(child: Center(child: Text(_error!)))
        else if (_students!.isEmpty)
          const Expanded(
            child: Center(child: Text('No active students in this class.')),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${_selected.length} of ${_students!.length} marked. Select a status for every student.',
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _students!.length,
              itemBuilder: (context, index) {
                final student = _students![index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${student.rollNumber}  ${student.name}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        SegmentedButton<AttendanceStatus>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: AttendanceStatus.present,
                              label: Text('Present'),
                            ),
                            ButtonSegment(
                              value: AttendanceStatus.absent,
                              label: Text('Absent'),
                            ),
                            ButtonSegment(
                              value: AttendanceStatus.late,
                              label: Text('Late'),
                            ),
                          ],
                          selected: _selected[student.id] == null
                              ? {}
                              : {_selected[student.id]!},
                          emptySelectionAllowed: true,
                          onSelectionChanged: _saving
                              ? null
                              : (value) => setState(
                                  () => _selected[student.id] = value.first,
                                ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed:
                                _saving || !_existing.containsKey(student.id)
                                ? null
                                : () => _report(student),
                            icon: const Icon(Icons.flag_outlined, size: 18),
                            label: Text(
                              !_existing.containsKey(student.id)
                                  ? 'Save attendance to report'
                                  : _sessionReportCounts[student.id] == null
                                  ? 'Report'
                                  : 'Report • ${_sessionReportCounts[student.id]}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving || _selected.length != _students!.length
                      ? null
                      : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                    _saving ? 'Saving…' : 'Review and save attendance',
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class _StudentReportDialog extends StatefulWidget {
  const _StudentReportDialog({
    required this.student,
    required this.schoolClass,
    required this.dateKey,
    required this.options,
  });

  final StudentModel student;
  final ClassModel schoolClass;
  final String dateKey;
  final Future<List<ReportOptionModel>> options;

  @override
  State<_StudentReportDialog> createState() => _StudentReportDialogState();
}

class _StudentReportDialogState extends State<_StudentReportDialog> {
  final _details = TextEditingController();
  ReportOptionModel? _option;
  ReportSeverity _severity = ReportSeverity.minor;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final details = _details.text.trim();
    if (_option == null) {
      setState(() => _error = 'Choose a report reason.');
      return;
    }
    if (!reportDetailsValid(_severity, details)) {
      setState(
        () => _error =
            'Serious reports need at least 10 characters of explanation.',
      );
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final actorId = FirebaseAuth.instance.currentUser?.uid;
      if (actorId == null) throw StateError('Sign in required.');
      await StudentReportRepository().create(
        studentId: widget.student.id,
        classId: widget.schoolClass.id,
        attendanceDateKey: widget.dateKey,
        option: _option!,
        severity: _severity,
        details: details,
        actorId: actorId,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is FirebaseException && error.code == 'permission-denied'
            ? 'You do not have permission to report this student.'
            : 'Unable to submit report. Check your connection and try again.';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_submitting,
    child: AlertDialog(
      title: Text('Report ${widget.student.name}'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Grade ${widget.schoolClass.grade} - ${widget.schoolClass.section} • ${widget.dateKey}',
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<ReportOptionModel>>(
                future: widget.options,
                builder: (context, snapshot) {
                  if (!snapshot.hasData && !snapshot.hasError) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Text(
                      snapshot.error is FirebaseException &&
                              (snapshot.error as FirebaseException).code ==
                                  'permission-denied'
                          ? 'You do not have access to report options for this class.'
                          : 'Unable to load report options. Close and try again.',
                    );
                  }
                  final options = snapshot.data!;
                  return DropdownButtonFormField<ReportOptionModel>(
                    initialValue: _option,
                    decoration: const InputDecoration(labelText: 'Reason'),
                    isExpanded: true,
                    items: [
                      for (final option in options)
                        DropdownMenuItem(
                          value: option,
                          child: Text(option.title),
                        ),
                    ],
                    onChanged: _submitting
                        ? null
                        : (value) => setState(() => _option = value),
                  );
                },
              ),
              const SizedBox(height: 16),
              SegmentedButton<ReportSeverity>(
                segments: const [
                  ButtonSegment(
                    value: ReportSeverity.minor,
                    label: Text('Minor'),
                  ),
                  ButtonSegment(
                    value: ReportSeverity.moderate,
                    label: Text('Moderate'),
                  ),
                  ButtonSegment(
                    value: ReportSeverity.serious,
                    label: Text('Serious'),
                  ),
                ],
                selected: {_severity},
                onSelectionChanged: _submitting
                    ? null
                    : (value) => setState(() => _severity = value.first),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _details,
                enabled: !_submitting,
                maxLength: 2000,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Details',
                  helperText: _severity == ReportSeverity.serious
                      ? 'Required: explain what happened (at least 10 characters).'
                      : _option?.category == ReportCategory.discipline
                      ? 'Please explain what happened.'
                      : 'Optional',
                ),
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting || _option == null ? null : _submit,
          child: Text(_submitting ? 'Submitting…' : 'Submit report'),
        ),
      ],
    ),
  );
}

class ClassAttendanceHistoryScreen extends StatefulWidget {
  const ClassAttendanceHistoryScreen({super.key, required this.schoolClass});
  final ClassModel schoolClass;
  @override
  State<ClassAttendanceHistoryScreen> createState() =>
      _ClassAttendanceHistoryScreenState();
}

class _ClassAttendanceHistoryScreenState
    extends State<ClassAttendanceHistoryScreen> {
  late Future<List<AttendanceModel>> _history = AttendanceRepository()
      .classHistory(widget.schoolClass.id);
  late final Future<List<StudentModel>> _roster = StudentRepository()
      .watchActiveClass(widget.schoolClass.id)
      .first;
  DateTime _selectedDate = DateUtils.dateOnly(
    DateTime.now().subtract(const Duration(days: 1)),
  );

  void _moveDay(int offset) {
    final next = DateUtils.dateOnly(_selectedDate.add(Duration(days: offset)));
    if (next.isAfter(DateUtils.dateOnly(DateTime.now()))) return;
    setState(() => _selectedDate = next);
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) setState(() => _selectedDate = picked);
  }

  Future<void> _openDate(String date) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => AttendanceScreen(
          schoolClass: widget.schoolClass,
          initialDate: DateTime.parse(date),
        ),
      ),
    );
    if (mounted) {
      setState(
        () => _history = AttendanceRepository().classHistory(
          widget.schoolClass.id,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Class attendance history')),
    body: FutureBuilder<List<AttendanceModel>>(
      future: _history,
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
                  ? 'You do not have access to this class history.'
                  : 'Unable to load history. Check your connection and try again.',
            ),
          );
        }
        final byDate = <String, List<AttendanceModel>>{};
        for (final record in snapshot.data!) {
          byDate.putIfAbsent(record.dateKey, () => []).add(record);
        }
        final date = attendanceDateKey(_selectedDate);
        final records = byDate[date] ?? [];
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: (details) {
            final speed = details.primaryVelocity ?? 0;
            if (speed < -150) _moveDay(1);
            if (speed > 150) _moveDay(-1);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Previous day',
                    onPressed: () => _moveDay(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDay,
                      icon: const Icon(Icons.calendar_month),
                      label: Text(date),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next day',
                    onPressed:
                        _selectedDate.isBefore(
                          DateUtils.dateOnly(DateTime.now()),
                        )
                        ? () => _moveDay(1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Swipe left or right to change the day.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (records.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No attendance recorded for this date.'),
                  ),
                )
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${records.length} students recorded',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${records.where((r) => r.status == AttendanceStatus.present).length} present',
                        ),
                        Text(
                          '${records.where((r) => r.status == AttendanceStatus.absent).length} absent',
                        ),
                        Text(
                          '${records.where((r) => r.status == AttendanceStatus.late).length} late',
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text('Students', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              FutureBuilder<List<StudentModel>>(
                future: _roster,
                builder: (context, rosterSnapshot) {
                  if (!rosterSnapshot.hasData && !rosterSnapshot.hasError) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final dayEnd = _selectedDate.add(const Duration(days: 1));
                  final students = (rosterSnapshot.data ?? [])
                      .where(
                        (student) =>
                            student.createdAt.toDate().isBefore(dayEnd),
                      )
                      .toList();
                  final studentById = {
                    for (final student in students) student.id: student,
                  };
                  final recordByStudent = {
                    for (final record in records) record.studentId: record,
                  };
                  final ids =
                      {...studentById.keys, ...recordByStudent.keys}.toList()
                        ..sort((a, b) {
                          final first = studentById[a];
                          final second = studentById[b];
                          if (first == null && second == null) {
                            return a.compareTo(b);
                          }
                          if (first == null) return 1;
                          if (second == null) return -1;
                          return first.rollNumber.compareTo(second.rollNumber);
                        });
                  if (rosterSnapshot.hasError && records.isEmpty) {
                    return const Text('Unable to load the student roster.');
                  }
                  if (ids.isEmpty) {
                    return const Text('No students to show for this date.');
                  }
                  return Column(
                    children: [
                      if (rosterSnapshot.hasError)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text('Student names are unavailable.'),
                        ),
                      for (final id in ids)
                        Card(
                          child: ListTile(
                            title: Text(studentById[id]?.name ?? 'Student $id'),
                            subtitle: Text(
                              studentById[id] == null
                                  ? 'No longer on the active roster'
                                  : 'Roll ${studentById[id]!.rollNumber}',
                            ),
                            trailing: Chip(
                              backgroundColor: switch (recordByStudent[id]
                                  ?.status) {
                                AttendanceStatus.present =>
                                  Colors.green.shade200,
                                AttendanceStatus.absent => Colors.red.shade200,
                                AttendanceStatus.late => Colors.amber.shade200,
                                null => null,
                              },
                              label: Text(switch (recordByStudent[id]?.status) {
                                AttendanceStatus.present => 'Present',
                                AttendanceStatus.absent => 'Absent',
                                AttendanceStatus.late => 'Late',
                                null => 'Not marked',
                              }),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _openDate(date),
                icon: const Icon(Icons.fact_check_outlined),
                label: Text(
                  records.isEmpty ? 'Take attendance' : 'Review attendance',
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class StudentAttendanceHistoryScreen extends StatefulWidget {
  const StudentAttendanceHistoryScreen({super.key, required this.student});
  final StudentModel student;
  @override
  State<StudentAttendanceHistoryScreen> createState() =>
      _StudentAttendanceHistoryScreenState();
}

class _StudentAttendanceHistoryScreenState
    extends State<StudentAttendanceHistoryScreen> {
  late final Future<List<AttendanceModel>> _history = AttendanceRepository()
      .studentHistory(widget.student.classId, widget.student.id);
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDate = DateUtils.dateOnly(
    DateTime.now().subtract(const Duration(days: 1)),
  );

  void _moveMonth(int offset) {
    final next = DateTime(_visibleMonth.year, _visibleMonth.month + offset);
    if (next.isAfter(DateTime(DateTime.now().year, DateTime.now().month))) {
      return;
    }
    setState(() => _visibleMonth = next);
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        _visibleMonth = DateTime(picked.year, picked.month);
        _selectedDate = picked;
      });
    }
  }

  Color? _statusColor(AttendanceStatus? status) => switch (status) {
    AttendanceStatus.present => Colors.green.shade200,
    AttendanceStatus.absent => Colors.red.shade200,
    AttendanceStatus.late => Colors.amber.shade200,
    null => null,
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('${widget.student.name} attendance')),
    body: FutureBuilder<List<AttendanceModel>>(
      future: _history,
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
                  ? 'You do not have access to this student history.'
                  : 'Unable to load history. Check your connection and try again.',
            ),
          );
        }
        final records = snapshot.data!;
        final byDate = {for (final record in records) record.dateKey: record};
        final firstWeekday = _visibleMonth.weekday - 1;
        final days = DateUtils.getDaysInMonth(
          _visibleMonth.year,
          _visibleMonth.month,
        );
        final chosen = byDate[attendanceDateKey(_selectedDate)];
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: (details) {
            final speed = details.primaryVelocity ?? 0;
            if (speed < -150) _moveMonth(1);
            if (speed > 150) _moveMonth(-1);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Previous month',
                    onPressed: () => _moveMonth(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickMonth,
                      icon: const Icon(Icons.calendar_month),
                      label: Text(
                        MaterialLocalizations.of(
                          context,
                        ).formatMonthYear(_visibleMonth),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next month',
                    onPressed:
                        _visibleMonth.isBefore(
                          DateTime(DateTime.now().year, DateTime.now().month),
                        )
                        ? () => _moveMonth(1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final day in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                    Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 5,
                  crossAxisSpacing: 5,
                ),
                itemCount: ((firstWeekday + days + 6) ~/ 7) * 7,
                itemBuilder: (context, index) {
                  final day = index - firstWeekday + 1;
                  if (day < 1 || day > days) return const SizedBox.shrink();
                  final date = DateTime(
                    _visibleMonth.year,
                    _visibleMonth.month,
                    day,
                  );
                  final record = byDate[attendanceDateKey(date)];
                  final selected =
                      attendanceDateKey(date) ==
                      attendanceDateKey(_selectedDate);
                  return Semantics(
                    label:
                        '${attendanceDateKey(date)}, ${record?.status.name ?? 'no record'}',
                    button: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _selectedDate = date),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _statusColor(record?.status),
                          borderRadius: BorderRadius.circular(12),
                          border: selected
                              ? Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 2,
                                )
                              : null,
                        ),
                        child: Text(
                          '$day',
                          style: TextStyle(
                            fontWeight: selected ? FontWeight.bold : null,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _LegendDot(color: Colors.green.shade200, label: 'Present'),
                  _LegendDot(color: Colors.red.shade200, label: 'Absent'),
                  _LegendDot(color: Colors.amber.shade200, label: 'Late'),
                  const _LegendDot(
                    color: Colors.transparent,
                    label: 'No record',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                child: ListTile(
                  title: Text(attendanceDateKey(_selectedDate)),
                  subtitle: Text(
                    chosen == null
                        ? 'No attendance recorded'
                        : 'Status: ${chosen.status.name}',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${records.length} recorded days • '
                '${records.where((r) => r.status == AttendanceStatus.present).length} present • '
                '${records.where((r) => r.status == AttendanceStatus.absent).length} absent • '
                '${records.where((r) => r.status == AttendanceStatus.late).length} late',
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(width: 5),
      Text(label),
    ],
  );
}
