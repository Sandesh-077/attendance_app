import 'package:flutter/material.dart';

import '../models/class_model.dart';
import '../models/student_model.dart';
import '../repositories/class_repository.dart';
import '../repositories/student_repository.dart';

class StudentFormScreen extends StatefulWidget {
  const StudentFormScreen({
    super.key,
    required this.repository,
    required this.classRepository,
    this.student,
    this.fixedClassId,
  });

  final StudentRepository repository;
  final ClassRepository classRepository;
  final StudentModel? student;
  final String? fixedClassId;

  @override
  State<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends State<StudentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.student?.name);
  late final _roll = TextEditingController(text: widget.student?.rollNumber);
  late final _classes = widget.classRepository.watchAll();
  late String? _classId = widget.fixedClassId ?? widget.student?.classId;
  bool _saving = false;
  bool _addedStudent = false;

  String? _validate(String? value, int max) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'This field is required.';
    if (text.length > max) return 'Use $max characters or fewer.';
    return null;
  }

  Future<void> _save(List<ClassModel> activeClasses) async {
    if (_saving || !_formKey.currentState!.validate()) return;
    if (_classId == null || !activeClasses.any((item) => item.id == _classId)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select an active class.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final student = widget.student;
      if (student == null) {
        await widget.repository.create(
          name: _name.text.trim(),
          rollNumber: _roll.text.trim(),
          classId: _classId!,
        );
      } else {
        await widget.repository.update(
          student.id,
          name: _name.text.trim(),
          rollNumber: _roll.text.trim(),
          classId: _classId!,
        );
      }
      if (!mounted) return;
      if (student != null) {
        Navigator.pop(context, true);
      } else {
        _name.clear();
        _roll.clear();
        setState(() => _addedStudent = true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to save student. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _roll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: Text(widget.student == null ? 'Add Student' : 'Edit Student'),
    ),
    body: StreamBuilder<List<ClassModel>>(
      stream: _classes,
      builder: (context, snapshot) {
        if (!snapshot.hasData && !snapshot.hasError) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(
            child: Text('Unable to load classes. Please try again.'),
          );
        }
        final active =
            [...?snapshot.data].where((item) => !item.isArchived).toList()
              ..sort(
                (a, b) => '${a.grade} ${a.section}'.compareTo(
                  '${b.grade} ${b.section}',
                ),
              );
        return ListView(
          padding: const EdgeInsets.all(30),
          children: [
            Text(
              widget.student == null ? 'Add Student' : 'Edit Student',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Student Name',
                      border: OutlineInputBorder(),
                    ),
                    maxLength: 200,
                    textCapitalization: TextCapitalization.words,
                    validator: (value) => _validate(value, 200),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _roll,
                    decoration: const InputDecoration(
                      labelText: 'Roll Number',
                      border: OutlineInputBorder(),
                    ),
                    maxLength: 40,
                    validator: (value) => _validate(value, 40),
                  ),
                  const SizedBox(height: 12),
                  if (widget.fixedClassId == null)
                    DropdownButtonFormField<String>(
                      initialValue: active.any((item) => item.id == _classId)
                          ? _classId
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Class',
                        border: OutlineInputBorder(),
                      ),
                      hint: const Text('Select a class'),
                      items: [
                        for (final item in active)
                          DropdownMenuItem(
                            value: item.id,
                            child: Text(
                              'Grade ${item.grade} - ${item.section} (${item.academicYear})',
                            ),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _classId = value),
                      validator: (value) =>
                          value == null ? 'Select an active class.' : null,
                    ),
                  if (widget.fixedClassId != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        active.any((item) => item.id == widget.fixedClassId)
                            ? 'Class: ${active.firstWhere((item) => item.id == widget.fixedClassId).grade} - ${active.firstWhere((item) => item.id == widget.fixedClassId).section}'
                            : 'Selected class is not active.',
                      ),
                    ),
                ],
              ),
            ),
            if (active.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('Add an active class before adding students.'),
              ),
            const SizedBox(height: 24),
            if (_addedStudent)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Student added. Enter another student or tap Done.',
                ),
              ),
            FilledButton(
              onPressed: _saving || active.isEmpty ? null : () => _save(active),
              child: Text(_saving ? 'Saving…' : 'Save Student'),
            ),
            if (_addedStudent)
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context, true),
                child: const Text('Done'),
              ),
          ],
        );
      },
    ),
  );
}
