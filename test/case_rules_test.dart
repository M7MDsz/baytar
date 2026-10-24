import 'package:baytar/features/cases/case_validation.dart';
import 'package:baytar/features/cases/media_rules.dart';
import 'package:flutter_test/flutter_test.dart';

// US-03 / US-05 rules (US-07 uses missingForSubmit when sending).
void main() {
  group('attachments (US-05)', () {
    test('JPG, PNG and MP4 are accepted', () {
      expect(mediaRejection(extension: 'jpg', sizeBytes: 1000), isNull);
      expect(mediaRejection(extension: 'PNG', sizeBytes: 1000), isNull);
      expect(mediaRejection(extension: 'mp4', sizeBytes: 1000, durationSeconds: 120), isNull);
    });

    test('other types are rejected and the message names the supported types', () {
      final reason = mediaRejection(extension: 'gif', sizeBytes: 1000);
      expect(reason, contains('JPG'));
      expect(reason, contains('MP4'));
    });

    test('files over 30 MB are rejected with the limit in the message', () {
      expect(mediaRejection(extension: 'jpg', sizeBytes: maxMediaBytes + 1), contains('30'));
      expect(mediaRejection(extension: 'jpg', sizeBytes: maxMediaBytes), isNull);
    });

    test('videos longer than 3 minutes are rejected', () {
      expect(mediaRejection(extension: 'mp4', sizeBytes: 1000, durationSeconds: 181), isNotNull);
      expect(mediaRejection(extension: 'mp4', sizeBytes: 1000, durationSeconds: 180), isNull);
    });
  });

  group('what a case needs before sending', () {
    test('an animal and a written or voice description', () {
      expect(missingForSubmit(animalId: null, description: '', hasVoice: false), hasLength(2));
      expect(missingForSubmit(animalId: 'a1', description: '  ', hasVoice: false), hasLength(1));
      expect(missingForSubmit(animalId: 'a1', description: '', hasVoice: true), isEmpty);
      expect(missingForSubmit(animalId: 'a1', description: 'يعرج منذ يومين', hasVoice: false), isEmpty);
    });
  });
}
