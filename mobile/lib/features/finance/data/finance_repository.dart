import 'package:drift/drift.dart';
import 'package:my_life/core/database/app_database.dart';
import 'package:my_life/features/expense/domain/expense_record.dart';
import 'package:my_life/features/finance/domain/finance_summary.dart';
import 'package:my_life/features/record/domain/life_record.dart';
import 'package:my_life/features/record/domain/local_date.dart';

class FinanceRepository {
  FinanceRepository(this._database);

  final AppDatabase _database;

  Stream<FinanceSummary> watchMonth(LocalDate month) {
    final start = LocalDate(month.year, month.month, 1).toIso8601String();
    final next = DateTime.utc(month.year, month.month + 1, 1);
    final end = LocalDate.fromDateTime(next).toIso8601String();
    final date = _database.records.eventDate;
    final category = _database.expenses.category;
    final amount = _database.expenses.amount.sum();
    // One grouped query keeps the total and both breakdowns on one snapshot.
    final query = _database.selectOnly(_database.expenses)
      ..addColumns([date, category, amount])
      ..join([
        innerJoin(
          _database.records,
          _database.records.id.equalsExp(_database.expenses.recordId),
        ),
      ])
      ..where(
        _database.records.deletedAt.isNull() &
            _database.records.type.equals(RecordType.expense.databaseValue) &
            date.isBiggerOrEqualValue(start) &
            (month.year == 9999 && month.month == 12
                ? date.isSmallerOrEqualValue('9999-12-31')
                : date.isSmallerThanValue(end)),
      )
      ..groupBy([date, category]);
    return query.watch().map((rows) {
      final categories = <ExpenseCategory, int>{};
      final days = <LocalDate, int>{};
      var total = 0;
      for (final row in rows) {
        final key = ExpenseCategory.fromDatabase(row.read(category)!);
        final day = LocalDate.parse(row.read(date)!);
        final value = row.read(amount)!;
        categories.update(key, (sum) => sum + value, ifAbsent: () => value);
        days.update(day, (sum) => sum + value, ifAbsent: () => value);
        total += value;
      }
      final categoryTotals =
          categories.entries
              .map((entry) => CategoryExpenseTotal(entry.key, entry.value))
              .toList()
            ..sort((a, b) {
              final byAmount = b.amount.compareTo(a.amount);
              return byAmount != 0
                  ? byAmount
                  : a.category.index.compareTo(b.category.index);
            });
      final dailyTotals =
          days.entries
              .map((entry) => DailyExpenseTotal(entry.key, entry.value))
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));
      return FinanceSummary(
        total: total,
        categories: categoryTotals,
        days: dailyTotals,
      );
    });
  }
}
