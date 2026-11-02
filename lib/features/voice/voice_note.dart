import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

/// A voice description: either just recorded on the phone ([localPath]) or already saved ([remotePath]).
class VoiceNote {
  const VoiceNote.local(String path)
      : localPath = path,
        remotePath = null;

  const VoiceNote.remote(String path)
      : localPath = null,
        remotePath = path;

  final String? localPath;
  final String? remotePath;

  bool get isSaved => remotePath != null;
}

const voiceBucket = 'case-voice';

/// The browser records 16 kHz mono WAV (every browser supports it): 5 minutes stay under 10 MB.
const webRecordConfig = RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1);

/// The saved recording's file extension and content type: AAC in .m4a on a phone, WAV in a browser.
const voiceExtension = kIsWeb ? 'wav' : 'm4a';
const voiceContentType = kIsWeb ? 'audio/wav' : 'audio/mp4';
