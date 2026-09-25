import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/attendance_model.dart';
import '../models/class_model.dart';
import '../models/student_model.dart';
import '../repositories/attendance_repository.dart';
import '../repositories/class_repository.dart';
import '../repositories/student_repository.dart';
import '../screens/attendance_screen.dart' show attendanceDateKey;

String _classLabel(ClassModel item) =>
    'Grade ${item.grade} - ${item.section} (${item.academicYear})';
String _day(DateTime date) => attendanceDateKey(date);
DateTime _initialDay(String? value) {
  final parsed = DateTime.tryParse(value ?? '');
  final today = DateUtils.dateOnly(DateTime.now());
  return parsed == null || parsed.isAfter(today)
      ? today
      : DateUtils.dateOnly(parsed);
}

class WebAttendanceIndex extends StatefulWidget {
  const WebAttendanceIndex({super.key});
  @override
  State<WebAttendanceIndex> createState() => _WebAttendanceIndexState();
}

class _WebAttendanceIndexState extends State<WebAttendanceIndex> {
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  @override
  Widget build(BuildContext context) => StreamBuilder<List<ClassModel>>(
    stream: ClassRepository().watchAll(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(
          child: Text('Unable to load classes. Check access and connection.'),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final classes = snapshot.data!.where((c) => !c.isArchived).toList()
        ..sort((a, b) => _classLabel(a).compareTo(_classLabel(b)));
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Attendance', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              final day = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (day != null && mounted) setState(() => _date = day);
            },
            icon: const Icon(Icons.calendar_month),
            label: Text(_day(_date)),
          ),
          const SizedBox(height: 16),
          if (classes.isEmpty) const Text('No active classes available.'),
          for (final item in classes)
            Card(
              child: ListTile(
                title: Text(_classLabel(item)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go(
                  '/admin/attendance/${Uri.encodeComponent(item.id)}?date=${_day(_date)}',
                ),
              ),
            ),
        ],
      );
    },
  );
}

class WebClassAttendance extends StatefulWidget {
  const WebClassAttendance({super.key, required this.classId, this.dateKey});
  final String classId;
  final String? dateKey;
  @override
  State<WebClassAttendance> createState() => _WebClassAttendanceState();
}

