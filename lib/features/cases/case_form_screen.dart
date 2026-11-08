import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/errors.dart';
import '../../core/navigation.dart';
import '../../core/supabase.dart';
import '../../core/widgets.dart';
import '../animals/animal.dart';
import '../animals/animals_repository.dart';
import '../voice/transcript_field.dart';
import '../voice/voice_note.dart';
import '../voice/voice_recorder_field.dart';
import 'animal_picker.dart';
import 'case_record.dart';
import 'case_validation.dart';
import 'cases_repository.dart';
import 'media_attachments_field.dart';

/// US-03 (written description), US-04 (voice, from the voice feature), US-05 (media), US-06 (draft)
/// and US-07 (submit).
class CaseFormScreen extends StatefulWidget {
  const CaseFormScreen({super.key, this.caseId, this.initialAnimalId});

  final String? caseId;
  final String? initialAnimalId;

  @override
  State<CaseFormScreen> createState() => _CaseFormScreenState();
}

class _CaseFormScreenState extends State<CaseFormScreen> {
  final _repo = CasesRepository();
  final _description = TextEditingController();
  final _transcript = TranscriptController();
  List<Animal>? _animals;
  String? _animalId;
  VoiceNote? _voice;
  List<MediaItem> _media = [];
  String? _caseId;
  bool _busy = false;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _caseId = widget.caseId;
    _animalId = widget.initialAnimalId;
    _load();
  }

  Future<void> _load() async {
    try {
      final animals = await AnimalsRepository().mine();
      CaseRecord? existing;
      if (_caseId != null) existing = await _repo.byId(_caseId!);
      setState(() {
        _animals = animals;
        if (existing != null) {
          _animalId = existing.animalId;
          _description.text = existing.description ?? '';
          _voice = existing.voicePath == null ? null : VoiceNote.remote(existing.voicePath!);
          _media = [...existing.media];
        }
      });
      if (existing?.voicePath != null) _transcript.load(existing!.id);
    } catch (e) {
      setState(() => _loadError = e);
    }
  }

  Future<String?> _saveDraft() async {
    if (_animalId == null) {
      showSnack(context, 'اختر الحيوان أولاً', error: true);
      return null;
    }
    setState(() => _busy = true);
    try {
      final saved = await _repo.saveDraft(
        id: _caseId,
        animalId: _animalId!,
        description: _description.text,
        voice: _voice,
        media: _media,
      );
      _caseId = saved.id;
      // Keep the attachments as saved, so the next save neither uploads them again nor deletes them.
      _media = saved.media;
      // US-36: keep the uploaded recording (saving it again would replace it and clear its transcript),
      // then save the owner's correction of the transcript, if any.
      if (_voice?.localPath != null) {
        final path = (await _repo.byId(_caseId!)).voicePath;
        _voice = path == null ? null : VoiceNote.remote(path);
      }
      await _transcript.saveCorrection(_caseId!);
      return _caseId;
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// US-36: a new recording is saved with the draft straight away and turned into text.
  Future<void> _onVoiceChanged(VoiceNote? voice) async {
    setState(() => _voice = voice);
    _transcript.reset();
    if (voice?.localPath != null) await _transcribe();
  }

  Future<void> _transcribe() async {
    final id = await _saveDraft();
    if (id != null && mounted) await _transcript.transcribe(id);
  }

  Future<void> _onSaveCorrection() async {
    if (await _saveDraft() != null && mounted) showSnack(context, 'تم حفظ تصحيح النص.');
  }

  Future<void> _onSaveDraft() async {
    if (await _saveDraft() == null || !mounted) return;
    showSnack(context, 'تم حفظ الحالة كمسودة. يمكنك إكمالها لاحقاً.');
    context.leave('/cases', true);
  }

  /// US-07: names every missing item, saves, then sends the case and shows its case number.
  Future<void> _onSubmit() async {
    final missing = missingForSubmit(
      animalId: _animalId,
      description: _description.text,
      hasVoice: _voice != null,
    );
    if (missing.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('لا يمكن إرسال الحالة'),
          content: Text('أكمل ما يلي أولاً:\n• ${missing.join('\n• ')}'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً'))],
        ),
      );
      return;
    }
    final id = await _saveDraft();
    if (id == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final caseNumber = await db.rpc('submit_case', params: {'p_case': id}) as String;
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const SuccessCheck(),
          title: const Text('تم إرسال الحالة'),
          content: Text('رقم الحالة: $caseNumber\nيمكنك الآن حجز موعد مع طبيب بيطري.'),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً'))],
        ),
      );
      if (mounted) context.leave('/cases', true);
    } catch (e) {
      if (mounted) {
        showSnack(context, friendlyError(e, {'missing_description': 'أضف وصفاً مكتوباً أو صوتياً قبل الإرسال.'}), error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _description.dispose();
    _transcript.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return Scaffold(appBar: AppBar(), body: EmptyState(icon: Icons.cloud_off, message: friendlyError(_loadError!)));
    }
    if (_animals == null) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    if (_animals!.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('حالة جديدة')),
        body: const EmptyState(
          icon: Icons.pets,
          illustration: SpeciesCluster(['cat', 'dog', 'camel']),
          message: 'أضف ملفاً لحيوانك أولاً من صفحة «حيواناتي».',
        ),
      );
    }
    final hasAnimal = _animalId != null;
    return Scaffold(
      appBar: AppBar(title: Text(_caseId == null ? 'حالة جديدة' : 'تعديل المسودة')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
          AppCard(
            child: AnimalPicker(
              animals: _animals!,
              value: _animalId,
              onChanged: (v) => setState(() => _animalId = v),
            ),
          ),
          SectionCard(
            title: 'وصف الحالة',
            icon: Icons.edit_note_rounded,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(
                controller: _description,
                enabled: hasAnimal,
                minLines: 4,
                maxLines: 10,
                maxLength: 2000,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  hintText: hasAnimal ? 'اشرح ما يعاني منه حيوانك ومتى بدأت الأعراض' : 'اختر الحيوان أولاً',
                ),
              ),
              const SizedBox(height: 4),
              Text('أو سجّل وصفاً صوتياً:', style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Palette.muted)),
              const SizedBox(height: 8),
              VoiceRecorderField(value: _voice, onChanged: _onVoiceChanged),
              if (_voice != null) ...[
                const SizedBox(height: 14),
                TranscriptField(controller: _transcript, onTranscribe: _transcribe, onSaveCorrection: _onSaveCorrection),
              ],
            ]),
          ),
          SectionCard(
            title: 'صور وفيديو',
            icon: Icons.photo_library_outlined,
            child: MediaAttachmentsField(items: _media, onChanged: (m) => setState(() => _media = m)),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : _onSubmit,
            icon: const Icon(Icons.send_rounded),
            label: const Text('إرسال الحالة'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            style: tonalButton,
            onPressed: _busy ? null : _onSaveDraft,
            icon: const Icon(Icons.save_outlined),
            label: const Text('حفظ كمسودة'),
          ),
          if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
        ]),
      ),
    );
  }
}
