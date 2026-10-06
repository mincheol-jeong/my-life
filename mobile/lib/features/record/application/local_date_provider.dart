import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_life/features/record/domain/local_date.dart';

final localClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final todayProvider = Provider.autoDispose<LocalDate>((ref) {
  final now = ref.watch(localClockProvider)();
  final midnight = DateTime(now.year, now.month, now.day + 1);
  final timer = Timer(midnight.difference(now), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return LocalDate.fromDateTime(now);
});
