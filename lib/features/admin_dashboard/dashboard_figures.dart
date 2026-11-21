import 'dart:convert';

import 'package:intl/intl.dart';

/// US-39: the period the dashboard counts, [from] inclusive to [to] exclusive.
class DashboardPeriod {
  const DashboardPeriod(this.from, this.to, this.kind);

  final DateTime from;
  final DateTime to;
  final PeriodKind kind;

  /// The last [days] days up to now.
  factory DashboardPeriod.lastDays(int days, {DateTime? now}) {
    final end = now ?? DateTime.now();
    return DashboardPeriod(end.subtract(Duration(days: days)), end, days == 7 ? PeriodKind.week : PeriodKind.month);
  }

  /// Whole days, from the start of [first] to the end of [last].
  factory DashboardPeriod.days(DateTime first, DateTime last) => DashboardPeriod(
        DateTime(first.year, first.month, first.day),
        DateTime(last.year, last.month, last.day).add(const Duration(days: 1)),
        PeriodKind.custom,
      );

  /// «14 نوفمبر – 21 نوفمبر 2026», the last day shown being the last one counted.
  String get label {
    final last = to.subtract(const Duration(microseconds: 1));
    return '${DateFormat('d MMMM', 'ar').format(from)} – ${DateFormat('d MMMM y', 'ar').format(last)}';
  }
}

enum PeriodKind { week, month, custom }

/// What `admin_dashboard` returns: totals only, never names, contact details or case descriptions.
class DashboardFigures {
  const DashboardFigures({
    required this.newOwnerAccounts,
    required this.verifiedVets,
    required this.submittedCases,
    required this.completedConsultations,
    required this.cancelledAppointments,
    required this.averageRating,
    required this.ratingCount,
    required this.pendingVerifications,
    required this.summariesAccepted,
    required this.summariesEdited,
    required this.summariesDisregarded,
    required this.summariesNotGenerated,
    required this.summariesAwaiting,
  });

  final int newOwnerAccounts;
  final int verifiedVets;
  final int submittedCases;
  final int completedConsultations;
  final int cancelledAppointments;
  final double averageRating;
  final int ratingCount;
  final int pendingVerifications;
  final int summariesAccepted;
  final int summariesEdited;
  final int summariesDisregarded;
  final int summariesNotGenerated;
  final int summariesAwaiting;

  factory DashboardFigures.fromMap(Map<String, dynamic> m) {
    int n(String k) => (m[k] as num?)?.toInt() ?? 0;
    return DashboardFigures(
      newOwnerAccounts: n('new_owner_accounts'),
      verifiedVets: n('verified_vets'),
      submittedCases: n('submitted_cases'),
      completedConsultations: n('completed_consultations'),
      cancelledAppointments: n('cancelled_appointments'),
      averageRating: (m['average_rating'] as num?)?.toDouble() ?? 0,
      ratingCount: n('rating_count'),
      pendingVerifications: n('pending_verifications'),
      summariesAccepted: n('summaries_accepted'),
      summariesEdited: n('summaries_edited'),
      summariesDisregarded: n('summaries_disregarded'),
      summariesNotGenerated: n('summaries_not_generated'),
      summariesAwaiting: n('summaries_awaiting'),
    );
  }

  /// The service figures, in display order.
  List<(String, String)> get serviceRows => [
        ('حسابات مالكين جديدة', '$newOwnerAccounts'),
        ('أطباء تم التحقق منهم', '$verifiedVets'),
        ('حالات مرسلة', '$submittedCases'),
        ('استشارات مكتملة', '$completedConsultations'),
        ('مواعيد ملغاة', '$cancelledAppointments'),
        ('متوسط تقييم الاستشارات', averageRating.toStringAsFixed(1)),
        ('عدد التقييمات', '$ratingCount'),
        ('طلبات تحقق معلّقة الآن', '$pendingVerifications'),
      ];

  int get summaryTotal =>
      summariesAccepted + summariesEdited + summariesDisregarded + summariesNotGenerated + summariesAwaiting;

  /// The AI summaries of the period, each in exactly one group, with its share of all of them (whole percent).
  List<(String, int, int)> get summaryRows => [
        ('قُبلت كما هي', summariesAccepted, percentOf(summariesAccepted, summaryTotal)),
        ('عدّلها الطبيب', summariesEdited, percentOf(summariesEdited, summaryTotal)),
        ('تم تجاهلها', summariesDisregarded, percentOf(summariesDisregarded, summaryTotal)),
        ('تعذّر إنشاؤها', summariesNotGenerated, percentOf(summariesNotGenerated, summaryTotal)),
        ('بانتظار المراجعة', summariesAwaiting, percentOf(summariesAwaiting, summaryTotal)),
      ];
}

/// Whole percent of [part] in [total]; 0 when there is nothing to count.
int percentOf(int part, int total) => total == 0 ? 0 : (part * 100 / total).round();

String _cell(String v) => RegExp(r'[",\n]').hasMatch(v) ? '"${v.replaceAll('"', '""')}"' : v;

/// The CSV the administrator downloads: the same figures as the screen, for [period]. UTF-8 with a byte-order mark so
/// spreadsheet programs show the Arabic correctly.
String dashboardCsv(DashboardFigures f, DashboardPeriod period) {
  final rows = <List<String>>[
    ['المؤشر', 'العدد', 'النسبة'],
    ['الفترة', period.label, ''],
    for (final (label, value) in f.serviceRows) [label, value, ''],
    ['ملخصات الذكاء الاصطناعي', '${f.summaryTotal}', f.summaryTotal == 0 ? '0%' : '100%'],
    for (final (label, count, pct) in f.summaryRows) ['ملخصات $label', '$count', '$pct%'],
  ];
  return '\u{FEFF}${rows.map((r) => r.map(_cell).join(',')).join('\r\n')}\r\n';
}

List<int> dashboardCsvBytes(DashboardFigures f, DashboardPeriod period) => utf8.encode(dashboardCsv(f, period));

String dashboardCsvName(DashboardPeriod period) =>
    'baytar-dashboard-${DateFormat('yyyy-MM-dd').format(period.from)}-to-'
    '${DateFormat('yyyy-MM-dd').format(period.to.subtract(const Duration(microseconds: 1)))}.csv';
