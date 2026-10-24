import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
            return ListView(padding: const EdgeInsets.all(12), children: [
              if (vets.every((v) => !v.bookable))
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('لا يوجد طبيب بيطري متاح حالياً. ستظهر المواعيد عند نشرها.'),
                ),
              for (final v in vets)
                Card(
                  child: ListTile(
                    onTap: () => context.push('/vets/${v.id}'),
                    leading: CircleAvatar(child: Text(v.fullName.characters.first)),
                    title: Text(v.fullName),
                    subtitle: Text(
                      '${labelList(specialtyLabels, v.specialties)}\n'
                      '${v.nextAvailable == null ? 'لا توجد مواعيد متاحة' : 'أقرب موعد: ${formatDayTime(v.nextAvailable!)}'}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_left),
                  ),
                ),
            ]);
          },
        ),
      );
}
