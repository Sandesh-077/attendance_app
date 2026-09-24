import 'package:cloud_firestore/cloud_firestore.dart';

class StudentModel {
  const StudentModel({
    required this.id,
    required this.name,
    required this.rollNumber,
    required this.classId,
    required this.isArchived,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String rollNumber;
  final String classId;
  final bool isArchived;
  final Timestamp createdAt;

  factory StudentModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? (throw StateError('Missing student ${doc.id}'));
    return StudentModel(
      id: doc.id,
      name: data['name'] as String,
      rollNumber: data['rollNumber'] as String,
      classId: data['classId'] as String,
      isArchived: data['isArchived'] as bool,
      createdAt: data['createdAt'] as Timestamp,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'rollNumber': rollNumber,
    'classId': classId,
    'isArchived': isArchived,
    'createdAt': createdAt,
  };
}
