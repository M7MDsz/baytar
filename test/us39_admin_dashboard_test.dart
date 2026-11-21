import 'dart:convert';

import 'package:baytar/features/admin_dashboard/admin_dashboard_screen.dart';
import 'package:baytar/features/admin_dashboard/dashboard_figures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

// US-39 View the Administration Dashboard.
void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  final figures = DashboardFigures.fromMap({
    'new_owner_accounts': 3,
    'verified_vets': 2,
    'submitted_cases': 14,
    'completed_consultations': 9,
    'cancelled_appointments': 1,
    'average_rating': 4.25,
    'rating_count': 4,
    'pending_verifications': 1,
    'summaries_accepted': 5,
    'summaries_edited': 2,
    'summaries_disregarded': 1,
    'summaries_not_generated': 2,
    'summaries_awaiting': 0,
  });
  final zero = DashboardFigures.fromMap({'average_rating': 0});
  final week = DashboardPeriod(DateTime(2026, 11, 14), DateTime(2026, 11, 21), PeriodKind.week);

  group('the period', () {
    test('the last 7 and 30 days end now', () {
      final now = DateTime(2026, 11, 21, 10);
      final w = DashboardPeriod.lastDays(7, now: now);
      expect(w.from, DateTime(2026, 11, 14, 10));
      expect(w.to, now);
      expect(DashboardPeriod.lastDays(30, now: now).kind, PeriodKind.month);
    });

    test('a custom range counts whole days, the last day included', () {
      final p = DashboardPeriod.days(DateTime(2026, 11, 3, 15), DateTime(2026, 11, 16, 9));
      expect(p.from, DateTime(2026, 11, 3));
      expect(p.to, DateTime(2026, 11, 17));
      expect(p.label, '3 نوفمبر – 16 نوفمبر 2026');
    });
  });

  group('the figures', () {
    test('AI summaries are shown as counts and whole percentages', () {
      expect(figures.summaryTotal, 10);
      expect(figures.summaryRows.map((r) => (r.$2, r.$3)), [(5, 50), (2, 20), (1, 10), (2, 20), (0, 0)]);
    });

    test('a period with no activity shows zeros, never a division by zero', () {
      expect(zero.serviceRows.map((r) => r.$2), ['0', '0', '0', '0', '0', '0.0', '0', '0']);
      expect(zero.summaryRows.every((r) => r.$2 == 0 && r.$3 == 0), isTrue);
    });

    test('the dashboard data has no names, contact details or descriptions', () {
      final labels = [...figures.serviceRows.map((r) => r.$1), ...figures.summaryRows.map((r) => r.$1)].join(' ');
      expect(labels, isNot(contains('@')));
      expect(figures.serviceRows.length, 8);
    });
  });

  group('the CSV', () {
    test('holds the same figures as the screen, with a byte-order mark for Arabic', () {
      final csv = dashboardCsv(figures, week);
      expect(csv, startsWith('\u{FEFF}المؤشر,العدد,النسبة\r\n'));
      expect(csv, contains('حالات مرسلة,14,\r\n'));
      expect(csv, contains('متوسط تقييم الاستشارات,4.3,\r\n'));
      expect(csv, contains('ملخصات قُبلت كما هي,5,50%\r\n'));
      expect(csv, contains('ملخصات عدّلها الطبيب,2,20%\r\n'));
      final bytes = dashboardCsvBytes(figures, week);
      expect(bytes.take(3), [0xEF, 0xBB, 0xBF], reason: 'the file starts with the UTF-8 byte-order mark');
      expect(bytes, utf8.encode(csv));
    });

    test('is named after its period', () {
      expect(dashboardCsvName(week), 'baytar-dashboard-2026-11-14-to-2026-11-20.csv');
    });
  });

  testWidgets('shows the figures and reloads them when the period changes', (tester) async {
    tester.view.physicalSize = const Size(1080, 5000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final asked = <PeriodKind>[];
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: AdminDashboardScreen(load: (p) async {
          asked.add(p.kind);
          return p.kind == PeriodKind.week ? figures : zero;
        }),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('١٤'), findsOneWidget, reason: 'submitted cases');
    expect(find.text('حالات مرسلة'), findsOneWidget);
    expect(find.text('٥ · ٥٠٪'), findsOneWidget, reason: 'accepted summaries, count and percent');
    expect(find.text('تنزيل الأرقام (CSV)'), findsOneWidget);

    await tester.tap(find.text('آخر ٣٠ يوماً'));
    await tester.pumpAndSettle();
    expect(asked, [PeriodKind.week, PeriodKind.month]);
    expect(find.text('لا توجد ملخصات في هذه الفترة.'), findsOneWidget);
    expect(find.text('١٤'), findsNothing);
  });
}
