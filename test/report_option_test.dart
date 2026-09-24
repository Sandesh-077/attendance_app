import 'package:ca_attendance/models/report_option_model.dart';
import 'package:ca_attendance/repositories/report_option_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('old Other options require details even without the new field', () {
    final option = ReportOptionModel.fromData('old', {
      'classId': 'class',
      'title': 'Old option',
      'category': 'other',
      'isActive': true,
      'createdAt': Timestamp.fromDate(DateTime(2025)),
      'createdBy': 'admin',
      'updatedAt': null,
    });
    expect(option.requiresDetails, isTrue);
  });

  test('explicit details setting is read in both states', () {
    for (final required in [true, false]) {
      final option = ReportOptionModel.fromData('option', {
        'classId': 'class',
        'title': 'Option',
        'category': 'other',
        'isActive': true,
        'requiresDetails': required,
        'createdAt': Timestamp.fromDate(DateTime(2025)),
        'createdBy': 'admin',
        'updatedAt': null,
      });
      expect(option.requiresDetails, isTrue);
    }
  });
  test('built-in report options have stable IDs and controlled categories', () {
    expect(ReportOptionModel.defaults.map((o) => o.id), [
      'default_equipment',
      'default_dress',
      'default_discipline',
      'default_other',
    ]);
    expect(
      ReportOptionModel.defaults.map((o) => o.category),
      ReportCategory.values,
    );
    expect(
      ReportOptionModel.defaults.every((o) => o.isDefault && o.isActive),
      isTrue,
    );
  });

  test('discipline and other always require details', () {
    expect(requiresReportDetails(ReportCategory.discipline, false), isTrue);
    expect(requiresReportDetails(ReportCategory.other, false), isTrue);
    expect(requiresReportDetails(ReportCategory.equipment, false), isFalse);
  });

  test('class override replaces its default without duplicating it', () {
    final override = ReportOptionModel(
      id: 'custom',
      classId: 'class',
      defaultId: 'default_other',
      title: 'Other concern',
      category: ReportCategory.other,
      isActive: true,
      requiresDetails: true,
    );
    final options = effectiveReportOptions([override]);
    expect(options.length, 4);
    expect(
      options.where((o) => o.category == ReportCategory.other).single.id,
      'custom',
    );
  });
}