class _WebClassAttendanceState extends State<WebClassAttendance> {
  final _attendance = AttendanceRepository();
  final _students = StudentRepository();
  final _classes = ClassRepository();
  late DateTime _date = _initialDay(widget.dateKey);
  ClassModel? _class;
  List<StudentModel>? _roster;
  Map<String, AttendanceModel> _existing = {};
  final Map<String, AttendanceStatus> _selected = {};
  bool _loading = true, _saving = false;
  String? _error;
  bool get _dirty =>
      _selected.entries.any((e) => _existing[e.key]?.status != e.value);

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
      final results = await Future.wait<Object?>([
        _classes.get(widget.classId),
        _students.activeClass(widget.classId),
        _attendance.classDay(widget.classId, _day(_date)),
      ]);
      if (!mounted) return;
      final roster = results[1] as List<StudentModel>
        ..sort((a, b) => a.rollNumber.compareTo(b.rollNumber));
      final records = results[2] as List<AttendanceModel>;
      setState(() {
        _class = results[0] as ClassModel?;
        _roster = roster;
        _existing = {for (final r in records) r.studentId: r};
        for (final s in roster) {
          final status = _existing[s.id]?.status;
          if (status != null) _selected[s.id] = status;
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Unable to load attendance. Check access and connection.';
          _loading = false;
        });
      }
    }
  }

  Future<bool> _discard() async =>
      !_dirty ||
      await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Discard attendance changes?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Keep editing'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Discard'),
                ),
              ],
            ),
          ) ==
          true;
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null ||
        !mounted ||
        _day(picked) == _day(_date) ||
        !await _discard() ||
        !mounted) {
      return;
    }
    setState(() => _date = picked);
    context.go(
      '/admin/attendance/${Uri.encodeComponent(widget.classId)}?date=${_day(picked)}',
    );
    _load();
  }

  Future<void> _save() async {
    final roster = _roster;
    if (_saving ||
        roster == null ||
        roster.isEmpty ||
        _selected.length != roster.length) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save attendance?'),
        content: Text('Save ${roster.length} students for ${_day(_date)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      final actor = FirebaseAuth.instance.currentUser?.uid;
      if (actor == null) throw StateError('Sign in required');
      await _attendance.saveClassDay(
        classId: widget.classId,
        dateKey: _day(_date),
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
            content: Text('Save failed. Reload this date before retrying.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text(
        _class == null ? 'Class attendance' : _classLabel(_class!),
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: _saving ? null : _pickDate,
            icon: const Icon(Icons.calendar_month),
            label: Text(_day(_date)),
          ),
          OutlinedButton.icon(
            onPressed: _saving
                ? null
                : () async {
                    if (await _discard() && context.mounted) {
                      context.go(
                        '/admin/attendance/${Uri.encodeComponent(widget.classId)}/history?date=${_day(_date)}',
                      );
                    }
                  },
            icon: const Icon(Icons.history),
            label: const Text('History'),
          ),
          IconButton(
            onPressed: _saving ? null : _load,
            tooltip: 'Reload',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      if (_loading)
        const Center(child: CircularProgressIndicator())
      else if (_error != null)
        Text(_error!)
      else if (_class == null)
        const Text('Class unavailable.')
      else if (_roster!.isEmpty)
        const Text('No active students in this class.')
      else ...[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            '${_selected.length} of ${_roster!.length} marked. Select every student before saving.',
          ),
        ),
        Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Roll')),
                DataColumn(label: Text('Student')),
                DataColumn(label: Text('Status')),
              ],
              rows: [
                for (final s in _roster!)
                  DataRow(
                    cells: [
                      DataCell(Text(s.rollNumber)),
                      DataCell(Text(s.name)),
                      DataCell(
                        SegmentedButton<AttendanceStatus>(
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
                          emptySelectionAllowed: true,
                          selected: _selected[s.id] == null
                              ? {}
                              : {_selected[s.id]!},
                          onSelectionChanged: _saving
                              ? null
                              : (values) => setState(
                                  () => _selected[s.id] = values.first,
                                ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _saving || _selected.length != _roster!.length
                ? null
                : _save,
            icon: const Icon(Icons.save),
            label: Text(_saving ? 'Saving…' : 'Review and save'),
          ),
        ),
      ],
    ],
  );
}

class WebAttendanceHistory extends StatefulWidget {
  const WebAttendanceHistory({
    super.key,
    required this.classId,
    this.dateKey,
    this.studentId,
  });
  final String classId;
  final String? dateKey, studentId;
  @override
  State<WebAttendanceHistory> createState() => _WebAttendanceHistoryState();
}

class _WebAttendanceHistoryState extends State<WebAttendanceHistory> {
  late DateTime _date = _initialDay(widget.dateKey);
  late String? _studentId = widget.studentId;
  Future<(ClassModel?, List<AttendanceModel>, List<StudentModel>)>? _future;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = _fetch();
    });
  }

  Future<(ClassModel?, List<AttendanceModel>, List<StudentModel>)>
  _fetch() async {
    final records = await AttendanceRepository().classHistory(widget.classId);
    final roster = await StudentRepository().attendanceHistoryRoster(
      widget.classId,
      records.map((r) => r.studentId),
    );
    return (await ClassRepository().get(widget.classId), records, roster);
  }

  void _setState({
    DateTime? date,
    String? studentId,
    bool changeStudent = false,
  }) {
    setState(() {
      if (date != null) _date = date;
      if (changeStudent) _studentId = studentId;
    });
    final query = <String, String>{'date': _day(_date)};
    if (_studentId != null) query['studentId'] = _studentId!;
    context.go(
      Uri(
        path:
            '/admin/attendance/${Uri.encodeComponent(widget.classId)}/history',
        queryParameters: query,
      ).toString(),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<(ClassModel?, List<AttendanceModel>, List<StudentModel>)>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Unable to load history.'),
              TextButton(onPressed: _reload, child: const Text('Retry')),
            ],
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final (schoolClass, all, roster) = snapshot.data!;
      if (schoolClass == null) {
        return const Center(child: Text('Class unavailable.'));
      }
      final students = {for (final s in roster) s.id: s};
      final dayRecords = all
          .where(
            (r) =>
                r.dateKey == _day(_date) &&
                (_studentId == null || r.studentId == _studentId),
          )
          .toList();
      final filtered = all
          .where((r) => _studentId == null || r.studentId == _studentId)
          .toList();
      final dates = filtered.map((r) => r.dateKey).toSet().toList()
        ..sort((a, b) => b.compareTo(a));
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            '${_classLabel(schoolClass)} history',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null && context.mounted) {
                    _setState(date: picked);
                  }
                },
                icon: const Icon(Icons.calendar_month),
                label: Text(_day(_date)),
              ),
              DropdownButton<String?>(
                value: students.containsKey(_studentId) ? _studentId : null,
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All students'),
                  ),
                  for (final s
                      in roster..sort((a, b) => a.name.compareTo(b.name)))
                    DropdownMenuItem(value: s.id, child: Text(s.name)),
                ],
                onChanged: (id) =>
                    _setState(studentId: id, changeStudent: true),
              ),
              IconButton(
                onPressed: _reload,
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
              ),
              OutlinedButton(
                onPressed: () => context.go(
                  '/admin/attendance/${Uri.encodeComponent(widget.classId)}?date=${_day(_date)}',
                ),
                child: const Text('Take or review attendance'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Selected date', style: Theme.of(context).textTheme.titleLarge),
          if (dayRecords.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No attendance recorded for this date.'),
              ),
            )
          else
            Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Roll')),
                    DataColumn(label: Text('Student')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: [
                    for (final r in dayRecords)
                      DataRow(
                        cells: [
                          DataCell(
                            Text(students[r.studentId]?.rollNumber ?? '—'),
                          ),
                          DataCell(
                            Text(
                              students[r.studentId]?.name ??
                                  'Student unavailable',
                            ),
                          ),
                          DataCell(Text(r.status.name)),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
          Text('Recorded dates', style: Theme.of(context).textTheme.titleLarge),
          if (dates.isEmpty) const Text('No attendance history found.'),
          for (final date in dates)
            ListTile(
              title: Text(date),
              subtitle: Text(
                '${filtered.where((r) => r.dateKey == date).length} records',
              ),
              onTap: () => _setState(date: DateTime.parse(date)),
            ),
        ],
      );
    },
  );
}
