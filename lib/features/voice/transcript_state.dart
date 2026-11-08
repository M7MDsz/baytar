import 'model/transcript_label.dart';

/// US-36: what the transcript part of the owner's case form shows.
enum TranscriptPhase {
  /// A recording exists but has no transcript yet: offer to turn it into text.
  idle,

  /// The transcribe-voice function is working.
  loading,

  /// A transcript the owner can read and correct.
  ready,

  /// It could not be transcribed. The case can still be sent; the veterinarian gets the recording only.
  failed,
}

/// A draft's transcript as stored on the case (`transcript`, `transcript_status`, `transcript_label`,
/// `transcript_pending_expired`).
class SavedTranscript {
  const SavedTranscript({required this.phase, required this.label, required this.text});

  final TranscriptPhase phase;
  final TranscriptLabel label;
  final String text;

  factory SavedTranscript.fromRow(Map<String, dynamic> row) {
    final text = (row['transcript'] as String? ?? '').trim();
    final phase = switch (row['transcript_status']) {
      'done' when text.isNotEmpty => TranscriptPhase.ready,
      // Still "pending" after 3 minutes: the function died on the way (QA M-7). Offer to try again.
      'pending' when row['transcript_pending_expired'] == true => TranscriptPhase.failed,
      'pending' => TranscriptPhase.loading,
      'failed' => TranscriptPhase.failed,
      _ => TranscriptPhase.idle,
    };
    return SavedTranscript(
      phase: phase,
      label: phase == TranscriptPhase.ready ? TranscriptLabel.parse(row['transcript_label']) : TranscriptLabel.none,
      text: phase == TranscriptPhase.ready ? text : '',
    );
  }
}

/// The transcribe-voice reply: `{status: 'done' | 'failed', transcript, reason}`.
SavedTranscript transcriptFromReply(Object? data) {
  final reply = data is Map ? data : const {};
  final text = (reply['transcript'] as String? ?? '').trim();
  if (reply['status'] == 'done' && text.isNotEmpty) {
    return SavedTranscript(phase: TranscriptPhase.ready, label: TranscriptLabel.auto, text: text);
  }
  return const SavedTranscript(phase: TranscriptPhase.failed, label: TranscriptLabel.none, text: '');
}

/// The short code in a transcribe-voice error body (`{error: 'case_changed'}`), if any.
String? transcribeErrorCode(Object? details) => details is Map && details['error'] is String ? details['error'] as String : null;

/// What the form does after a transcribe-voice error code.
enum TranscribeRecovery {
  /// The draft changed meanwhile (`case_changed`): read the stored transcript again.
  reload,

  /// The recording is not saved yet (`no_recording`): offer to try again.
  retry,

  /// Anything else: show the gentle failure note; the case can still be sent.
  failed,
}

TranscribeRecovery recoveryFor(String? code) => switch (code) {
      'case_changed' => TranscribeRecovery.reload,
      'no_recording' => TranscribeRecovery.retry,
      _ => TranscribeRecovery.failed,
    };

/// True when the owner changed the transcript and the correction is not saved yet.
bool hasUnsavedCorrection({required String saved, required String edited}) => edited.trim() != saved.trim();
