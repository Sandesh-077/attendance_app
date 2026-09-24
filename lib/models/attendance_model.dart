import 'package:cloud_firestore/cloud_firestore.dart';

enum AttendanceStatus { present, absent, late }

class AttendanceModel {
  const AttendanceModel({
    required this.id,
    required this.studentId,
    required this.classId,
    required this.dateKey,
    required this.status,
    required this.recordedAt,
    required this.recordedBy,
    required this.updatedAt,
    required this.updatedBy,
  });

  final String id;
  final String studentId;
  final String classId;
  final String dateKey;
  final AttendanceStatus status;
  final Timestamp recordedAt;
  final String recordedBy;
  final Timestamp updatedAt;
  final String updatedBy;

  static String documentId(String studentId, String dateKey) =>
      '${studentId}_$dateKey';

  factory AttendanceModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data =
        doc.data() ?? (throw StateError('Missing attendance ${doc.id}'));
    return AttendanceModel(
      id: doc.id,
      studentId: data['studentId'] as String,
      classId: data['classId'] as String,
      dateKey: data['dateKey'] as String,
      status: AttendanceStatus.values.byName(data['status'] as String),
      recordedAt: data['recordedAt'] as Timestamp,
      recordedBy: data['recordedBy'] as String,
      updatedAt: data['updatedAt'] as Timestamp,
      updatedBy: data['updatedBy'] as String,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'studentId': studentId,
    'classId': classId,
    'dateKey': dateKey,
    'status': status.name,
    'recordedAt': recordedAt,
    'recordedBy': recordedBy,
    'updatedAt': updatedAt,
    'updatedBy': updatedBy,
  };
}
