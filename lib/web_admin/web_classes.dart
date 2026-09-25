import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/class_model.dart';
import '../models/student_model.dart';
import '../repositories/class_repository.dart';
import '../repositories/student_repository.dart';

final class WebClassesPage extends StatefulWidget {
  const WebClassesPage({super.key});

  @override
  State<WebClassesPage> createState() => _WebClassesPageState();
}

class _WebClassesPageState extends State<WebClassesPage> {
  final _repository = ClassRepository();
  late final _stream = _repository.watchAll();
  String _query = '';
  bool _showArchived = false;
  String? _busyId;

  Future<void> _create() async {
    final values = await showDialog<(String, String, String)>(
      context: context,
      builder: (_) => const ClassEditor(),
    );
    if (values == null) return;
    try {
      final id = await _repository.create(
        grade: values.$1,
        section: values.$2,
        academicYear: values.$3,
      );
      if (mounted) context.go('/admin/classes/$id');
    } catch (_) {
      _message('Unable to create class. Please try again.');
    }
  }

  Future<void> _archive(ClassModel item) async {
    if (_busyId != null) return;
    if (!item.isArchived) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Archive class?'),
          content: Text(
            'Grade ${item.grade} - ${item.section} will move to archived classes. Its records will remain available.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Archive'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _busyId = item.id);
    try {
      if (item.isArchived) {
        await _repository.unarchive(item.id);
      } else {
        await _repository.archive(item.id);
      }
      _message(
        item.isArchived ? 'Class moved to active classes.' : 'Class archived.',
      );
    } catch (_) {
      _message('Unable to update class. Please try again.');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<ClassModel>>(
    stream: _stream,
    builder: (context, snapshot) {
      final classes = [...?snapshot.data]
        ..sort((a, b) {
          final year = b.academicYear.compareTo(a.academicYear);
          if (year != 0) return year;
          final grade = a.grade.compareTo(b.grade);
          return grade != 0 ? grade : a.section.compareTo(b.section);
        });
      final count = classes.where((c) => c.isArchived == _showArchived).length;
      final shown = classes
          .where(
            (c) =>
                c.isArchived == _showArchived &&
                'grade ${c.grade} ${c.section} ${c.academicYear}'
                    .toLowerCase()
                    .contains(_query.toLowerCase()),
          )
          .toList();
      return ListView(
        padding: const EdgeInsets.all(32),
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Classes',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const Text('Manage class details and archived records.'),
                ],
              ),
              FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: const Text('Add class'),
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
                width: 320,
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Search classes',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Active')),
                  ButtonSegment(value: true, label: Text('Archived')),
                ],
                selected: {_showArchived},
                onSelectionChanged: (s) =>
                    setState(() => _showArchived = s.first),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData)
            const Center(child: CircularProgressIndicator())
          else if (snapshot.hasError)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Unable to load classes. Check your access or connection and try again.',
                ),
              ),
            )
          else if (shown.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  count == 0
                      ? 'No ${_showArchived ? 'archived' : 'active'} classes.'
                      : 'No classes match your search.',
                ),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final item in shown) ...[
                    ListTile(
                      leading: Icon(
                        item.isArchived
                            ? Icons.archive_outlined
                            : Icons.class_outlined,
                      ),
                      title: Text('Grade ${item.grade} - ${item.section}'),
                      subtitle: Text('Academic Year ${item.academicYear}'),
                      onTap: () => context.go(
                        '/admin/classes/${Uri.encodeComponent(item.id)}',
                      ),
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Class actions',
                        enabled: _busyId == null,
                        onSelected: (_) => _archive(item),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'archive',
                            child: Text(
                              item.isArchived ? 'Unarchive' : 'Archive',
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (item != shown.last) const Divider(height: 1),
                  ],
                ],
              ),
            ),
        ],
      );
    },
  );
}

class WebClassDetailPage extends StatefulWidget {
  const WebClassDetailPage({super.key, required this.classId});
  final String classId;
  @override
  State<WebClassDetailPage> createState() => _WebClassDetailPageState();
}

class _WebClassDetailPageState extends State<WebClassDetailPage> {
  final _repository = ClassRepository();
  final _students = StudentRepository();
  late Future<ClassModel?> _class = _repository.get(widget.classId);
  bool _busy = false;

  void _reload() => setState(() {
    _class = _repository.get(widget.classId);
  });

