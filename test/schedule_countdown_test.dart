import 'package:baytar/features/slots/schedule_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 11, 9, 10);
  String at(Duration offset) => countdownLabel(start, now: start.add(offset));

  test('inside the vet join window it reads «الآن»', () {
    expect(at(const Duration(minutes: -15)), 'الآن');
    expect(at(Duration.zero), 'الآن');
    expect(at(const Duration(minutes: 15)), 'الآن');
  });

  // QA L-3: between +15 and +30 minutes it used to read «بعد ١ دقيقة».
  test('after the join window it reads «بدأ», never a countdown', () {
    expect(at(const Duration(minutes: 16)), 'بدأ');
    expect(at(const Duration(minutes: 29)), 'بدأ');
  });

  test('minutes before the window use Arabic number agreement', () {
    expect(at(const Duration(minutes: -17)), 'بعد ١٧ دقيقة');
    expect(countdownLabel(start, now: start.subtract(const Duration(minutes: 16))), 'بعد ١٦ دقيقة');
    expect(at(const Duration(hours: -2)), 'بعد ساعتين');
  });
}
