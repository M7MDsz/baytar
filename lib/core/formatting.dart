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
