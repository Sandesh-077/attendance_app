import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/class_model.dart';
import '../models/report_option_model.dart';
import '../repositories/report_option_repository.dart';

class ReportOptionsScreen extends StatefulWidget {
  const ReportOptionsScreen({super.key, required this.schoolClass});
  final ClassModel schoolClass;
  @override
  State<ReportOptionsScreen> createState() => _ReportOptionsScreenState();
}

class _ReportOptionsScreenState extends State<ReportOptionsScreen> {
  final _repository = ReportOptionRepository();
  late final _options = _repository.watchClass(widget.schoolClass.id);
  bool _busy = false;

  Future<void> _edit([ReportOptionModel? option]) async {
    if (_busy || widget.schoolClass.isArchived) return;
    final result = await showDialog<(String, ReportCategory)>(
      context: context,
      builder: (_) => _ReportOptionDialog(option: option),
    );
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    try {
      if (option == null) {
        await _repository.create(
          classId: widget.schoolClass.id,
          title: result.$1,
          category: result.$2,
          actorId: FirebaseAuth.instance.currentUser!.uid,
        );
      } else {
        await _repository.update(
          option.id,
          title: result.$1,
          category: result.$2,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Report option saved.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to save report option. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disable(ReportOptionModel option) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Disable report option?'),
        content: Text(
          '${option.title} will no longer be available for new reports. Existing reports remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Disable'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repository.disable(option.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to disable report option. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: const Text('Report Options'),
    ),
    floatingActionButton: widget.schoolClass.isArchived
        ? null
        : FloatingActionButton.extended(
            onPressed: _busy ? null : () => _edit(),
            icon: const Icon(Icons.add),
            label: const Text('Add Option'),
          ),
    body: StreamBuilder<List<ReportOptionModel>>(
      stream: _options,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(
            child: Text('Unable to load report options. Please try again.'),
          );
        }
        final custom = snapshot.data ?? [];
        final active = custom.where((o) => o.isActive).toList()
          ..sort((a, b) => a.title.compareTo(b.title));
        final disabled = custom.where((o) => !o.isActive).toList();
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Grade ${widget.schoolClass.grade} - ${widget.schoolClass.section}',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Default options',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final option in ReportOptionModel.defaults)
              Card(
                child: ListTile(
                  title: Text(option.title),
                  subtitle: Text(option.category.name),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Class options',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (active.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No custom options yet. Add an option for this class.',
                  ),
                ),
              ),
            for (final option in active)
              Card(
                child: ListTile(
                  title: Text(option.title),
                  subtitle: Text(option.category.name),
                  trailing: widget.schoolClass.isArchived
                      ? null
                      : PopupMenuButton<String>(
                          enabled: !_busy,
                          onSelected: (action) => action == 'edit'
                              ? _edit(option)
                              : _disable(option),
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                              value: 'disable',
                              child: Text('Disable'),
                            ),
                          ],
                        ),
                ),
              ),
            if (disabled.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Disabled', style: Theme.of(context).textTheme.titleMedium),
              for (final option in disabled)
                Card(
                  child: ListTile(
                    title: Text(option.title),
                    subtitle: Text(option.category.name),
                    trailing: const Chip(label: Text('Disabled')),
                  ),
                ),
            ],
          ],
        );
      },
    ),
  );
}

class _ReportOptionDialog extends StatefulWidget {
  const _ReportOptionDialog({this.option});
  final ReportOptionModel? option;

  @override
  State<_ReportOptionDialog> createState() => _ReportOptionDialogState();
}

class _ReportOptionDialogState extends State<_ReportOptionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title = TextEditingController(
    text: widget.option?.title,
  );
  late ReportCategory _category =
      widget.option?.category ?? ReportCategory.equipment;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.option == null ? 'Add Report Option' : 'Edit Report Option',
    ),
    content: SingleChildScrollView(
      child: Form(
        key: _formKey,
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
                for (final value in ReportCategory.values)
                  DropdownMenuItem(value: value, child: Text(value.name)),
              ],
              onChanged: (value) =>
                  setState(() => _category = value ?? _category),
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
          if (_formKey.currentState!.validate()) {
            Navigator.pop(context, (_title.text.trim(), _category));
          }
        },
        child: const Text('Save'),
      ),
    ],
  );
}
