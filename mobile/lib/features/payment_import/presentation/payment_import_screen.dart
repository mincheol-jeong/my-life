import 'package:my_life/shared/formatting/display_formatters.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_life/core/localization/app_strings.dart';
import 'package:my_life/features/expense/presentation/expense_form_screen.dart';
import 'package:my_life/features/payment_import/application/payment_import_providers.dart';

class PaymentImportScreen extends ConsumerWidget {
  const PaymentImportScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final controller = ref.read(paymentImportControllerProvider.notifier);
    final action = ref.watch(paymentImportControllerProvider);
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    return Scaffold(
      appBar: AppBar(title: Text(strings.get('paymentImport'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(strings.get('paymentImportDescription')),
          if (action.hasError) Text(strings.get('paymentImportError')),
          ref
              .watch(paymentDeviceStateProvider)
              .when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => TextButton(
                  onPressed: () => ref.invalidate(paymentDeviceStateProvider),
                  child: Text(strings.get('retry')),
                ),
                data: (device) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      key: const Key('payment-import-enabled'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(strings.get('paymentImportEnable')),
                      value: device.enabled,
                      onChanged: action.isLoading
                          ? null
                          : (enabled) =>
                                controller.configure(enabled, device.selected),
                    ),
                    if (isAndroid && device.enabled) ...[
                      Text(strings.get('paymentAccessExplanation')),
                      OutlinedButton(
                        onPressed: () async {
                          try {
                            await ref
                                .read(paymentDeviceServiceProvider)
                                .openAccessSettings();
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    strings.get('paymentImportError'),
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        child: Text(strings.get('paymentAccessSettings')),
                      ),
                      if (!device.access)
                        Text(strings.get('paymentAccessMissing')),
                      Text(strings.get('paymentSelectApps')),
                      for (final app in device.apps)
                        CheckboxListTile(
                          title: Text(app['name']!),
                          value: device.selected.contains(app['id']),
                          onChanged: action.isLoading
                              ? null
                              : (selected) {
                                  final sources = {...device.selected};
                                  selected == true
                                      ? sources.add(app['id']!)
                                      : sources.remove(app['id']);
                                  controller.configure(true, sources.toList());
                                },
                        ),
                    ],
                    if (!isAndroid) ...[
                      Text(strings.get('paymentShortcutInstructions')),
                      TextButton.icon(
                        onPressed: () => Clipboard.setData(
                          const ClipboardData(
                            text: 'mylife://payment-import?source=shortcuts&text=',
                          ),
                        ),
                        icon: const Icon(Icons.copy_outlined),
                        label: Text(strings.get('paymentCopyUrl')),
                      ),
                    ],
                  ],
                ),
              ),
          const SizedBox(height: 24),
          Text(
            strings.get('paymentPending'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          TextButton.icon(
            key: const Key('payment-import-refresh'),
            onPressed: action.isLoading ? null : controller.collect,
            icon: const Icon(Icons.refresh),
            label: Text(strings.get('paymentRefresh')),
          ),
          ref
              .watch(paymentPendingProvider)
              .when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => TextButton(
                  onPressed: () => ref.invalidate(paymentPendingProvider),
                  child: Text(strings.get('retry')),
                ),
                data: (rows) => Column(
                  children: [
                    if (rows.isEmpty) Text(strings.get('paymentEmpty')),
                    for (final row in rows)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        key: Key('payment-pending-${row.id}'),
                        title: Text(
                          formatWon(
                            ref.watch(paymentSuggestionProvider(row))?.amount ??
                                0,
                          ),
                        ),
                        subtitle: Text(
                          row.rawText,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () =>
                            context.push('/payment-imports/${row.id}/review'),
                        trailing: IconButton(
                          tooltip: strings.get('paymentDismiss'),
                          icon: const Icon(Icons.close),
                          onPressed: action.isLoading
                              ? null
                              : () => controller.dismiss(row.id),
                        ),
                      ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class PaymentReviewScreen extends ConsumerWidget {
  const PaymentReviewScreen({required this.importId, super.key});
  final String importId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(paymentReviewProvider(importId))
      .when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (_, _) => Scaffold(
          appBar: AppBar(),
          body: Center(child: Text(context.strings.get('paymentImportError'))),
        ),
        data: (row) {
          if (row == null) {
            return Scaffold(
              appBar: AppBar(),
              body: Center(child: Text(context.strings.get('notFound'))),
            );
          }
          final draft = ref.watch(paymentSuggestionProvider(row));
          return ExpenseFormScreen(
            initialDraft: draft,
            paymentImportId: importId,
            importText: row.rawText,
          );
        },
      );
}
