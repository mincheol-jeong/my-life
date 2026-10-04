import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_life/core/database/app_database_provider.dart';
import 'package:my_life/features/record/domain/life_record.dart';
import 'package:my_life/features/record/domain/local_date.dart';
import 'package:my_life/features/timeline/data/timeline_repository.dart';
import 'package:my_life/features/timeline/domain/timeline_entry.dart';

final timelineRepositoryProvider = Provider<TimelineRepository>((ref) {
  return TimelineRepository(ref.watch(appDatabaseProvider));
});

final timelineFilterProvider =
    NotifierProvider<TimelineFilterController, TimelineFilter>(
      TimelineFilterController.new,
    );

class TimelineFilterController extends Notifier<TimelineFilter> {
  @override
  TimelineFilter build() => const TimelineFilter();

  void setType(RecordType? type) {
    state = state.withType(type);
  }

  void setDateRange(LocalDate start, LocalDate end) {
    state = state.withDateRange(start, end);
  }

  void clearDateRange() {
    state = state.withoutDateRange();
  }
}

final timelineEntriesProvider = StreamProvider<List<TimelineEntry>>((ref) {
  final filter = ref.watch(timelineFilterProvider);
  return ref.watch(timelineRepositoryProvider).watchEntries(filter);
});
