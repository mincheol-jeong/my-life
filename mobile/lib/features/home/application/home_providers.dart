import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_life/core/database/app_database_provider.dart';
import 'package:my_life/features/home/data/home_repository.dart';
import 'package:my_life/features/record/domain/local_date.dart';
import 'package:my_life/features/timeline/domain/timeline_entry.dart';

final homeClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final homeTodayProvider = Provider.autoDispose<LocalDate>((ref) {
  final now = ref.watch(homeClockProvider)();
  final midnight = DateTime(now.year, now.month, now.day + 1);
  final timer = Timer(midnight.difference(now), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return LocalDate.fromDateTime(now);
});

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepository(ref.watch(appDatabaseProvider));
});

final homeRecentRecordsProvider =
    StreamProvider.autoDispose<List<TimelineEntry>>(
      (ref) => ref.watch(homeRepositoryProvider).watchRecentRecords(),
    );

final homeRecentPhotosProvider =
    StreamProvider.autoDispose<List<TimelineEntry>>(
      (ref) => ref.watch(homeRepositoryProvider).watchRecentPhotos(),
    );

final homeMonthlyExpenseProvider = StreamProvider.autoDispose<int>((ref) {
  final today = ref.watch(homeTodayProvider);
  return ref.watch(homeRepositoryProvider).watchMonthlyExpense(today);
});
