import '../../core/formatting.dart';

class MediaItem {
  const MediaItem({required this.kind, required this.sizeBytes, this.id, this.localPath, this.remotePath, this.durationSeconds});

  final String? id;
  final String kind;
  final int sizeBytes;
  final String? localPath;
  final String? remotePath;
  final int? durationSeconds;

  bool get isVideo => kind == 'video';

  factory MediaItem.fromMap(Map<String, dynamic> m) => MediaItem(
        id: m['id'] as String,
        kind: m['kind'] as String,
        sizeBytes: (m['size_bytes'] as num).toInt(),
        remotePath: m['path'] as String,
        durationSeconds: (m['duration_seconds'] as num?)?.toInt(),
      );
}

/// After a draft is saved: the form's attachments in the same order, each new one ([MediaItem.localPath])
/// replaced by what [upload] stored, so that saving again neither uploads it twice nor removes it.
Future<List<MediaItem>> replaceUploaded(List<MediaItem> items, Future<MediaItem> Function(MediaItem local) upload) async => [
      for (final m in items) m.localPath == null ? m : await upload(m),
    ];

/// The saved attachments the owner took off: every saved row whose id the form no longer lists.
List<MediaItem> removedMedia({required List<MediaItem> saved, required Set<String> keptIds}) =>
    [for (final s in saved) if (!keptIds.contains(s.id)) s];

class CaseRecord {
  const CaseRecord({
    required this.id,
    required this.animalId,
    required this.status,
    required this.createdAt,
    this.animalName,
    this.animalSpecies,
    this.caseNumber,
    this.description,
    this.voicePath,
    this.submittedAt,
    this.media = const [],
  });

  final String id;
  final String animalId;
  final String? animalName;
  final String? animalSpecies;
  final String? caseNumber;
  final String? description;
  final String? voicePath;

  /// draft, submitted or closed.
  final String status;
  final DateTime createdAt;
  final DateTime? submittedAt;
  final List<MediaItem> media;

  bool get isDraft => status == 'draft';

  factory CaseRecord.fromMap(Map<String, dynamic> m) => CaseRecord(
        id: m['id'] as String,
        animalId: m['animal_id'] as String,
        animalName: (m['animals'] as Map<String, dynamic>?)?['name'] as String?,
        animalSpecies: (m['animals'] as Map<String, dynamic>?)?['species'] as String?,
        caseNumber: m['case_number'] as String?,
        description: m['description'] as String?,
        voicePath: m['voice_path'] as String?,
        status: m['status'] as String,
        createdAt: parseTs(m['created_at']),
        submittedAt: parseTsOrNull(m['submitted_at']),
        media: [for (final x in (m['case_media'] as List? ?? const [])) MediaItem.fromMap(x as Map<String, dynamic>)],
      );
}
