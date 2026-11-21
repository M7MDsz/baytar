import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/errors.dart';
import '../../core/widgets.dart';
import 'dashboard_figures.dart';
import 'dashboard_repository.dart';

/// US-39 View the Administration Dashboard: key figures for the last 7 days, the last 30 days or a chosen range,
/// the AI summaries as counts and percentages, and a CSV of the same figures. Totals only.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key, this.load});

  /// For tests; the dashboard repository by default.
  final Future<DashboardFigures> Function(DashboardPeriod period)? load;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  DashboardPeriod _period = DashboardPeriod.lastDays(7);
  late Future<DashboardFigures> _figures = _fetch();

  Future<DashboardFigures> _fetch() => (widget.load ?? DashboardRepository().load)(_period);

  void _choose(DashboardPeriod period) => setState(() {
        _period = period;
        _figures = _fetch();
      });

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2026, 1, 1),
      lastDate: now,
      initialDateRange: DateTimeRange(start: now.subtract(const Duration(days: 13)), end: now),
      helpText: 'اختر الفترة',
      saveText: 'عرض',
    );
    if (range != null) _choose(DashboardPeriod.days(range.start, range.end));
  }

  Future<void> _export(DashboardFigures f) async {
    try {
      final saved = await FilePicker.saveFile(
        fileName: dashboardCsvName(_period),
        bytes: Uint8List.fromList(dashboardCsvBytes(f, _period)),
        mimeType: 'text/csv',
      );
      if (mounted && saved != null) showSnack(context, 'تم حفظ ملف CSV بالأرقام نفسها.');
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('لوحة المتابعة')),
        body: FutureBuilder<DashboardFigures>(
          future: _figures,
          builder: (context, snap) {
            final f = snap.data;
            return ListView(padding: pagePadding(context), children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                ChoiceChip(
                  label: const Text('آخر ٧ أيام'),
                  selected: _period.kind == PeriodKind.week,
                  onSelected: (_) => _choose(DashboardPeriod.lastDays(7)),
                ),
                ChoiceChip(
                  label: const Text('آخر ٣٠ يوماً'),
                  selected: _period.kind == PeriodKind.month,
                  onSelected: (_) => _choose(DashboardPeriod.lastDays(30)),
                ),
                ChoiceChip(
                  avatar: const Icon(Icons.date_range_rounded, size: 18),
                  label: const Text('فترة محددة'),
                  selected: _period.kind == PeriodKind.custom,
                  onSelected: (_) => _pickRange(),
                ),
              ]),
              const SizedBox(height: 8),
              Text(_period.label, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Palette.muted)),
              if (snap.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: EmptyState(
                    icon: Icons.cloud_off_rounded,
                    message: friendlyError(snap.error!, dashboardErrors),
                    action: OutlinedButton(onPressed: () => _choose(_period), child: const Text('إعادة المحاولة')),
                  ),
                )
              else if (f == null || snap.connectionState != ConnectionState.done)
                const Padding(padding: EdgeInsets.only(top: 48), child: Center(child: CircularProgressIndicator()))
              else
                ..._figuresView(context, f),
            ]);
          },
        ),
      );

  List<Widget> _figuresView(BuildContext context, DashboardFigures f) {
    final text = Theme.of(context).textTheme;
    return [
      const SectionTitle('الخدمة'),
      LayoutBuilder(
        builder: (context, c) {
          final columns = c.maxWidth >= 560 ? 4 : 2;
          final width = (c.maxWidth - 10 * (columns - 1)) / columns;
          return Wrap(spacing: 10, runSpacing: 10, children: [
            for (final (label, value) in f.serviceRows) SizedBox(width: width, child: _Figure(label: label, value: value)),
          ]);
        },
      ),
      const SectionTitle('ملخصات الذكاء الاصطناعي'),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(
            f.summaryTotal == 0 ? 'لا توجد ملخصات في هذه الفترة.' : 'من ${arabicDigits(f.summaryTotal)} ملخصاً لحالات هذه الفترة',
            style: text.bodySmall,
          ),
          for (final (label, count, pct) in f.summaryRows) _Share(label: label, count: count, percent: pct),
        ]),
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: () => _export(f),
        icon: const Icon(Icons.download_rounded),
        label: const Text('تنزيل الأرقام (CSV)'),
      ),
      const SizedBox(height: 8),
      Text('أرقام إجمالية فقط، دون أسماء أو بيانات تواصل أو أوصاف حالات.',
          textAlign: TextAlign.center, style: text.bodySmall),
    ];
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(arabicDigits(value), style: text.headlineSmall!.copyWith(color: Palette.ink, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: text.bodySmall, maxLines: 2),
      ]),
    );
  }
}

class _Share extends StatelessWidget {
  const _Share({required this.label, required this.count, required this.percent});

  final String label;
  final int count;
  final int percent;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(label, style: text.bodyMedium)),
          Text('${arabicDigits(count)} · ${arabicDigits(percent)}٪', style: text.titleSmall),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: percent / 100,
            minHeight: 8,
            backgroundColor: Palette.surfaceMuted,
            color: Palette.accent,
          ),
        ),
      ]),
    );
  }
}
