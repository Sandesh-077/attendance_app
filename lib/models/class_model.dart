import 'package:cloud_firestore/cloud_firestore.dart';

class ClassModel {
  const ClassModel({
    required this.id,
    required this.grade,
    required this.section,
    required this.academicYear,
    required this.isArchived,
    required this.createdAt,
  });

  final String id;
  final String grade;
  final String section;
  final String academicYear;
  final bool isArchived;
  final Timestamp createdAt;

  factory ClassModel.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? (throw StateError('Missing class ${doc.id}'));
    return ClassModel(
      id: doc.id,
      grade: data['grade'] as String,
      section: data['section'] as String,
      academicYear: data['academicYear'] as String,
      isArchived: data['isArchived'] as bool,
      createdAt: data['createdAt'] as Timestamp,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'grade': grade,
    'section': section,
    'academicYear': academicYear,
    'isArchived': isArchived,
    'createdAt': createdAt,
  };
}
