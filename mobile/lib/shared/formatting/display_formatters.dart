import 'package:my_life/features/record/domain/local_date.dart';

String formatRecordDate(LocalDate date) =>
    date.toIso8601String().replaceAll('-', '.');

String formatRecordTime(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

String formatWon(int value) =>
    '₩${value.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}';
