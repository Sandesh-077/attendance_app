import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/class_model.dart';
import '../models/report_option_model.dart';
import '../repositories/class_repository.dart';
import '../repositories/report_option_repository.dart';

class WebReportClassPicker extends StatefulWidget {
  const WebReportClassPicker({super.key});
  @override
  State<WebReportClassPicker> createState() => _WebReportClassPickerState();
}

class _WebReportClassPickerState extends State<WebReportClassPicker> {
  final _repository = ClassRepository();
  late final _stream = _repository.watchAll();
  String _query = '';
  @override
  Widget build(BuildContext context) => StreamBuilder<List<ClassModel>>(
    stream: _stream,
    builder: (context, snapshot) {
      final classes = [...?snapshot.data]
        ..sort((a, b) => a.grade.compareTo(b.grade));
      final shown = classes
          .where(
            (c) => 'grade ${c.grade} ${c.section} ${c.academicYear}'
                .toLowerCase()
                .contains(_query.toLowerCase()),
          )
          .toList();
      return ListView(
        padding: const EdgeInsets.all(32),
        children: [
          Text(
            'Report options',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text('Select a class to configure its report options.'),
          const SizedBox(height: 24),
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
          const SizedBox(height: 20),
          if (!snapshot.hasData && !snapshot.hasError)
            const Center(child: CircularProgressIndicator())
          else if (snapshot.hasError)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Unable to load classes.'),
              ),
            )
          else if (shown.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No classes found.'),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final item in shown)
                    ListTile(
                      title: Text('Grade ${item.grade} - ${item.section}'),
                      subtitle: Text('Academic Year ${item.academicYear}'),
                      trailing: item.isArchived
                          ? const Chip(label: Text('Archived'))
                          : const Icon(Icons.chevron_right),
                      onTap: () => context.go(
                        '/admin/report-options/${Uri.encodeComponent(item.id)}',
                      ),
                    ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

class WebReportOptionsPage extends StatefulWidget {
  const WebReportOptionsPage({super.key, required this.classId});
  final String classId;
  @override
  State<WebReportOptionsPage> createState() => _WebReportOptionsPageState();
}

class _WebReportOptionsPageState extends State<WebReportOptionsPage> {
  final _classes = ClassRepository();
  final _repository = ReportOptionRepository();
  late final Future<ClassModel?> _class = _classes.get(widget.classId);
  late final Stream<List<ReportOptionModel>> _options = _repository.watchClass(
    widget.classId,
  );
  bool _busy = false;

  Future<void> _edit(
    ClassModel schoolClass, [
    ReportOptionModel? option,
  ]) async {
    if (_busy || schoolClass.isArchived) return;
    final result = await showDialog<(String, ReportCategory, bool)>(
      context: context,
      builder: (_) => _OptionEditor(option: option),
    );
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    try {
      if (option?.isDefault == true) {
        await _repository.customizeDefault(
          classId: schoolClass.id,
          defaultOption: option!,
          title: result.$1,
          requiresDetails: result.$3,
          actorId: FirebaseAuth.instance.currentUser!.uid,
        );
      } else if (option == null) {
        await _repository.create(
          classId: schoolClass.id,
          title: result.$1,
          category: result.$2,
          requiresDetails: result.$3,
          actorId: FirebaseAuth.instance.currentUser!.uid,
        );
      } else {
        await _repository.update(
          option.id,
          title: result.$1,
          category: result.$2,
          requiresDetails: result.$3,
        );
      }
      _message('Report option saved.');
    } catch (error) {
      _message(
        error is FirebaseException && error.code == 'permission-denied'
            ? 'Permission denied. Check your admin access and Firestore rules.'
            : 'Unable to save report option. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disable(ReportOptionModel option) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disable report option?'),
        content: Text(
          '${option.title} will no longer be available for new reports. Existing reports remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disable'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repository.disable(option.id);
      _message('Report option disabled.');
    } catch (_) {
      _message('Unable to disable report option. Please try again.');
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
    builder: (context, classSnapshot) {
      if (!classSnapshot.hasData &&
          !classSnapshot.hasError &&
          classSnapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (classSnapshot.hasError) {
        return const Center(child: Text('Unable to load class.'));
      }
      final schoolClass = classSnapshot.data;
      if (schoolClass == null) {
        return const Center(child: Text('Class not found.'));
      }
      return StreamBuilder<List<ReportOptionModel>>(
        stream: _options,
        builder: (context, snapshot) {
          final custom = snapshot.data ?? [];
          final active = custom.where((o) => o.isActive).toList()
            ..sort((a, b) => a.title.compareTo(b.title));
          final overrides = {
            for (final option in active)
              if (option.defaultId != null) option.defaultId!: option,
          };
          final disabled = custom.where((o) => !o.isActive).toList();
          return ListView(
            padding: const EdgeInsets.all(32),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => context.go('/admin/report-options'),
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
                        'Grade ${schoolClass.grade} - ${schoolClass.section}',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      Text(
                        'Academic Year ${schoolClass.academicYear}${schoolClass.isArchived ? ' • Archived' : ''}',
                      ),
                    ],
                  ),
                  if (!schoolClass.isArchived)
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _edit(schoolClass),
                      icon: const Icon(Icons.add),
                      label: const Text('Add option'),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              if (!snapshot.hasData && !snapshot.hasError)
                const Center(child: CircularProgressIndicator())
              else if (snapshot.hasError)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Unable to load report options.'),
                  ),
                )
              else ...[
                Text(
                  'Default options',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      for (final original in ReportOptionModel.defaults)
                        _OptionRow(
                          option: overrides[original.id] ?? original,
                          onEdit: schoolClass.isArchived || _busy
                              ? null
                              : () => _edit(
                                  schoolClass,
                                  overrides[original.id] ?? original,
                                ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Class options',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (active.where((o) => o.defaultId == null).isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No custom options yet.'),
                    ),
                  )
                else
                  Card(
                    child: Column(
                      children: [
                        for (final option in active.where(
                          (o) => o.defaultId == null,
                        ))
                          _OptionRow(
                            option: option,
                            onEdit: schoolClass.isArchived || _busy
                                ? null
                                : () => _edit(schoolClass, option),
                            onDisable: schoolClass.isArchived || _busy
                                ? null
                                : () => _disable(option),
                          ),
                      ],
                    ),
                  ),
                if (disabled.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Disabled',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Card(
                    child: Column(
                      children: [
                        for (final option in disabled)
                          _OptionRow(option: option),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          );
        },
      );
    },
  );
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.option, this.onEdit, this.onDisable});
  final ReportOptionModel option;
  final VoidCallback? onEdit;
  final VoidCallback? onDisable;
  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(option.title),
    subtitle: Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        Text(option.category.name),
        Text('Details ${option.requiresDetails ? 'required' : 'optional'}'),
      ],
    ),
    trailing: !option.isActive
        ? const Chip(label: Text('Disabled'))
        : onDisable == null
        ? (onEdit == null
              ? null
              : IconButton(
                  onPressed: onEdit,
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined),
                ))
        : PopupMenuButton<String>(
            tooltip: 'Option actions',
            onSelected: (action) =>
                action == 'edit' ? onEdit?.call() : onDisable?.call(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'disable', child: Text('Disable')),
            ],
          ),
    onTap: onEdit,
  );
}

class _OptionEditor extends StatefulWidget {
  const _OptionEditor({this.option});
  final ReportOptionModel? option;
  @override
  State<_OptionEditor> createState() => _OptionEditorState();
}

class _OptionEditorState extends State<_OptionEditor> {
  final _key = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.option?.title);
  late ReportCategory _category =
      widget.option?.category ?? ReportCategory.equipment;
  late bool _details = widget.option?.requiresDetails ?? false;
  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.option == null ? 'Add report option' : 'Edit report option',
    ),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Form(
          key: _key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _title,
                autofocus: true,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Enter a title.' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ReportCategory>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final category in ReportCategory.values)
                    DropdownMenuItem(
                      value: category,
                      child: Text(category.name),
                    ),
                ],
                onChanged:
                    widget.option?.isDefault == true ||
                        widget.option?.defaultId != null
                    ? null
                    : (value) => setState(() => _category = value ?? _category),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Require teacher details'),
                value: requiresReportDetails(_category, _details),
                onChanged:
                    _category == ReportCategory.discipline ||
                        _category == ReportCategory.other
                    ? null
                    : (v) => setState(() => _details = v),
              ),
            ],
          ),
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
              _title.text.trim(),
              _category,
              requiresReportDetails(_category, _details),
            ));
          }
        },
        child: const Text('Save'),
      ),
    ],
  );
}
