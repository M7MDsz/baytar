import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/catalog.dart';
import '../../core/formatting.dart';
import '../../core/widgets.dart';
import 'vet_filters_sheet.dart';
import 'vet_summary.dart';
import 'vets_repository.dart';

/// US-08 (browse) and US-09 (filter).
class VetsScreen extends StatefulWidget {
  const VetsScreen({super.key});

  @override
  State<VetsScreen> createState() => _VetsScreenState();
}

class _VetsScreenState extends State<VetsScreen> {
  VetFilters _filters = const VetFilters();
  Key _key = UniqueKey();

  Future<void> _openFilters() async {
    final f = await showModalBottomSheet<VetFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => VetFiltersSheet(initial: _filters),
    );
    if (f != null) {
      setState(() {
        _filters = f;
        _key = UniqueKey();
      });
    }
  }

  void _clear() => setState(() {
        _filters = const VetFilters();
        _key = UniqueKey();
      });

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('الأطباء البيطريون'), actions: [
          IconButton(
            tooltip: 'تصفية',
            onPressed: _openFilters,
            style: IconButton.styleFrom(
              backgroundColor: _filters.isEmpty ? Palette.surface : Palette.juniper,
              foregroundColor: _filters.isEmpty ? Palette.juniper : Colors.white,
              side: BorderSide(color: _filters.isEmpty ? Palette.lineStrong : Palette.juniper),
            ),
            icon: Badge(isLabelVisible: !_filters.isEmpty, child: const Icon(Icons.tune)),
          ),
        ]),
        body: AsyncView<List<VetSummary>>(
          key: _key,
          load: () => VetsRepository().list(_filters),
          builder: (context, vets, _) {
            if (vets.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 100),
                _filters.isEmpty
                    ? const EmptyState(icon: Icons.medical_services_outlined, message: 'لا يوجد طبيب بيطري متاح حالياً.')
                    : EmptyState(
                        icon: Icons.filter_alt_off_outlined,
                        message: 'لا يوجد طبيب يطابق كل الشروط المختارة.\nجرّب إزالة بعض الشروط أو توسيعها.',
                        action: OutlinedButton(onPressed: _clear, child: const Text('مسح الشروط')),
                      ),
              ]);
            }
            return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
              if (vets.every((v) => !v.bookable))
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: NoticeBanner('لا يوجد طبيب بيطري متاح حالياً. ستظهر المواعيد عند نشرها.', icon: Icons.event_busy),
                ),
              for (final v in vets) _VetCard(v),
            ]);
          },
        ),
      );
}

/// Avatar-led card: name, specialty chips and the nearest free time.
class _VetCard extends StatelessWidget {
  const _VetCard(this.v);

  final VetSummary v;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      onTap: () => context.push('/vets/${v.id}'),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 12, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          NameAvatar(v.fullName, radius: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v.fullName, style: text.titleMedium!.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final s in v.specialties) TagChip(label(specialtyLabels, s)),
              ]),
            ]),
          ),
          const Icon(Icons.chevron_right, color: Palette.muted),
        ]),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: v.bookable ? Palette.successSoft : Palette.surfaceMuted,
            borderRadius: BorderRadius.circular(Radii.tile),
          ),
          child: Row(children: [
            Icon(v.bookable ? Icons.event_available : Icons.event_busy, size: 18, color: v.bookable ? Palette.success : Palette.muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                v.nextAvailable == null ? 'لا توجد مواعيد متاحة' : 'أقرب موعد: ${formatDayTime(v.nextAvailable!)}',
                style: text.labelMedium!.copyWith(
                  color: v.bookable ? Palette.success : Palette.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
