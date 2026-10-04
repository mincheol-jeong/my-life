import 'package:flutter_test/flutter_test.dart';
import 'package:my_life/features/record/domain/local_date.dart';

void main() {
  test('round-trips an ISO local date without a timezone conversion', () {
    final date = LocalDate.parse('2026-09-30');

    expect(date, LocalDate(2026, 9, 30));
    expect(date.toIso8601String(), '2026-09-30');
  });

  test('rejects an invalid calendar date', () {
    expect(() => LocalDate(2026, 2, 30), throwsArgumentError);
    expect(() => LocalDate.parse('2026-02-30'), throwsFormatException);
  });
}
