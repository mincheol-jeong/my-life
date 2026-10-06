import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_life/core/database/app_database_provider.dart';
import 'package:my_life/features/home/data/home_repository.dart';
import 'package:my_life/features/record/application/local_date_provider.dart';
import 'package:my_life/features/timeline/domain/timeline_entry.dart';

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
  final today = ref.watch(todayProvider);
  return ref.watch(homeRepositoryProvider).watchMonthlyExpense(today);
});
