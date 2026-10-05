import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_life/app/app.dart';
import 'package:my_life/core/database/app_database.dart';
import 'package:my_life/core/database/app_database_provider.dart';
import 'package:my_life/features/payment_import/application/payment_import_providers.dart';
import 'package:my_life/features/payment_import/data/payment_device_service.dart';
import 'package:my_life/features/payment_import/domain/payment_message.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'import entry never grants access implicitly; enable, review then save',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final device = _FakePayments();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            paymentDeviceServiceProvider.overrideWithValue(device),
          ],
          child: const MyLifeApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('나'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('payment-import-entry')));
      await tester.tap(find.byKey(const Key('payment-import-entry')));
      await tester.pumpAndSettle();
      expect(device.enabled, isFalse);
      expect(device.accessRequests, 0);
      await tester.tap(find.byKey(const Key('payment-import-enabled')));
      await tester.pumpAndSettle();
      expect(device.enabled, isTrue);
      await tester.ensureVisible(
        find.byKey(const Key('payment-import-refresh')),
      );
      await tester.tap(find.byKey(const Key('payment-import-refresh')));
      await tester.pumpAndSettle();
      expect(await database.select(database.expenses).get(), isEmpty);
      final row = (await database.select(database.paymentImports).get()).single;
      await tester.ensureVisible(find.byKey(Key('payment-pending-${row.id}')));
      await tester.tap(find.byKey(Key('payment-pending-${row.id}')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('expense-amount-field')))
            .controller!
            .text,
        '12345',
      );
      await tester.ensureVisible(find.byKey(const Key('expense-memo-field')));
      await tester.enterText(
        find.byKey(const Key('expense-memo-field')),
        'Confirmed purchase',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('save-expense-button')));
      await tester.tap(find.byKey(const Key('save-expense-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('expense-detail-title')), findsOneWidget);
      expect(
        (await database.select(database.expenses).get()).single.amount,
        12345,
      );
      expect(
        (await database.select(database.paymentImports).get()).single.rawText,
        '',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  test(
    'a failed native acknowledgment retries without creating a duplicate',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final device = _FakePayments()
        ..enabled = true
        ..failAck = true;
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          paymentDeviceServiceProvider.overrideWithValue(device),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(
        paymentImportControllerProvider.notifier,
      );
      await controller.collect();
      expect(container.read(paymentImportControllerProvider).hasError, isTrue);
      device.failAck = false;
      await controller.collect();
      expect(
        await database.select(database.paymentImports).get(),
        hasLength(1),
      );
      expect(await database.select(database.records).get(), isEmpty);
    },
  );
}

class _FakePayments extends PaymentDeviceService {
  bool enabled = false;
  bool failAck = false;
  bool acknowledged = false;
  int accessRequests = 0;
  @override
  Future<PaymentDeviceState> status() async =>
      PaymentDeviceState(enabled: enabled, access: true);
  @override
  Future<void> configure(bool value, List<String> selected) async {
    enabled = value;
  }

  @override
  Future<void> openAccessSettings() async {
    accessRequests++;
  }

  @override
  Future<List<PaymentMessage>> pending() async => !enabled || acknowledged
      ? []
      : [
          PaymentMessage(
            source: 'synthetic-card',
            externalId: 'one',
            text: '카드 승인 12,345원\n10/05 12:34',
            receivedAt: DateTime(2026, 10, 5, 12, 34),
          ),
        ];
  @override
  Future<void> acknowledge(List<String> ids) async {
    if (failAck) throw StateError('Native handoff temporarily unavailable');
    acknowledged = true;
  }
}
