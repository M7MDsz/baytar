import 'package:intl/intl.dart';

final _day = DateFormat('EEEE d MMMM', 'ar');
final _dayTime = DateFormat('EEEE d MMMM، h:mm a', 'ar');
final _time = DateFormat('h:mm a', 'ar');
final _date = DateFormat('yyyy/MM/dd');

String formatDay(DateTime d) => _day.format(d.toLocal());
String formatDayTime(DateTime d) => _dayTime.format(d.toLocal());
String formatTime(DateTime d) => _time.format(d.toLocal());
String formatDate(DateTime d) => _date.format(d.toLocal());

bool isSameDay(DateTime a, DateTime b) {
  final x = a.toLocal(), y = b.toLocal();
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

DateTime parseTs(Object? v) => DateTime.parse(v as String).toLocal();

DateTime? parseTsOrNull(Object? v) => v == null ? null : parseTs(v);

/// An email that may wrap after the @ instead of mid-word: on a 360 px phone «admin.demo@example.com» broke as
/// «…example.co» / «m».
String wrappableEmail(String email) => email.replaceFirst('@', '@\u200B');
