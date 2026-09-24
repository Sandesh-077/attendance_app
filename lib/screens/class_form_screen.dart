import 'package:flutter/material.dart';

import '../models/class_model.dart';
import '../repositories/class_repository.dart';

class ClassFormScreen extends StatefulWidget {
  const ClassFormScreen({
    super.key,
    required this.repository,
    this.schoolClass,
  });

  final ClassRepository repository;
  final ClassModel? schoolClass;

  @override
  State<ClassFormScreen> createState() => _ClassFormScreenState();
}

class _ClassFormScreenState extends State<ClassFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _grade = TextEditingController(
    text: widget.schoolClass?.grade,
  );
  late final TextEditingController _section = TextEditingController(
    text: widget.schoolClass?.section,
  );
  late final TextEditingController _academicYear = TextEditingController(
    text: widget.schoolClass?.academicYear,
  );
  bool _saving = false;

  String? _validate(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'This field is required.';
    if (text.length > 30) return 'Use 30 characters or fewer.';
    return null;
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final grade = _grade.text.trim();
      final section = _section.text.trim();
      final academicYear = _academicYear.text.trim();
      final existing = widget.schoolClass;
      if (existing == null) {
        await widget.repository.create(
          grade: grade,
          section: section,
          academicYear: academicYear,
        );
      } else {
        await widget.repository.updateDetails(
          existing.id,
          grade: grade,
          section: section,
          academicYear: academicYear,
        );
      }
      if (!mounted) return;
      Navigator.pop(
        context,
        existing == null
            ? null
            : ClassModel(
                id: existing.id,
                grade: grade,
                section: section,
                academicYear: academicYear,
                isArchived: existing.isArchived,
                createdAt: existing.createdAt,
              ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to save class. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _grade.dispose();
    _section.dispose();
    _academicYear.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.schoolClass != null;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(editing ? 'Edit Class' : 'Add Class'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                editing ? 'Edit Class' : 'Add Class',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _grade,
                decoration: const InputDecoration(
                  labelText: 'Grade',
                  hintText: 'e.g. 10',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                maxLength: 30,
                validator: _validate,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _section,
                decoration: const InputDecoration(
                  labelText: 'Section',
                  hintText: 'e.g. A',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
                maxLength: 30,
                validator: _validate,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _academicYear,
                decoration: const InputDecoration(
                  labelText: 'Academic Year',
                  hintText: 'e.g. 2083',
                  border: OutlineInputBorder(),
                ),
                maxLength: 30,
                validator: _validate,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(editing ? 'Save Changes' : 'Add Class'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
