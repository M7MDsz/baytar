import 'package:baytar/features/voice/model/transcript_label.dart';
import 'package:baytar/features/voice/transcript_state.dart';
import 'package:flutter_test/flutter_test.dart';

// US-36 Turn a Voice Description into Text: what the owner's case form shows for each stored and returned state.
void main() {
  group('a saved draft', () {
    test('with an automatic transcript is ready to correct, labelled «نص تلقائي»', () {
      final t = SavedTranscript.fromRow({
        'transcript': '  لونا تحك أذنها من ثلاث أيام  ',
        'transcript_status': 'done',
        'transcript_label': 'auto',
      });
      expect(t.phase, TranscriptPhase.ready);
      expect(t.label, TranscriptLabel.auto);
      expect(t.label.text, 'نص تلقائي');
      expect(t.text, 'لونا تحك أذنها من ثلاث أيام');
    });

    test('corrected by the owner is labelled «عدّله المالك»', () {
      final t = SavedTranscript.fromRow({'transcript': 'نص', 'transcript_status': 'done', 'transcript_label': 'owner'});
      expect(t.label.text, 'عدّله المالك');
    });

    test('still being transcribed shows the loading state', () {
      final t = SavedTranscript.fromRow({'transcript': null, 'transcript_status': 'pending', 'transcript_label': 'pending'});
      expect(t.phase, TranscriptPhase.loading);
    });

    test('stuck in pending for more than 3 minutes counts as failed, so the owner can try again (QA M-7)', () {
      final stuck = {'transcript': null, 'transcript_status': 'pending', 'transcript_label': 'pending'};
      expect(SavedTranscript.fromRow({...stuck, 'transcript_pending_expired': true}).phase, TranscriptPhase.failed);
      expect(SavedTranscript.fromRow({...stuck, 'transcript_pending_expired': false}).phase, TranscriptPhase.loading);
    });

    test('that failed shows the gentle note; never transcribed offers to try', () {
      expect(SavedTranscript.fromRow({'transcript_status': 'failed', 'transcript_label': 'unavailable'}).phase,
          TranscriptPhase.failed);
      expect(SavedTranscript.fromRow({'transcript_status': null, 'transcript_label': 'unavailable'}).phase,
          TranscriptPhase.idle);
    });
  });

  group('the transcribe-voice reply', () {
    test('done with text is an automatic transcript', () {
      final t = transcriptFromReply({'status': 'done', 'transcript': 'تعرج على رجلها', 'reason': null});
      expect(t.phase, TranscriptPhase.ready);
      expect(t.label, TranscriptLabel.auto);
      expect(t.text, 'تعرج على رجلها');
    });

    test('failed, empty or unreadable replies are failures, so the case goes with the recording only', () {
      expect(transcriptFromReply({'status': 'failed', 'transcript': null, 'reason': 'timeout'}).phase,
          TranscriptPhase.failed);
      expect(transcriptFromReply({'status': 'done', 'transcript': '  '}).phase, TranscriptPhase.failed);
      expect(transcriptFromReply('oops').phase, TranscriptPhase.failed);
    });

    test('error codes: a changed draft is read again, a missing recording can be retried, the rest fail gently', () {
      expect(transcribeErrorCode({'error': 'case_changed'}), 'case_changed');
      expect(transcribeErrorCode('not json'), isNull);
      expect(recoveryFor('case_changed'), TranscribeRecovery.reload);
      expect(recoveryFor('no_recording'), TranscribeRecovery.retry);
      expect(recoveryFor('not_draft'), TranscribeRecovery.failed);
      expect(recoveryFor('case_not_found'), TranscribeRecovery.failed);
      expect(recoveryFor(null), TranscribeRecovery.failed);
    });
  });

  test('a correction is pending only when the text really changed', () {
    expect(hasUnsavedCorrection(saved: 'تحك أذنها', edited: 'تحك أذنها '), isFalse);
    expect(hasUnsavedCorrection(saved: 'تحك أذنها', edited: 'تحك أذنها اليسرى'), isTrue);
    expect(hasUnsavedCorrection(saved: 'تحك أذنها', edited: ''), isTrue);
  });
}
