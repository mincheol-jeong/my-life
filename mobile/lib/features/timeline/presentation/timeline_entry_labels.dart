import 'package:my_life/core/localization/app_strings.dart';
import 'package:my_life/features/record/domain/life_record.dart';
import 'package:my_life/features/timeline/domain/timeline_entry.dart';

String recordDetailPath(LifeRecord record) => switch (record.type) {
  RecordType.memo => '/records/${record.id}',
  RecordType.expense => '/expenses/${record.id}',
  RecordType.photo => '/photos/${record.id}',
};

String recordEntryLabel(TimelineEntry entry, AppStrings strings) {
  final title = entry.record.title?.trim();
  if (title != null && title.isNotEmpty) return title;
  if (entry.record.type == RecordType.memo) {
    for (final line in entry.record.content?.split('\n') ?? const <String>[]) {
      final normalized = line.trim();
      if (normalized.isNotEmpty) return normalized;
    }
  }
  if (entry.record.type == RecordType.expense) {
    final memo = entry.expenseMemo?.trim();
    if (memo != null && memo.isNotEmpty) return memo;
    final category = entry.expenseCategory;
    if (category != null) return strings.expenseCategory(category);
  }
  if (entry.record.type == RecordType.photo && entry.photos.length > 1) {
    return strings.get('photosCount', values: {'count': entry.photos.length});
  }
  return strings.get(entry.record.type.name);
}

String formatWon(int value) =>
    '₩${value.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}';
