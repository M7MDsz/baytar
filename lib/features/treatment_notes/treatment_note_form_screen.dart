import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/errors.dart';
import '../../core/widgets.dart';
import '../case_summary/summary_card.dart';
import '../case_summary/summary_review.dart';
import '../case_summary/summary_review_repository.dart';
import 'treatment_note.dart';
import 'treatment_notes_repository.dart';

/// US-37 Issue a Treatment Note. The veterinarian writes care instructions and any medicines, each with its name,
/// dose, frequency and duration. The case's AI summary and its status are shown above the note for reference only:
/// nothing is copied from it and nothing is suggested. Once issued the note is final; a correction is a new note.
class TreatmentNoteFormScreen extends StatefulWidget {
  const TreatmentNoteFormScreen({super.key, required this.appointmentId, required this.caseId, this.corrects});

  final String appointmentId;
  final String caseId;

  /// The earlier note this one corrects.
  final String? corrects;

  @override
  State<TreatmentNoteFormScreen> createState() => _TreatmentNoteFormScreenState();
}

class _MedicineFields {
  final name = TextEditingController();
  final dose = TextEditingController();
  final frequency = TextEditingController();
  final duration = TextEditingController();

  List<TextEditingController> get all => [name, dose, frequency, duration];

  Medicine get value => Medicine(name: name.text, dose: dose.text, frequency: frequency.text, duration: duration.text);

  void dispose() {
    for (final c in all) {
      c.dispose();
    }
  }
}

class _TreatmentNoteFormScreenState extends State<TreatmentNoteFormScreen> {
  final _instructions = TextEditingController();
  final _medicines = <_MedicineFields>[];
  late final Future<VetCaseSummary> _summary = SummaryReviewRepository().load(widget.caseId);
  bool _busy = false;
  bool _tried = false;

  void _addMedicine() => setState(() => _medicines.add(_MedicineFields()));

  void _removeMedicine(int i) => setState(() => _medicines.removeAt(i).dispose());

  Future<void> _issue() async {
    final medicines = [for (final m in _medicines) m.value];
    setState(() => _tried = true);
    final problem = noteProblem(_instructions.text, medicines);
    if (problem != null) {
      showSnack(context, problem, error: true);
      return;
    }
    final confirmed = await confirmDialog(
      context,
      title: 'إصدار ملاحظة العلاج؟',
      message: 'تصل الملاحظة إلى المالك باسمك ورقم ترخيصك، ولا يمكن تعديلها بعد إصدارها. أي تصحيح يصدر كملاحظة جديدة.',
      confirmLabel: 'إصدار الملاحظة',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await TreatmentNotesRepository().issue(
        appointmentId: widget.appointmentId,
        instructions: _instructions.text,
        medicines: medicines,
        corrects: widget.corrects,
      );
      if (!mounted) return;
      showSnack(context, 'صدرت ملاحظة العلاج ووصل إشعار للمالك.');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e, treatmentNoteErrors), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _instructions.dispose();
    for (final m in _medicines) {
      m.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.corrects == null ? 'ملاحظة علاج' : 'تصحيح ملاحظة العلاج')),
      body: Column(children: [
        Expanded(
          child: ListView(padding: pagePadding(context), children: [
            if (widget.corrects != null)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: NoticeBanner(
                  'تصدر هذه الملاحظة تصحيحاً للسابقة، وتبقى الاثنتان في سجل الاستشارة.',
                  icon: Icons.history_rounded,
                ),
              ),
            Text('ملخص الحالة، للاطلاع فقط', style: text.titleSmall),
            const SizedBox(height: 2),
            Text('لا يُنسخ منه شيء إلى الملاحظة، ولا يقترح الذكاء الاصطناعي أي دواء.', style: text.bodySmall),
            FutureBuilder<VetCaseSummary>(
              future: _summary,
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: NoticeBanner('تعذّر عرض الملخص الآن. يمكنك إصدار الملاحظة دونه.', tone: Tone.neutral),
                  );
                }
                final s = snap.data;
                if (s == null) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return SummaryCard(content: s.content, status: s.status);
              },
            ),
            SectionCard(
              title: 'تعليمات العناية',
              icon: Icons.checklist_rounded,
              child: TextField(
                controller: _instructions,
                minLines: 3,
                maxLines: 8,
                maxLength: 2000,
                decoration: const InputDecoration(hintText: 'مثل: راحة، ماء نظيف، متى تراجع العيادة'),
              ),
            ),
            SectionCard(
              title: 'الأدوية',
              icon: Icons.medication_outlined,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (_medicines.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('لا توجد أدوية. أضف دواءً إن وصفت واحداً.',
                        style: text.bodyMedium!.copyWith(color: Palette.muted)),
                  ),
                for (var i = 0; i < _medicines.length; i++)
                  _MedicineEditor(
                    key: ObjectKey(_medicines[i]),
                    index: i,
                    fields: _medicines[i],
                    showErrors: _tried,
                    onRemove: () => _removeMedicine(i),
                  ),
                if (_medicines.length < 20)
                  OutlinedButton.icon(
                    onPressed: _addMedicine,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('إضافة دواء'),
                  ),
              ]),
            ),
          ]),
        ),
        BottomActionBar(children: [
          BusyButton(busy: _busy, onPressed: _issue, label: 'إصدار الملاحظة', icon: Icons.send_rounded),
        ]),
      ]),
    );
  }
}

class _MedicineEditor extends StatefulWidget {
  const _MedicineEditor({
    super.key,
    required this.index,
    required this.fields,
    required this.showErrors,
    required this.onRemove,
  });

  final int index;
  final _MedicineFields fields;
  final bool showErrors;
  final VoidCallback onRemove;

  @override
  State<_MedicineEditor> createState() => _MedicineEditorState();
}

class _MedicineEditorState extends State<_MedicineEditor> {
  @override
  Widget build(BuildContext context) {
    final f = widget.fields;
    Widget field(TextEditingController c, String label) => TextField(
          controller: c,
          maxLength: 120,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: requiredLabel(label),
            counterText: '',
            errorText: widget.showErrors && c.text.trim().isEmpty ? 'مطلوب' : null,
          ),
        );
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Palette.canvas,
        borderRadius: BorderRadius.circular(Radii.tile),
        border: Border.all(color: Palette.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('الدواء ${widget.index + 1}', style: Theme.of(context).textTheme.titleSmall)),
          IconButton(tooltip: 'حذف الدواء', onPressed: widget.onRemove, icon: const Icon(Icons.delete_outline_rounded)),
        ]),
        field(f.name, medicineFieldLabels[0]),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: field(f.dose, medicineFieldLabels[1])),
          const SizedBox(width: 8),
          Expanded(child: field(f.frequency, medicineFieldLabels[2])),
        ]),
        const SizedBox(height: 8),
        field(f.duration, medicineFieldLabels[3]),
      ]),
    );
  }
}
