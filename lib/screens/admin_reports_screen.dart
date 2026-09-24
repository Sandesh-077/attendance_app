import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/attendance_model.dart';
import '../models/class_model.dart';
import '../models/report_overview.dart';
import '../models/student_model.dart';
import '../models/student_report_model.dart';
import '../repositories/attendance_repository.dart';
import '../repositories/student_report_repository.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});
  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final _repository = StudentReportRepository();
  List<StudentReportModel>? _reports;
  Map<String, StudentModel> _students = {};
  Map<String, ClassModel> _classes = {};
  String? _error;
  String? _classId;
  bool _openOnly = false;
  bool _seriousOnly = false;
  bool _thisMonth = false;
  bool _history = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _reports = null;
      _error = null;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw StateError('Sign in required');
      final profile = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (profile.data()?['role'] != 'Admin') {
        throw StateError('Admin access required');
      }
      final reports = await _repository.adminAll();
      final students = await FirebaseFirestore.instance
          .collection('students')
          .get();
      final classes = await FirebaseFirestore.instance
          .collection('classes')
          .get();
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _students = {
          for (final doc in students.docs)
            doc.id: StudentModel.fromDocument(doc),
        };
        _classes = {
          for (final doc in classes.docs) doc.id: ClassModel.fromDocument(doc),
        };
      });
    } on FirebaseException catch (error) {
      if (mounted) {
        setState(
          () => _error =
              'Unable to load reports (${error.code}): ${error.message ?? 'Firebase request failed.'}',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Unable to load reports: $error');
      }
    }
  }

  String _className(String? id) {
    final item = _classes[id];
    return item == null
        ? 'Class unavailable'
        : 'Grade ${item.grade} - ${item.section}';
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_reports == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final now = DateTime.now();
    final groups = groupStudentReports(_reports!, now).where((group) {
      if (!_history && group.open.isEmpty) return false;
      final relevant = group.reports.where((report) {
        if (!_history && report.status != ReportStatus.open) return false;
        if (_classId != null && report.classId != _classId) return false;
        if (_openOnly && report.status != ReportStatus.open) return false;
        if (_seriousOnly && report.severity != ReportSeverity.serious) {
          return false;
        }
        if (_thisMonth) {
          final date = report.reportedAt.toDate();
          if (date.year != now.year || date.month != now.month) return false;
        }
        return true;
      });
      return relevant.isNotEmpty;
    }).toList();
    final classes = _classes.values.toList()
      ..sort(
        (a, b) =>
            '${a.grade} ${a.section}'.compareTo('${b.grade} ${b.section}'),
      );
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Reports',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ),
              IconButton(
                onPressed: _load,
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Needs Attention')),
              ButtonSegment(value: true, label: Text('History')),
            ],
            selected: {_history},
            onSelectionChanged: (value) =>
                setState(() => _history = value.first),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            initialValue: _classId,
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
                  child: Text(_className(item.id)),
                ),
            ],
            onChanged: (value) => setState(() => _classId = value),
          ),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('Open reports'),
                selected: _openOnly,
                onSelected: (v) => setState(() => _openOnly = v),
              ),
              FilterChip(
                label: const Text('Serious'),
                selected: _seriousOnly,
                onSelected: (v) => setState(() => _seriousOnly = v),
              ),
              FilterChip(
                label: const Text('This month'),
                selected: _thisMonth,
                onSelected: (v) => setState(() => _thisMonth = v),
              ),
            ],
          ),
          if (!_history)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Ordered by open serious reports, open reports, reports this month, then latest report.',
              ),
            ),
          if (groups.isEmpty)
            Padding(
              padding: const EdgeInsets.all(30),
              child: Text(
                _history
                    ? 'No student history matches these filters.'
                    : 'No students need attention with these filters.',
              ),
            ),
          for (final group in groups)
            Card(
              child: ListTile(
                leading: Icon(
                  _history ? Icons.history : Icons.report_outlined,
                  color: Colors.blue[700],
                ),
                title: Text(
                  _students[group.studentId]?.name ?? 'Student unavailable',
                ),
                subtitle: Text(
                  '${_className(_students[group.studentId]?.classId ?? group.reports.first.classId)}\n'
                  '${group.monthlyCount(now)} reports this month • ${group.openSerious} open serious • ${group.open.length} open\n'
                  'Latest: ${_date(group.latest)}',
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _StudentReportsDetail(
                        group: group,
                        student: _students[group.studentId],
                        className: _className,
                        repository: _repository,
                      ),
                    ),
                  );
                  if (mounted) await _load();
                },
              ),
            ),
        ],
      ),
    );
  }
}

