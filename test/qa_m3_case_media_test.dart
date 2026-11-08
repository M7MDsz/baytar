import 'package:baytar/features/cases/case_record.dart';
import 'package:flutter_test/flutter_test.dart';

// QA M-3: saving a draft twice must not upload an attachment again or delete it.
void main() {
  const savedPhoto = MediaItem(id: 'a', kind: 'photo', sizeBytes: 10, remotePath: 'u/c/a.jpg');
  const newPhoto = MediaItem(kind: 'photo', sizeBytes: 20, localPath: '/tmp/b.jpg');
  const newVideo = MediaItem(kind: 'video', sizeBytes: 30, localPath: '/tmp/c.mp4', durationSeconds: 12);

  Future<MediaItem> Function(MediaItem) fakeUpload(List<MediaItem> calls) => (m) async {
        calls.add(m);
        return MediaItem(id: 'id-${m.localPath}', kind: m.kind, sizeBytes: m.sizeBytes, remotePath: 'u/c/${calls.length}');
      };

  test('new attachments are uploaded once and replaced by their saved rows, in the same order', () async {
    final calls = <MediaItem>[];
    final saved = await replaceUploaded([savedPhoto, newPhoto, newVideo], fakeUpload(calls));

    expect(calls, [newPhoto, newVideo]);
    expect(saved.map((m) => m.id), ['a', 'id-/tmp/b.jpg', 'id-/tmp/c.mp4']);
    expect(saved.first, same(savedPhoto));
    expect(saved.every((m) => m.localPath == null), isTrue);
  });

  test('saving the saved list again uploads nothing and removes nothing', () async {
    final first = await replaceUploaded([savedPhoto, newPhoto], fakeUpload([]));

    final calls = <MediaItem>[];
    final second = await replaceUploaded(first, fakeUpload(calls));
    final gone = removedMedia(saved: first, keptIds: {for (final m in second) m.id!});

    expect(calls, isEmpty);
    expect(gone, isEmpty);
  });

  test('only the attachments the owner took off are removed', () {
    const b = MediaItem(id: 'b', kind: 'photo', sizeBytes: 1, remotePath: 'u/c/b.jpg');
    const c = MediaItem(id: 'c', kind: 'video', sizeBytes: 1, remotePath: 'u/c/c.mp4');

    expect(removedMedia(saved: [savedPhoto, b, c], keptIds: {'a', 'c'}), [b]);
    expect(removedMedia(saved: [savedPhoto, b], keptIds: {}), [savedPhoto, b]);
    expect(removedMedia(saved: [], keptIds: {'a'}), isEmpty);
  });
}
