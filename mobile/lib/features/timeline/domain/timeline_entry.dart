import 'package:my_life/features/expense/domain/expense_record.dart';
import 'package:my_life/features/photo/domain/photo_record.dart';
import 'package:my_life/features/record/domain/life_record.dart';
import 'package:my_life/features/record/domain/local_date.dart';

class TimelineEntry {
  const TimelineEntry({
    required this.record,
    this.expenseAmount,
    this.expenseCategory,
    this.expenseMemo,
    this.photos = const [],
  });

  final LifeRecord record;
  final int? expenseAmount;
  final ExpenseCategory? expenseCategory;
  final String? expenseMemo;
  final List<StoredPhoto> photos;
}

class TimelineFilter {
  const TimelineFilter({this.type, this.startDate, this.endDate});

  final RecordType? type;
  final LocalDate? startDate;
  final LocalDate? endDate;

  bool get hasDateRange => startDate != null && endDate != null;

  TimelineFilter withType(RecordType? value) {
    return TimelineFilter(type: value, startDate: startDate, endDate: endDate);
  }

  TimelineFilter withDateRange(LocalDate start, LocalDate end) {
    return TimelineFilter(type: type, startDate: start, endDate: end);
  }

  TimelineFilter withoutDateRange() => TimelineFilter(type: type);
}