String _date(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class _StudentReportsDetail extends StatefulWidget {
  const _StudentReportsDetail({
    required this.group,
    required this.student,
    required this.className,
    required this.repository,
  });
  final StudentReportGroup group;
  final StudentModel? student;
  final String Function(String?) className;
  final StudentReportRepository repository;
  @override
  State<_StudentReportsDetail> createState() => _StudentReportsDetailState();
}

class _StudentReportsDetailState extends State<_StudentReportsDetail> {
  late Future<List<AttendanceModel>> _attendance = AttendanceRepository()
      .studentMonth(widget.group.studentId, DateTime.now());
  late List<StudentReportModel> _reports = [...widget.group.reports];
  String? _savingId;
  String? _feedback;
  String? _feedbackReportId;
  bool _feedbackIsError = false;

  Future<void> _resolve(StudentReportModel report) async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _ResolveReportDialog(title: report.titleSnapshot),
    );
    if (note == null || !mounted) return;
    setState(() {
      _savingId = report.id;
      _feedback = null;
      _feedbackReportId = report.id;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw StateError('Sign in required');
      await widget.repository.resolve(
        report.id,
        actorId: uid,
        resolutionNote: note,
      );
      if (!mounted) return;
      setState(() {
        _reports = [
          for (final item in _reports)
            item.id == report.id
                ? item.resolvedLocally(actorId: uid, note: note)
                : item,
        ];
        _feedback = 'Report resolved and kept in history.';
        _feedbackIsError = false;
      });
    } on FirebaseException catch (error) {
      if (mounted) {
        setState(() {
          _feedback = switch (error.code) {
            'permission-denied' =>
              'Resolution was denied by Firestore rules. Check that this account is an Admin.',
            'not-found' => 'This report no longer exists. Refresh the page.',
            'unavailable' => 'Connection unavailable. Please try again.',
            _ => 'Could not resolve report (${error.code}). Please try again.',
          };
          _feedbackIsError = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _feedback = 'Could not resolve report. Please try again.';
          _feedbackIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _savingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final group = StudentReportGroup(widget.group.studentId, _reports);
    final monthly = group.monthlyFrequency(now).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Scaffold(
      appBar: AppBar(title: Text(widget.student?.name ?? 'Student reports')),
      body: RefreshIndicator(
        onRefresh: () async {
          final reports = await widget.repository.forStudent(
            widget.group.studentId,
          );
          final attendance = await AttendanceRepository().studentMonth(
            widget.group.studentId,
            DateTime.now(),
          );
          if (mounted) {
            setState(() {
              _reports = reports;
              _attendance = Future.value(attendance);
            });
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              widget.student?.name ?? 'Student unavailable',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              widget.className(
                widget.student?.classId ?? _reports.first.classId,
              ),
            ),
            const SizedBox(height: 18),
            Text('This month', style: Theme.of(context).textTheme.titleLarge),
            FutureBuilder<List<AttendanceModel>>(
              future: _attendance,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Card(
                    child: ListTile(
                      title: Text('Attendance summary unavailable'),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: LinearProgressIndicator(),
                  );
                }
                final data = snapshot.data!;
                int count(AttendanceStatus status) =>
                    data.where((a) => a.status == status).length;
                return Card(
                  child: ListTile(
                    title: const Text('Attendance'),
                    subtitle: Text(
                      '${count(AttendanceStatus.present)} present • ${count(AttendanceStatus.absent)} absent • ${count(AttendanceStatus.late)} late',
                    ),
                  ),
                );
              },
            ),
            Card(
              child: ListTile(
                title: const Text('Reports'),
                subtitle: Text(
                  '${group.monthlyCount(now)} total this month • ${group.open.where((r) {
                    final d = r.reportedAt.toDate();
                    return d.year == now.year && d.month == now.month;
                  }).length} unresolved this month • ${group.open.length} open overall',
                ),
              ),
            ),
            if (monthly.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Repeated reasons this month'),
                      for (final item in monthly)
                        Text('${item.key}: ${item.value}'),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 18),
            Text(
              'Report history',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final report in _reports)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_date(report.reportedAt.toDate())} • ${report.severity.name.toUpperCase()} • ${report.category.name}',
                      ),
                      const SizedBox(height: 4),
                      Text(
                        report.titleSnapshot,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (report.details.isNotEmpty) Text(report.details),
                      Text(widget.className(report.classId)),
                      const SizedBox(height: 8),
                      Chip(
                        avatar: Icon(
                          report.status == ReportStatus.open
                              ? Icons.pending_outlined
                              : Icons.check_circle_outline,
                          size: 18,
                        ),
                        label: Text(report.status.name.toUpperCase()),
                      ),
                      if (report.status == ReportStatus.resolved) ...[
                        if (report.resolvedAt != null)
                          Text(
                            'Resolved ${_date(report.resolvedAt!.toDate())}',
                          ),
                        if (report.resolutionNote?.isNotEmpty == true)
                          Text('Resolution: ${report.resolutionNote}'),
                      ] else
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.tonal(
                            onPressed: _savingId == null
                                ? () => _resolve(report)
                                : null,
                            child: _savingId == report.id
                                ? const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text('Saving…'),
                                    ],
                                  )
                                : const Text('Resolve'),
                          ),
                        ),
                      if (_feedback != null && _feedbackReportId == report.id)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _feedbackIsError
                                ? Theme.of(context).colorScheme.errorContainer
                                : Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _feedbackIsError
                                    ? Icons.error_outline
                                    : Icons.check_circle_outline,
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text(_feedback!)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ResolveReportDialog extends StatefulWidget {
  const _ResolveReportDialog({required this.title});
  final String title;

  @override
  State<_ResolveReportDialog> createState() => _ResolveReportDialogState();
}

class _ResolveReportDialogState extends State<_ResolveReportDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Resolve report?'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            maxLength: 2000,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Resolution note (optional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _note.text),
        child: const Text('Resolve'),
      ),
    ],
  );
}
