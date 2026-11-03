import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../../core/storage.dart';
import '../../core/supabase.dart';
import '../voice/voice_note.dart';
import 'case_record.dart';
import 'media_rules.dart';

const mediaBucket = 'case-media';

class CasesRepository {
  static const _select = '*, animals(name, species), case_media(*)';

  Future<List<CaseRecord>> mine({required bool drafts}) async {
    final query = db.from('cases').select(_select).eq('owner_id', currentUserId!);
    final rows = drafts
        ? await query.eq('status', 'draft').order('updated_at', ascending: false)
        : await query.neq('status', 'draft').order('submitted_at', ascending: false);
    return rows.map(CaseRecord.fromMap).toList();
  }

  Future<CaseRecord> byId(String id) async => CaseRecord.fromMap(await db.from('cases').select(_select).eq('id', id).single());

  /// Saves the case as a draft: creates it when [id] is null, uploads a new recording and new attachments,
  /// and removes attachments the owner took off. Returns the case id and the attachments as saved, which the
  /// form keeps so that saving again neither uploads them twice nor removes them.
  Future<({String id, List<MediaItem> media})> saveDraft({
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
      final path = userFilePath(caseId, voiceExtension);
      voicePath = kIsWeb
          ? await uploadBytes(voiceBucket, path, await XFile(voice!.localPath!).readAsBytes(), contentType: voiceContentType)
          : await uploadFile(voiceBucket, path, File(voice!.localPath!), contentType: voiceContentType);
    }
    await db.from('cases').update({'animal_id': animalId, 'description': text, 'voice_path': voicePath}).eq('id', caseId);

    // New files first. Rows the owner took off are removed only once every new file is stored, so a failed
    // upload never leaves the case with fewer attachments than it had.
    final saved = await replaceUploaded(media, (m) => _uploadMedia(caseId, m));
    final rows = await db.from('case_media').select().eq('case_id', caseId);
    final gone = removedMedia(saved: rows.map(MediaItem.fromMap).toList(), keptIds: {for (final m in saved) m.id!});
    if (gone.isNotEmpty) {
      await db.from('case_media').delete().inFilter('id', [for (final m in gone) m.id!]);
      // Their files go too. A file that fails to delete is only unused storage: the case no longer lists it.
      try {
        await db.storage.from(mediaBucket).remove([for (final m in gone) m.remotePath!]);
      } catch (_) {}
    }
    return (id: caseId, media: saved);
  }

  Future<MediaItem> _uploadMedia(String caseId, MediaItem m) async {
    final ext = extensionOf(m.localPath!);
    final path = await uploadFile(mediaBucket, userFilePath(caseId, ext), File(m.localPath!), contentType: mediaContentType(ext));
    final row = await db
        .from('case_media')
        .insert({
          'case_id': caseId,
          'path': path,
          'kind': m.kind,
          'size_bytes': m.sizeBytes,
          'duration_seconds': m.durationSeconds,
        })
        .select()
        .single();
    return MediaItem.fromMap(row);
  }
}
