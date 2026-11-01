import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/formatting.dart';
import '../../core/widgets.dart';
import '../notifications/notification_bell.dart';
import 'case_record.dart';
import 'cases_repository.dart';

/// Owner's cases tab: drafts (US-06) and sent cases.
class CasesScreen extends StatefulWidget {
  const CasesScreen({super.key});

  @override
  State<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends State<CasesScreen> {
  Key _key = UniqueKey();

  Future<void> _open(String path) async {
    await context.push(path);
    setState(() => _key = UniqueKey());
  }

  Widget _list(List<CaseRecord> cases, {required bool drafts}) {
    if (cases.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 80),
        EmptyState(
          icon: drafts ? Icons.edit_note : Icons.outbox_outlined,
          message: drafts ? 'لا توجد مسودات.' : 'لم ترسل أي حالة بعد.',
        ),
      ]);
    }
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 96), children: [
      for (final c in cases)
        ListCard(
          leading: Stack(clipBehavior: Clip.none, children: [
            SpeciesAvatar(c.animalSpecies, radius: 26),
            PositionedDirectional(
              bottom: -4,
              end: -4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: drafts ? Palette.amberSoft : Palette.juniperSoft,
                  shape: BoxShape.circle,
                  border: Border.all(color: Palette.surface, width: 2),
                ),
                child: Icon(
                  drafts ? Icons.edit_note : Icons.assignment_outlined,
                  size: 14,
                  color: drafts ? Palette.amberDeep : Palette.juniper,
                ),
              ),
            ),
          ]),
          title: c.animalName ?? '',
          subtitle: [
            if (c.caseNumber != null) c.caseNumber!,
            formatDayTime(c.submittedAt ?? c.createdAt),
            if ((c.description ?? '').isNotEmpty) c.description!,
          ].join('\n'),
          subtitleMaxLines: 3,
          onTap: () => _open(drafts ? '/cases/${c.id}/edit' : '/cases/${c.id}'),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('حالاتي'),
            actions: const [NotificationBell()],
            bottom: const PillTabBar(tabs: [Tab(text: 'المسودات'), Tab(text: 'المرسلة')]),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _open('/cases/new'),
            icon: const Icon(Icons.add),
            label: const Text('حالة جديدة'),
          ),
          body: AsyncView<(List<CaseRecord>, List<CaseRecord>)>(
            key: _key,
            load: () async {
              final repo = CasesRepository();
              return (await repo.mine(drafts: true), await repo.mine(drafts: false));
            },
            builder: (context, data, _) => TabBarView(children: [
              _list(data.$1, drafts: true),
              _list(data.$2, drafts: false),
            ]),
          ),
        ),
      );
}
