import 'package:my_life/features/expense/domain/expense_record.dart';
import 'package:my_life/features/record/domain/local_date.dart';

class CategoryExpenseTotal {
  const CategoryExpenseTotal(this.category, this.amount);

  final ExpenseCategory category;
  final int amount;
}

class DailyExpenseTotal {
  const DailyExpenseTotal(this.date, this.amount);

  final LocalDate date;
  final int amount;
}

class FinanceSummary {
  FinanceSummary({
    required this.total,
    required List<CategoryExpenseTotal> categories,
    required List<DailyExpenseTotal> days,
  }) : categories = List.unmodifiable(categories),
       days = List.unmodifiable(days);

  final int total;
  final List<CategoryExpenseTotal> categories;
  final List<DailyExpenseTotal> days;
}
