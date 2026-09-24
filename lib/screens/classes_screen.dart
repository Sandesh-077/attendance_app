import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/class_model.dart';
import '../repositories/class_repository.dart';
import 'class_detail_screen.dart';
import 'class_form_screen.dart';

class ClassesScreen extends StatefulWidget {
  const ClassesScreen({super.key});

  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> {
  final ClassRepository _repository = ClassRepository();
  late final Stream<List<ClassModel>> _classes = _repository.watchAll();
  final Set<String> _archiving = {};

  String _loadError(Object? error) {
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' =>
          'Your account does not have permission to view classes. Check that your profile role is Admin.',
        'unavailable' =>
          'Firestore is unavailable. Check your connection and try again.',
        _ =>
          'Unable to load classes (Firestore: ${error.code}). Please try again.',
      };
    }
    if (error is TypeError || error is StateError) {
      return 'A class record has missing or invalid data. Please contact the administrator.';
    }
    return 'Unable to load classes. Please try again.';
  }

  Future<void> _addClass() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ClassFormScreen(repository: _repository),
      ),
    );
  }

  Future<void> _openClass(ClassModel schoolClass) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ClassDetailScreen(
          schoolClass: schoolClass,
          repository: _repository,
        ),
      ),
    );
  }

  Future<void> _archive(ClassModel schoolClass) async {
    if (_archiving.contains(schoolClass.id)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive class?'),
        content: Text(
          'Grade ${schoolClass.grade} - ${schoolClass.section} will move to archived classes. Its records will remain available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _archiving.add(schoolClass.id));
    try {
      await _repository.archive(schoolClass.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Class archived.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to archive class. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _archiving.remove(schoolClass.id));
    }
  }

  Future<void> _unarchive(ClassModel schoolClass) async {
    if (_archiving.contains(schoolClass.id)) return;
    setState(() => _archiving.add(schoolClass.id));
    try {
      await _repository.unarchive(schoolClass.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Class moved to active classes.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to unarchive class. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _archiving.remove(schoolClass.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ClassModel>>(
      stream: _classes,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Text(
                _loadError(snapshot.error),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final classes = [...?snapshot.data]
          ..sort((a, b) {
            final byYear = b.academicYear.compareTo(a.academicYear);
            if (byYear != 0) return byYear;
            final byGrade = a.grade.compareTo(b.grade);
            return byGrade != 0 ? byGrade : a.section.compareTo(b.section);
          });
        final active = classes.where((item) => !item.isArchived).toList();
        final archived = classes.where((item) => item.isArchived).toList();

        return ListView(
          padding: const EdgeInsets.all(30),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Classes',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _addClass,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Class'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (classes.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No classes yet. Add a class to get started.'),
                ),
              ),
            if (active.isNotEmpty) ...[
              Text('Active', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final item in active)
                _ClassCard(
                  schoolClass: item,
                  onOpen: () => _openClass(item),
                  onArchive: _archiving.contains(item.id)
                      ? null
                      : () => _archive(item),
                ),
            ],
            if (archived.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Archived', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final item in archived)
                _ClassCard(
                  schoolClass: item,
                  onOpen: () => _openClass(item),
                  onUnarchive: _archiving.contains(item.id)
                      ? null
                      : () => _unarchive(item),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({
    required this.schoolClass,
    required this.onOpen,
    this.onArchive,
    this.onUnarchive,
  });

  final ClassModel schoolClass;
  final VoidCallback onOpen;
  final VoidCallback? onArchive;
  final VoidCallback? onUnarchive;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: const Icon(Icons.class_outlined),
      title: Text('Grade ${schoolClass.grade} - ${schoolClass.section}'),
      subtitle: Text('Academic Year ${schoolClass.academicYear}'),
      onTap: onOpen,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (schoolClass.isArchived) const Chip(label: Text('Archived')),
          PopupMenuButton<String>(
            tooltip: 'Class actions',
            onSelected: (value) {
              if (value == 'archive') onArchive?.call();
              if (value == 'unarchive') onUnarchive?.call();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: schoolClass.isArchived ? 'unarchive' : 'archive',
                enabled: schoolClass.isArchived
                    ? onUnarchive != null
                    : onArchive != null,
                child: Text(schoolClass.isArchived ? 'Unarchive' : 'Archive'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
