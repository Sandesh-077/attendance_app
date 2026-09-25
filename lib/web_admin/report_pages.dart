import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/class_model.dart';
import '../models/student_model.dart';
import '../models/student_report_model.dart';
import '../repositories/class_repository.dart';
import '../repositories/student_repository.dart';
import '../repositories/student_report_repository.dart';

String _className(ClassModel? item) => item == null
    ? 'Class unavailable'
    : 'Grade ${item.grade} - ${item.section}';
String _reportDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class WebReportsPage extends StatefulWidget {
  const WebReportsPage({super.key});
  @override
  State<WebReportsPage> createState() => _WebReportsPageState();
}

class _WebReportsPageState extends State<WebReportsPage> {
  Future<List<StudentReportModel>>? _future;
  final _students = <String, StudentModel?>{};
  final _classes = <String, ClassModel?>{};
  ReportStatus? _status = ReportStatus.open;
  ReportSeverity? _severity;
  String? _classId;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = _fetch();
    });
  }

  Future<List<StudentReportModel>> _fetch() async {
    final reports = await StudentReportRepository().adminAll();
    final students = await Future.wait(
      reports
          .map((r) => r.studentId)
          .toSet()
          .map((id) async => MapEntry(id, await StudentRepository().get(id))),
    );
    final classes = await Future.wait(
      reports
          .map((r) => r.classId)
          .toSet()
          .map((id) async => MapEntry(id, await ClassRepository().get(id))),
    );
    _students.addEntries(students);
    _classes.addEntries(classes);
    return reports;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<StudentReportModel>>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Unable to load reports.'),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final reports = snapshot.data!
          .where(
            (r) =>
                (_status == null || r.status == _status) &&
                (_severity == null || r.severity == _severity) &&
                (_classId == null || r.classId == _classId),
          )
          .toList();
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Student reports',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              IconButton(
                onPressed: _load,
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              DropdownButton<ReportStatus?>(
                value: _status,
                items: const [
                  DropdownMenuItem(
                    value: ReportStatus.open,
                    child: Text('Needs attention'),
                  ),
                  DropdownMenuItem(value: null, child: Text('All history')),
                  DropdownMenuItem(
                    value: ReportStatus.resolved,
                    child: Text('Resolved'),
                  ),
                ],
                onChanged: (v) => setState(() => _status = v),
              ),
              DropdownButton<ReportSeverity?>(
                value: _severity,
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All severities'),
                  ),
                  for (final severity in ReportSeverity.values)
                    DropdownMenuItem(
                      value: severity,
                      child: Text(severity.name),
                    ),
                ],
                onChanged: (v) => setState(() => _severity = v),
              ),
              DropdownButton<String?>(
                value: _classId,
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All classes'),
                  ),
                  for (final entry in _classes.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(_className(entry.value)),
                    ),
                ],
                onChanged: (v) => setState(() => _classId = v),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (reports.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No reports match these filters.'),
              ),
            )
          else
            Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Student')),
                    DataColumn(label: Text('Class')),
                    DataColumn(label: Text('Type')),
                    DataColumn(label: Text('Severity')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: [
                    for (final r in reports)
                      DataRow(
                        onSelectChanged: (_) => context.go(
                          '/admin/reports/${Uri.encodeComponent(r.id)}',
                        ),
                        cells: [
                          DataCell(Text(_reportDate(r.reportedAt.toDate()))),
                          DataCell(
                            Text(
                              _students[r.studentId]?.name ??
                                  'Student unavailable',
                            ),
                          ),
                          DataCell(Text(_className(_classes[r.classId]))),
                          DataCell(Text(r.titleSnapshot)),
                          DataCell(Text(r.severity.name)),
                          DataCell(Chip(label: Text(r.status.name))),
                        ],
                      ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

class WebReportDetail extends StatefulWidget {
  const WebReportDetail({super.key, required this.reportId});
  final String reportId;
  @override
  State<WebReportDetail> createState() => _WebReportDetailState();
}

class _WebReportDetailState extends State<WebReportDetail> {
  Future<(StudentReportModel?, StudentModel?, ClassModel?)>? _future;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _error = null;
      _future = _fetch();
    });
  }

  Future<(StudentReportModel?, StudentModel?, ClassModel?)> _fetch() async {
    final report = await StudentReportRepository().get(widget.reportId);
    if (report == null) return (null, null, null);
    final student = await StudentRepository().get(report.studentId);
    final schoolClass = await ClassRepository().get(report.classId);
    return (report, student, schoolClass);
  }

  Future<void> _resolve(StudentReportModel report) async {
    final note = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resolve report?'),
        content: SizedBox(
          width: 480,
          child: TextField(
            controller: note,
            maxLength: 2000,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Resolution note (optional)',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );
    final resolutionNote = note.text;
    note.dispose();
    if (confirmed != true || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final actor = FirebaseAuth.instance.currentUser?.uid;
      if (actor == null) throw StateError('Sign in required');
      await StudentReportRepository().resolve(
        report.id,
        actorId: actor,
        resolutionNote: resolutionNote,
      );
      if (mounted) _load();
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Unable to resolve report. Check access and connection.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<(StudentReportModel?, StudentModel?, ClassModel?)>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Unable to load report.'),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final (report, student, schoolClass) = snapshot.data!;
      if (report == null) {
        return const Center(child: Text('Report unavailable.'));
      }
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.go('/admin/reports'),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Reports'),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  report.titleSnapshot,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              IconButton(
                onPressed: _load,
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student?.name ?? 'Student unavailable',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      student == null
                          ? 'Student record unavailable'
                          : 'Roll ${student.rollNumber}',
                    ),
                    Text(_className(schoolClass)),
                    const Divider(height: 32),
                    _field('Reported', _reportDate(report.reportedAt.toDate())),
                    _field('Attendance date', report.attendanceDateKey),
                    _field(
                      'Type',
                      '${report.category.name} · ${report.titleSnapshot}',
                    ),
                    _field('Severity', report.severity.name),
                    _field('Status', report.status.name),
                    _field(
                      'Details',
                      report.details.isEmpty
                          ? 'No details supplied'
                          : report.details,
                    ),
                    if (report.status == ReportStatus.resolved) ...[
                      if (report.resolvedAt != null)
                        _field(
                          'Resolved',
                          _reportDate(report.resolvedAt!.toDate()),
                        ),
                      _field(
                        'Resolution note',
                        report.resolutionNote?.isNotEmpty == true
                            ? report.resolutionNote!
                            : 'No note supplied',
                      ),
                    ] else
                      FilledButton.icon(
                        onPressed: _saving ? null : () => _resolve(report),
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(_saving ? 'Resolving…' : 'Resolve report'),
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
        ],
      );
    },
  );
  Widget _field(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(value),
      ],
    ),
  );
}
