import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherAssignmentModel {
  const TeacherAssignmentModel({
    required this.id,
    required this.teacherId,
    required this.classId,
    this.subject,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String teacherId;
  final String classId;
  final String? subject;
  final bool isActive;
  final Timestamp createdAt;

  static String documentId(String teacherId, String classId) =>
      '${teacherId}_$classId';

  factory TeacherAssignmentModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data =
        doc.data() ?? (throw StateError('Missing assignment ${doc.id}'));
    return TeacherAssignmentModel(
      id: doc.id,
      teacherId: data['teacherId'] as String,
      classId: data['classId'] as String,
      subject: data['subject'] as String?,
      isActive: data['isActive'] as bool,
      createdAt: data['createdAt'] as Timestamp,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'teacherId': teacherId,
    'classId': classId,
    if (subject != null) 'subject': subject,
    'isActive': isActive,
    'createdAt': createdAt,
  };
}
