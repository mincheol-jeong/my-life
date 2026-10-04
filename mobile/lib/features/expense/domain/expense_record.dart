import 'package:my_life/features/record/domain/life_record.dart';
import 'package:my_life/features/record/domain/local_date.dart';

enum ExpenseCategory {
  food('FOOD', '식비'),
  transport('TRANSPORT', '교통'),
  shopping('SHOPPING', '쇼핑'),
  entertainment('ENTERTAINMENT', '문화·여가'),
  travel('TRAVEL', '여행'),
  housing('HOUSING', '주거'),
  subscription('SUBSCRIPTION', '구독'),
  other('OTHER', '기타');

  const ExpenseCategory(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static ExpenseCategory fromDatabase(String value) {
    return ExpenseCategory.values.firstWhere(
      (category) => category.databaseValue == value,
      orElse: () => throw FormatException('Unknown expense category', value),
    );
  }
}

enum PaymentMethod {
  cash('CASH', '현금'),
  card('CARD', '카드'),
  transfer('TRANSFER', '계좌이체'),
  other('OTHER', '기타');

  const PaymentMethod(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static PaymentMethod fromDatabase(String value) {
    return PaymentMethod.values.firstWhere(
      (method) => method.databaseValue == value,
      orElse: () => throw FormatException('Unknown payment method', value),
    );
  }
}

class ExpenseRecord {
  const ExpenseRecord({
    required this.id,
    required this.record,
    required this.amount,
    required this.category,
    required this.paymentMethod,
    this.memo,
  });

  final String id;
  final LifeRecord record;
  final int amount;
  final ExpenseCategory category;
  final PaymentMethod paymentMethod;
  final String? memo;

  String get displayLabel {
    return displayLabelFor(category.label);
  }

  String displayLabelFor(String categoryLabel) {
    final title = record.title?.trim();
    if (title != null && title.isNotEmpty) return title;
    final normalizedMemo = memo?.trim();
    if (normalizedMemo != null && normalizedMemo.isNotEmpty) {
      return normalizedMemo;
    }
    return categoryLabel;
  }
}

class ExpenseDraft {
  const ExpenseDraft({
    required this.amount,
    required this.category,
    required this.paymentMethod,
    required this.eventDate,
    this.memo,
    this.title,
    this.eventTimeMinutes,
  });

  final int amount;
  final ExpenseCategory category;
  final PaymentMethod paymentMethod;
  final String? memo;
  final String? title;
  final LocalDate eventDate;
  final int? eventTimeMinutes;
}

class ExpenseValidationException implements Exception {
  const ExpenseValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}