  Future<void> _edit(ClassModel item) async {
    final values = await showDialog<(String, String, String)>(
      context: context,
      builder: (_) => ClassEditor(schoolClass: item),
    );
    if (values == null) return;
    setState(() => _busy = true);
    try {
      await _repository.updateDetails(
        item.id,
        grade: values.$1,
        section: values.$2,
        academicYear: values.$3,
      );
      _reload();
    } catch (_) {
      _message('Unable to save class. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _archive(ClassModel item) async {
    if (!item.isArchived) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Archive class?'),
          content: const Text('Its records will remain available.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Archive'),
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      if (item.isArchived) {
        await _repository.unarchive(item.id);
      } else {
        await _repository.archive(item.id);
      }
      _reload();
    } catch (_) {
      _message('Unable to update class. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ClassModel?>(
    future: _class,
    builder: (context, snapshot) {
      if (!snapshot.hasData &&
          !snapshot.hasError &&
          snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Unable to load class.'),
              TextButton(onPressed: _reload, child: const Text('Retry')),
            ],
          ),
        );
      }
      final item = snapshot.data;
      if (item == null) return const Center(child: Text('Class not found.'));
      return ListView(
        padding: const EdgeInsets.all(32),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.go('/admin/classes'),
              icon: const Icon(Icons.arrow_back),
              label: const Text('All classes'),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Grade ${item.grade} - ${item.section}',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    'Academic Year ${item.academicYear} • ${item.isArchived ? 'Archived' : 'Active'}',
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _edit(item),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit class'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _archive(item),
                    icon: Icon(
                      item.isArchived
                          ? Icons.unarchive_outlined
                          : Icons.archive_outlined,
                    ),
                    label: Text(item.isArchived ? 'Unarchive' : 'Archive'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.tune_outlined),
              title: const Text('Report options'),
              subtitle: const Text('Manage this class’s report options'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(
                '/admin/report-options/${Uri.encodeComponent(item.id)}',
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Students', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          StreamBuilder<List<StudentModel>>(
            stream: _students.watchClass(item.id),
            builder: (context, students) {
              if (!students.hasData && !students.hasError) {
                return const Center(child: CircularProgressIndicator());
              }
              if (students.hasError) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Unable to load students.'),
                  ),
                );
              }
              final rows = [...?students.data]
                ..sort((a, b) {
                  final first = int.tryParse(a.rollNumber.trim());
                  final second = int.tryParse(b.rollNumber.trim());
                  return first != null && second != null
                      ? first.compareTo(second)
                      : a.rollNumber.toLowerCase().compareTo(
                          b.rollNumber.toLowerCase(),
                        );
                });
              if (rows.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No students in this class.'),
                  ),
                );
              }
              return Card(
                child: Column(
                  children: [
                    for (final student in rows)
                      ListTile(
                        title: Text(student.name),
                        subtitle: Text('Roll ${student.rollNumber}'),
                        trailing: student.isArchived
                            ? const Chip(label: Text('Archived'))
                            : const Icon(Icons.chevron_right),
                        onTap: () => context.go(
                          '/admin/students/${Uri.encodeComponent(student.id)}?classId=${Uri.encodeComponent(item.id)}',
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      );
    },
  );
}

class ClassEditor extends StatefulWidget {
  const ClassEditor({super.key, this.schoolClass});
  final ClassModel? schoolClass;
  @override
  State<ClassEditor> createState() => _ClassEditorState();
}

class _ClassEditorState extends State<ClassEditor> {
  final _key = GlobalKey<FormState>();
  late final _grade = TextEditingController(text: widget.schoolClass?.grade);
  late final _section = TextEditingController(
    text: widget.schoolClass?.section,
  );
  late final _year = TextEditingController(
    text: widget.schoolClass?.academicYear,
  );
  String? _validate(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'This field is required.';
    if (v.length > 30) return 'Use 30 characters or fewer.';
    return null;
  }

  @override
  void dispose() {
    _grade.dispose();
    _section.dispose();
    _year.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.schoolClass == null ? 'Add class' : 'Edit class'),
    content: SizedBox(
      width: 420,
      child: Form(
        key: _key,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _grade,
              maxLength: 30,
              validator: _validate,
              decoration: const InputDecoration(
                labelText: 'Grade',
                border: OutlineInputBorder(),
              ),
            ),
            TextFormField(
              controller: _section,
              maxLength: 30,
              validator: _validate,
              decoration: const InputDecoration(
                labelText: 'Section',
                border: OutlineInputBorder(),
              ),
            ),
            TextFormField(
              controller: _year,
              maxLength: 30,
              validator: _validate,
              decoration: const InputDecoration(
                labelText: 'Academic Year',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_key.currentState!.validate()) {
            Navigator.pop(context, (
              _grade.text.trim(),
              _section.text.trim(),
              _year.text.trim(),
            ));
          }
        },
        child: const Text('Save'),
      ),
    ],
  );
}
