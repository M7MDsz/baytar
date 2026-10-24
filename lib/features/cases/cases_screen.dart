import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatting.dart';
import '../../core/widgets.dart';
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
        const SizedBox(height: 100),
        EmptyState(
          icon: drafts ? Icons.edit_note : Icons.outbox_outlined,
          message: drafts ? 'لا توجد مسودات.' : 'لم ترسل أي حالة بعد.',
        ),
      ]);
    }
    return ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 96), children: [
      for (final c in cases)
        Card(
          child: ListTile(
            leading: Icon(drafts ? Icons.edit_note : Icons.assignment_outlined),
            title: Text(c.animalName ?? ''),
            subtitle: Text(
              [
                if (c.caseNumber != null) c.caseNumber!,
                formatDayTime(c.submittedAt ?? c.createdAt),
                if ((c.description ?? '').isNotEmpty) c.description!,
              ].join('\n'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            isThreeLine: true,
            onTap: () => _open(drafts ? '/cases/${c.id}/edit' : '/cases/${c.id}'),
          ),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('حالاتي'),
            bottom: const TabBar(tabs: [Tab(text: 'المسودات'), Tab(text: 'المرسلة')]),
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
