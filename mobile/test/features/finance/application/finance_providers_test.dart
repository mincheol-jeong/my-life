import 'package:my_life/features/record/application/local_date_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_life/features/finance/application/finance_providers.dart';
import 'package:my_life/features/record/domain/local_date.dart';

void main() {
  test(
    'month selection crosses year boundary and returns to current month',
    () {
      final container = ProviderContainer(
        overrides: [
          localClockProvider.overrideWithValue(() => DateTime(2026, 1, 15)),
        ],
      );
      final listener = container.listen(financeMonthProvider, (_, _) {});
      addTearDown(() {
        listener.close();
        container.dispose();
      });
      final selection = container.read(financeSelectionProvider.notifier);
      expect(container.read(financeMonthProvider), LocalDate(2026, 1, 1));
      selection.move(-1);
      expect(container.read(financeMonthProvider), LocalDate(2025, 12, 1));
      selection.move(2);
      expect(container.read(financeMonthProvider), LocalDate(2026, 2, 1));
      selection.currentMonth();
      expect(container.read(financeMonthProvider), LocalDate(2026, 1, 1));
    },
  );

  testWidgets(
    'default month follows midnight but explicit month stays selected',
    (tester) async {
      var now = DateTime(2026, 12, 31, 23, 59, 59);
      final container = ProviderContainer(
        overrides: [localClockProvider.overrideWithValue(() => now)],
      );
      final listener = container.listen(financeMonthProvider, (_, _) {});
      expect(container.read(financeMonthProvider), LocalDate(2026, 12, 1));
      now = DateTime(2027, 1, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(container.read(financeMonthProvider), LocalDate(2027, 1, 1));
      container.read(financeSelectionProvider.notifier).move(-1);
      now = DateTime(2027, 2, 1);
      container.invalidate(todayProvider);
      expect(container.read(financeMonthProvider), LocalDate(2026, 12, 1));
      container.read(financeSelectionProvider.notifier).currentMonth();
      expect(container.read(financeMonthProvider), LocalDate(2027, 2, 1));
      listener.close();
      container.dispose();
    },
  );

  test('month selection does not exceed supported calendar boundaries', () {
    var now = DateTime(1, 1, 1);
    final container = ProviderContainer(
      overrides: [localClockProvider.overrideWithValue(() => now)],
    );
    final listener = container.listen(financeMonthProvider, (_, _) {});
    final selection = container.read(financeSelectionProvider.notifier);
    selection.move(-1);
    expect(container.read(financeMonthProvider), LocalDate(1, 1, 1));
    now = DateTime(9999, 12, 1);
    container.invalidate(todayProvider);
    selection.move(1);
    expect(container.read(financeMonthProvider), LocalDate(9999, 12, 1));
    listener.close();
    container.dispose();
  });
}
