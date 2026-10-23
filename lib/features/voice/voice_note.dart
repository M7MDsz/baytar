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
