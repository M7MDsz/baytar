import 'dart:io';

import '../../core/storage.dart';
import '../../core/supabase.dart';
import '../voice/voice_note.dart';
import 'case_record.dart';
import 'media_rules.dart';

const mediaBucket = 'case-media';

class CasesRepository {
  static const _select = '*, animals(name), case_media(*)';

  Future<List<CaseRecord>> mine({required bool drafts}) async {
    final query = db.from('cases').select(_select).eq('owner_id', currentUserId!);
    final rows = drafts
        ? await query.eq('status', 'draft').order('updated_at', ascending: false)
        : await query.neq('status', 'draft').order('submitted_at', ascending: false);
    return rows.map(CaseRecord.fromMap).toList();
  }

  Future<CaseRecord> byId(String id) async => CaseRecord.fromMap(await db.from('cases').select(_select).eq('id', id).single());

  /// Saves the case as a draft: creates it when [id] is null, uploads a new recording and new attachments,
  /// and removes attachments the owner took off. Returns the case id.
  Future<String> saveDraft({
    String? id,
    required String animalId,
    required String? description,
    required VoiceNote? voice,
    required List<MediaItem> media,
  }) async {
    final text = description?.trim();
    final caseId = id ??
        (await db.from('cases').insert({'animal_id': animalId, 'description': text}).select('id').single())['id'] as String;

    String? voicePath = voice?.remotePath;
    if (voice?.localPath != null) {
      voicePath = await uploadFile(voiceBucket, userFilePath(caseId, 'm4a'), File(voice!.localPath!), contentType: 'audio/mp4');
    }
    await db.from('cases').update({'animal_id': animalId, 'description': text, 'voice_path': voicePath}).eq('id', caseId);

    final kept = media.where((m) => m.id != null).map((m) => m.id!).toList();
    final removed = db.from('case_media').delete().eq('case_id', caseId);
    await (kept.isEmpty ? removed : removed.not('id', 'in', '(${kept.join(',')})'));

    for (final m in media.where((m) => m.localPath != null)) {
      final ext = extensionOf(m.localPath!);
      final path = await uploadFile(mediaBucket, userFilePath(caseId, ext), File(m.localPath!), contentType: mediaContentType(ext));
      await db.from('case_media').insert({
        'case_id': caseId,
        'path': path,
        'kind': m.kind,
        'size_bytes': m.sizeBytes,
        'duration_seconds': m.durationSeconds,
      });
    }
    return caseId;
  }
}
