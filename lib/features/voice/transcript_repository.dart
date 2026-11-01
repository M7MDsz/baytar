import 'dart:async';

import '../../core/supabase.dart';
import 'transcript_state.dart';

/// US-36: the draft's transcript on the live backend.
class TranscriptRepository {
  static const _columns = 'transcript, transcript_status, transcript_label';

  /// The transcript stored on the draft. `transcript_label` is a computed column of `cases`.
  Future<SavedTranscript> fetch(String caseId) async =>
      SavedTranscript.fromRow(await db.from('cases').select(_columns).eq('id', caseId).single());

  /// Asks the transcribe-voice function to write an Arabic transcript of the draft's saved recording.
  /// The function answers within about 25 seconds; past 45 the attempt counts as failed.
  Future<SavedTranscript> transcribe(String caseId) async {
    final res = await db.functions
        .invoke('transcribe-voice', body: {'caseId': caseId})
        .timeout(const Duration(seconds: 45));
    return transcriptFromReply(res.data);
  }

  /// Saves the owner's correction. The database labels it "corrected by owner"; a blank text clears the transcript.
  Future<SavedTranscript> saveCorrection(String caseId, String text) async {
    final value = text.trim();
    await db.from('cases').update({'transcript': value.isEmpty ? null : value}).eq('id', caseId);
    return fetch(caseId);
  }
}
