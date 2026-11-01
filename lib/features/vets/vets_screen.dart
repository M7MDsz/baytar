import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/widgets.dart';
import '../notifications/notification_bell.dart';
import 'vet_card.dart';
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
          const SizedBox(width: 4),
          const NotificationBell(),
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
            return ListView(padding: pagePadding(context), children: [
              if (vets.every((v) => !v.bookable))
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: NoticeBanner('لا يوجد طبيب بيطري متاح حالياً. ستظهر المواعيد عند نشرها.', icon: Icons.event_busy),
                ),
              for (final v in vets) VetCard(v),
            ]);
          },
        ),
      );
}
