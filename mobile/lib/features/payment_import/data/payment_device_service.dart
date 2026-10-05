import 'package:flutter/services.dart';
import 'package:my_life/features/payment_import/domain/payment_message.dart';

class PaymentDeviceState {
  const PaymentDeviceState({
    this.enabled = false,
    this.access = false,
    this.apps = const [],
    this.selected = const [],
  });
  final bool enabled;
  final bool access;
  final List<Map<String, String>> apps;
  final List<String> selected;
}

class PaymentDeviceService {
  static const _channel = MethodChannel('com.mincheol.mylife/payment_import');

  Future<PaymentDeviceState> status() async {
    try {
      final result =
          await _channel.invokeMapMethod<String, dynamic>('status') ?? {};
      return PaymentDeviceState(
        enabled: result['enabled'] == true,
        access: result['access'] == true,
        apps: [
          for (final app in (result['apps'] as List? ?? []))
            Map<String, String>.from(app as Map),
        ],
        selected: List<String>.from(result['selected'] as List? ?? []),
      );
    } on MissingPluginException {
      return const PaymentDeviceState();
    }
  }

  Future<void> configure(bool enabled, List<String> selected) => _channel
      .invokeMethod('configure', {'enabled': enabled, 'selected': selected});
  Future<void> openAccessSettings() =>
      _channel.invokeMethod('openAccessSettings');

  Future<List<PaymentMessage>> pending() async {
    try {
      final list = await _channel.invokeListMethod<dynamic>('pending') ?? [];
      return [
        for (final item in list)
          PaymentMessage(
            source: item['source'] as String,
            externalId: item['id'] as String,
            text: item['text'] as String,
            receivedAt: DateTime.fromMillisecondsSinceEpoch(
              item['receivedAt'] as int,
              isUtc: true,
            ),
          ),
      ];
    } on MissingPluginException {
      return [];
    }
  }

  Future<void> acknowledge(List<String> ids) =>
      _channel.invokeMethod('acknowledge', {'ids': ids});
}
