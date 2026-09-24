import 'package:ca_attendance/models/report_option_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
