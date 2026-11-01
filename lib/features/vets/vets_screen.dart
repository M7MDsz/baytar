import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/catalog.dart';
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
        _query = '';
        _search.clear();
        _key = UniqueKey();
      });

  // Name or specialty search over the loaded list; the server filters stay in the sheet (US-09).
  final _search = TextEditingController();
  String _query = '';

  bool _matches(VetSummary v) {
    final q = _query.trim();
    return q.isEmpty || v.fullName.contains(q) || labelList(specialtyLabels, v.specialties).contains(q);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('الأطباء البيطريون'),
          actions: [
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
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SearchBar(
                controller: _search,
                hintText: 'ابحث عن طبيب',
                leading: const Icon(Icons.search_rounded),
                onChanged: (v) => setState(() => _query = v),
                trailing: [
                  if (_query.isNotEmpty)
                    IconButton(
                      tooltip: 'مسح',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() {
                        _search.clear();
                        _query = '';
                      }),
                    ),
                ],
              ),
            ),
          ),
        ),
        body: AsyncView<List<VetSummary>>(
          key: _key,
          load: () => VetsRepository().list(_filters),
          builder: (context, all, _) {
            final vets = all.where(_matches).toList();
            if (vets.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 100),
                _filters.isEmpty && _query.isEmpty
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
              for (final (i, v) in vets.indexed) Entrance(index: i, child: VetCard(v)),
            ]);
          },
        ),
      );
}
