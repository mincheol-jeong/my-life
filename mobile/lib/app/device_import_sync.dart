import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_life/features/calendar_import/application/calendar_sync_controller.dart';
import 'package:my_life/features/payment_import/application/payment_import_providers.dart';
import 'package:my_life/features/record/application/local_date_provider.dart';

class DeviceImportSync extends ConsumerStatefulWidget {
  const DeviceImportSync({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<DeviceImportSync> createState() => _DeviceImportSyncState();
}

class _DeviceImportSyncState extends ConsumerState<DeviceImportSync>
    with WidgetsBindingObserver {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _start();
    });
  }

  void _start() {
    _timer?.cancel();
    unawaited(_refresh(force: true));
    _timer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(_refresh()),
    );
  }

  Future<void> _refresh({bool force = false}) async {
    if (!mounted) return;
    await ref.read(paymentImportControllerProvider.notifier).collect();
    if (!mounted) return;
    await ref
        .read(calendarSyncControllerProvider.notifier)
        .synchronize(force: force);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(todayProvider);
      _start();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
