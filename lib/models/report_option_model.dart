import 'package:cloud_firestore/cloud_firestore.dart';

enum ReportCategory { equipment, dress, discipline, other }

bool requiresReportDetails(ReportCategory category, bool configured) =>
    configured ||
    category == ReportCategory.discipline ||
    category == ReportCategory.other;

class ReportOptionModel {
  const ReportOptionModel({
    required this.id,
    required this.classId,
    required this.title,
    required this.category,
    required this.isActive,
    this.requiresDetails = false,
    this.defaultId,
    this.createdAt,
    this.createdBy,
    this.updatedAt,
  });

  final String id;
  final String? classId;
  final String title;
  final ReportCategory category;
  final bool isActive;
  final bool requiresDetails;
  final String? defaultId;
  final Timestamp? createdAt;
  final String? createdBy;
  final Timestamp? updatedAt;
  bool get isDefault => classId == null;

  static const defaults = [
    ReportOptionModel(
      id: 'default_equipment',
      classId: null,
      title: 'Required equipment/material missing',
      category: ReportCategory.equipment,
      isActive: true,
    ),
    ReportOptionModel(
      id: 'default_dress',
      classId: null,
      title: 'Improper dress/uniform',
      category: ReportCategory.dress,
      isActive: true,
    ),
    ReportOptionModel(
      id: 'default_discipline',
      classId: null,
      title: 'Discipline/decorum issue',
      category: ReportCategory.discipline,
      isActive: true,
      requiresDetails: true,
    ),
    ReportOptionModel(
      id: 'default_other',
      classId: null,
      title: 'Other',
      category: ReportCategory.other,
      isActive: true,
      requiresDetails: true,
    ),
  ];

  factory ReportOptionModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d =
        doc.data() ?? (throw StateError('Missing report option ${doc.id}'));
    return fromData(doc.id, d);
  }

  static ReportOptionModel fromData(String id, Map<String, dynamic> d) {
    return ReportOptionModel(
      id: id,
      classId: d['classId'] as String,
      title: d['title'] as String,
      category: ReportCategory.values.byName(d['category'] as String),
      isActive: d['isActive'] as bool,
      requiresDetails: requiresReportDetails(
        ReportCategory.values.byName(d['category'] as String),
        d['requiresDetails'] as bool? ?? false,
      ),
      defaultId: d['defaultId'] as String?,
      createdAt: d['createdAt'] as Timestamp,
      createdBy: d['createdBy'] as String,
      updatedAt: d['updatedAt'] as Timestamp?,
    );
  }
}
