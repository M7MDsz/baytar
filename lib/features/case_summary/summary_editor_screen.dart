import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/errors.dart';
import '../../core/widgets.dart';
import 'model/case_summary.dart';
import 'summary_review.dart';
import 'summary_review_repository.dart';

/// One editable line: the veterinarian's text and the owner's words it came from (kept, never edited).
typedef EditableItem = ({String text, String? quote});

/// US-26: the summary the veterinarian saves. A field left blank is removed; an item keeps the owner's quote it had,
/// and an item the veterinarian added has none. Null when nothing is left (a summary needs at least one item).
SummaryContent? editedSummary({
  EditableItem? chiefComplaint,
  EditableItem? duration,
  EditableItem? onset,
  EditableItem? affectedArea,
  List<EditableItem> symptoms = const [],
}) {
  SummaryItem? item(EditableItem? e) {
    final text = e?.text.trim() ?? '';
    return text.isEmpty ? null : SummaryItem(value: text, quote: e!.quote);
  }

  final content = SummaryContent(
    chiefComplaint: item(chiefComplaint),
    duration: item(duration),
    onset: item(onset),
    affectedArea: item(affectedArea),
    symptoms: [for (final s in symptoms) ?item(s)],
  );
  return content.isEmpty ? null : content;
}

/// The longest item the server accepts.
const maxSummaryItem = 300;

/// US-26 Edit an AI-Structured Summary: the veterinarian corrects the summary before deciding on it. The owner's
/// original description is not touched, and the summary stays marked as coming from the AI. [onSave] stores the
/// edit (the summary repository by default); the screen pops with true once it is saved.
class SummaryEditorScreen extends StatefulWidget {
  const SummaryEditorScreen({super.key, required this.caseId, required this.content, this.onSave});

  final String caseId;
  final SummaryContent content;
  final Future<void> Function(SummaryContent content)? onSave;

  @override
  State<SummaryEditorScreen> createState() => _SummaryEditorScreenState();
}

class _Line {
  _Line(SummaryItem? item) : text = TextEditingController(text: item?.value ?? ''), quote = item?.quote;

  final TextEditingController text;
  final String? quote;

  EditableItem get value => (text: text.text, quote: quote);
}

class _SummaryEditorScreenState extends State<SummaryEditorScreen> {
  late final _fields = [
    for (final (label, item) in [
      ('الشكوى الرئيسية', widget.content.chiefComplaint),
      ('المدة', widget.content.duration),
      ('البداية', widget.content.onset),
      ('المنطقة المصابة', widget.content.affectedArea),
    ])
      (label, _Line(item)),
  ];
  late final List<_Line> _symptoms = [for (final s in widget.content.symptoms) _Line(s)];
  bool _busy = false;

  void _addSymptom() => setState(() => _symptoms.add(_Line(null)));

  void _removeSymptom(int i) => setState(() => _symptoms.removeAt(i).text.dispose());

  Future<void> _save() async {
    final content = editedSummary(
      chiefComplaint: _fields[0].$2.value,
      duration: _fields[1].$2.value,
      onset: _fields[2].$2.value,
      affectedArea: _fields[3].$2.value,
      symptoms: [for (final s in _symptoms) s.value],
    );
    if (content == null) {
      showSnack(context, 'أبقِ عنصراً واحداً على الأقل في الملخص.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final save = widget.onSave ?? (c) => SummaryReviewRepository().edit(widget.caseId, c);
      await save(content);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e, summaryReviewErrors), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    for (final (_, line) in _fields) {
      line.text.dispose();
    }
    for (final s in _symptoms) {
      s.text.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('تعديل الملخص')),
      body: Column(children: [
        Expanded(
          child: ListView(padding: pagePadding(context), children: [
            const NoticeBanner(
              'صحّح ما يلزم فقط. يبقى وصف المالك الأصلي كما هو، ويبقى الملخص معلَّماً بأنه من الذكاء الاصطناعي وأنك عدّلته.',
              icon: Icons.info_outline_rounded,
            ),
            const SizedBox(height: 4),
            Wrap(spacing: 6, children: const [StatusPill('ليس تشخيصاً', icon: Icons.info_outline_rounded)]),
            SectionCard(
              title: 'الحقول',
              icon: Icons.notes_rounded,
              child: Column(children: [
                for (final (label, line) in _fields) ...[
                  _ItemField(label: label, line: line),
                  const SizedBox(height: 12),
                ],
              ]),
            ),
            SectionCard(
              title: 'الأعراض',
              icon: Icons.format_list_bulleted_rounded,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (_symptoms.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('لا توجد أعراض في الملخص.', style: text.bodyMedium!.copyWith(color: Palette.muted)),
                  ),
                for (var i = 0; i < _symptoms.length; i++) ...[
                  _ItemField(
                    key: ObjectKey(_symptoms[i]),
                    label: 'عرض ${i + 1}',
                    line: _symptoms[i],
                    onRemove: () => _removeSymptom(i),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_symptoms.length < 15)
                  OutlinedButton.icon(
                    onPressed: _addSymptom,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('إضافة عرض'),
                  ),
              ]),
            ),
          ]),
        ),
        BottomActionBar(children: [
          BusyButton(busy: _busy, onPressed: _save, label: 'حفظ التعديل', icon: Icons.check_rounded),
        ]),
      ]),
    );
  }
}

class _ItemField extends StatelessWidget {
  const _ItemField({super.key, required this.label, required this.line, this.onRemove});

  final String label;
  final _Line line;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        controller: line.text,
        maxLength: maxSummaryItem,
        minLines: 1,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: label,
          counterText: '',
          suffixIcon: onRemove == null
              ? null
              : IconButton(tooltip: 'حذف العرض', icon: const Icon(Icons.delete_outline_rounded), onPressed: onRemove),
        ),
      ),
      Padding(
        padding: const EdgeInsetsDirectional.only(start: 4, top: 4),
        child: Text(
          line.quote == null ? 'أضافه الطبيب، دون اقتباس من المالك' : 'من كلام المالك: «${line.quote}»',
          style: text.bodySmall,
        ),
      ),
    ]);
  }
}

/// Opens the editor for [content]. True when an edit was saved.
Future<bool> editSummary(BuildContext context, {required String caseId, required SummaryContent content}) async =>
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SummaryEditorScreen(caseId: caseId, content: content)),
    ) ??
    false;
