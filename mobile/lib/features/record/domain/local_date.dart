class LocalDate implements Comparable<LocalDate> {
  factory LocalDate(int year, int month, int day) {
    final verified = DateTime.utc(year, month, day);
    if (verified.year != year ||
        verified.month != month ||
        verified.day != day) {
      throw ArgumentError.value(
        '$year-$month-$day',
        'date',
        'Invalid local calendar date',
      );
    }
    return LocalDate._(year, month, day);
  }

  const LocalDate._(this.year, this.month, this.day);

  factory LocalDate.fromDateTime(DateTime value) {
    return LocalDate(value.year, value.month, value.day);
  }

  factory LocalDate.parse(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) {
      throw FormatException('Invalid local date format', value);
    }

    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final verified = DateTime.utc(year, month, day);
    if (verified.year != year ||
        verified.month != month ||
        verified.day != day) {
      throw FormatException('Invalid local calendar date', value);
    }

    return LocalDate._(year, month, day);
  }

  final int year;
  final int month;
  final int day;

  String toIso8601String() {
    final paddedMonth = month.toString().padLeft(2, '0');
    final paddedDay = day.toString().padLeft(2, '0');
    return '${year.toString().padLeft(4, '0')}-$paddedMonth-$paddedDay';
  }

  DateTime toDateTime() => DateTime(year, month, day);

  @override
  int compareTo(LocalDate other) {
    return toIso8601String().compareTo(other.toIso8601String());
  }

  @override
  bool operator ==(Object other) {
    return other is LocalDate &&
        other.year == year &&
        other.month == month &&
        other.day == day;
  }

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso8601String();
}
