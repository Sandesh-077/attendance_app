import 'package:flutter/material.dart';

import '../models/attendance_model.dart';
import '../models/student_report_model.dart';

class StudentMonthCalendar extends StatefulWidget {
  const StudentMonthCalendar({
    super.key,
    required this.attendance,
    required this.reports,
    required this.month,
    required this.onMonthChanged,
  });

  final List<AttendanceModel> attendance;
  final List<StudentReportModel> reports;
  final DateTime month;
  final ValueChanged<DateTime> onMonthChanged;

  @override
  State<StudentMonthCalendar> createState() => _StudentMonthCalendarState();
}

class _StudentMonthCalendarState extends State<StudentMonthCalendar> {
  DateTime? _selected;

  @override
  void didUpdateWidget(covariant StudentMonthCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.month.year != widget.month.year ||
        oldWidget.month.month != widget.month.month) {
      _selected = null;
    }
  }

  String _key(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final days = DateUtils.getDaysInMonth(
      widget.month.year,
      widget.month.month,
    );
    final offset = DateTime(widget.month.year, widget.month.month).weekday - 1;
    final byDate = {
      for (final record in widget.attendance) record.dateKey: record,
    };
    final reportsByDate = <String, List<StudentReportModel>>{};
    for (final report in widget.reports) {
      (reportsByDate[report.attendanceDateKey] ??= []).add(report);
    }
    final monthPrefix = _key(widget.month).substring(0, 7);
    final monthReports = widget.reports
        .where((report) => report.attendanceDateKey.startsWith(monthPrefix))
        .length;
    final selectedKey = _selected == null ? null : _key(_selected!);
    final selectedRecord = byDate[selectedKey];
    final selectedReports =
        reportsByDate[selectedKey] ?? const <StudentReportModel>[];
    final currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attendance calendar',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Count(
                  'Present',
                  widget.attendance
                      .where((r) => r.status == AttendanceStatus.present)
                      .length,
                  Colors.green,
                ),
                _Count(
                  'Late',
                  widget.attendance
                      .where((r) => r.status == AttendanceStatus.late)
                      .length,
                  Colors.orange,
                ),
                _Count(
                  'Absent',
                  widget.attendance
                      .where((r) => r.status == AttendanceStatus.absent)
                      .length,
                  Colors.red,
                ),
                _Count('Reports', monthReports, Colors.redAccent),
              ],
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Previous month',
                        onPressed: () => widget.onMonthChanged(
                          DateTime(widget.month.year, widget.month.month - 1),
                        ),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Text(
                          MaterialLocalizations.of(
                            context,
                          ).formatMonthYear(widget.month),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Next month',
                        onPressed: widget.month.isBefore(currentMonth)
                            ? () => widget.onMonthChanged(
                                DateTime(
                                  widget.month.year,
                                  widget.month.month + 1,
                                ),
                              )
                            : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      for (final day in const [
                        'M',
                        'T',
                        'W',
                        'T',
                        'F',
                        'S',
                        'S',
                      ])
                        Expanded(
                          child: Center(
                            child: Text(
                              day,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                          childAspectRatio: 1.25,
                        ),
                    itemCount: ((offset + days + 6) ~/ 7) * 7,
                    itemBuilder: (context, index) {
                      final day = index - offset + 1;
                      if (day < 1 || day > days) return const SizedBox.shrink();
                      final date = DateTime(
                        widget.month.year,
                        widget.month.month,
                        day,
                      );
                      final key = _key(date);
                      final status = byDate[key]?.status;
                      final reported = reportsByDate.containsKey(key);
                      final color = switch (status) {
                        AttendanceStatus.present => Colors.green.shade100,
                        AttendanceStatus.late => Colors.orange.shade100,
                        AttendanceStatus.absent => Colors.red.shade100,
                        null => Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
                      };
                      return Semantics(
                        label:
                            '$key, ${status?.name ?? 'no attendance'}${reported ? ', reported' : ''}',
                        button: true,
                        child: InkWell(
                          onTap: () => setState(() => _selected = date),
                          child: Container(
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(8),
                              border: selectedKey == key
                                  ? Border.all(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('$day'),
                                if (reported)
                                  const Icon(
                                    Icons.circle,
                                    size: 8,
                                    color: Colors.red,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (selectedKey != null) ...[
              Text(
                '$selectedKey • ${selectedRecord?.status.name ?? 'No attendance recorded'}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (selectedReports.isEmpty)
                const Text('No reports on this date.'),
              for (final report in selectedReports)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.report_outlined, color: Colors.red),
                  title: Text(report.titleSnapshot),
                  subtitle: Text(
                    '${report.severity.name} • ${report.status.name}${report.details.trim().isEmpty ? '' : '\n${report.details}'}',
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.label, this.count, this.color);
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: CircleAvatar(backgroundColor: color, radius: 5),
    label: Text('$label $count'),
  );
}
