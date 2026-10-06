import 'package:flutter_test/flutter_test.dart';
import 'package:my_life/features/record/domain/local_date.dart';
import 'package:my_life/shared/formatting/display_formatters.dart';

void main() {
  test('date keeps the local date and pads month/day', () {
    expect(formatRecordDate(LocalDate(2026, 2, 3)), '2026.02.03');
  });
  test('time includes midnight and the end of day', () {
    expect(formatRecordTime(0), '00:00');
    expect(formatRecordTime(1439), '23:59');
  });
  test('KRW amounts have consistent grouping', () {
    expect(formatWon(0), '₩0');
    expect(formatWon(1234567), '₩1,234,567');
  });
}
