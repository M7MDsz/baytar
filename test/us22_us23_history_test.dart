import 'package:baytar/features/history/consultation_history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

// US-22 View an Animal's Consultation History, US-23 Open a Past Consultation Record.
void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  Map<String, dynamic> entry(String id, String startsAt, {String outcome = 'approved'}) => {
        'appointment_id': id,
        'case_id': 'case-$id',
        'case_number': 'BT-$id',
        'consultation_date': startsAt.substring(0, 10),
        'starts_at': startsAt,
        'vet_name': 'سارة العتيبي',
        'outcome_status': outcome,
      };

  group('history', () {
    test('is newest first, whatever order it arrives in', () {
      final list = newestFirst([
        HistoryEntry.fromMap(entry('a', '2026-09-10T07:00:00Z')),
        HistoryEntry.fromMap(entry('b', '2026-11-02T07:00:00Z')),
        HistoryEntry.fromMap(entry('c', '2025-12-01T07:00:00Z')),
      ]);
      expect(list.map((e) => e.appointmentId), ['b', 'a', 'c']);
    });

    test('reads the outcome status and keeps the vet gender for the avatar', () {
      final approved = HistoryEntry.fromMap(entry('a', '2026-11-02T07:00:00Z'), vetGender: 'female');
      final pending = HistoryEntry.fromMap(entry('b', '2026-11-02T07:00:00Z', outcome: 'pending'));
      expect(approved.outcomeApproved, isTrue);
      expect(approved.vetGender, 'female');
      expect(pending.outcomeApproved, isFalse);
      expect(outcomeStatusLabel(true), 'النتيجة معتمدة');
      expect(outcomeStatusLabel(false), 'بانتظار النتيجة');
    });

    test('dates show the weekday this year and the year for earlier ones', () {
      final now = DateTime(2026, 11, 3);
      expect(historyDateLabel(DateTime(2026, 11, 2, 10), now: now), 'الاثنين 2 نوفمبر');
      expect(historyDateLabel(DateTime(2025, 12, 1, 10), now: now), '1 ديسمبر 2025');
    });

    test('names carry the doctor title once, and counts read naturally', () {
      expect(vetDisplayName('سارة العتيبي'), 'د. سارة العتيبي');
      expect(vetDisplayName('د. سارة العتيبي'), 'د. سارة العتيبي');
      expect(consultationCountLabel(0), 'لا توجد استشارات بعد');
      expect(consultationCountLabel(1), 'استشارة واحدة');
      expect(consultationCountLabel(2), 'استشارتان');
      expect(consultationCountLabel(3), '3 استشارات');
      expect(consultationCountLabel(11), '11 استشارة');
    });

    test('paths for the history and a record', () {
      expect(animalHistoryPath('a1'), '/animals/a1/history');
      expect(consultationRecordPath('a1', 'p1'), '/animals/a1/history/p1');
      expect(consultationHeroTag('p1'), isNot(consultationHeroTag('p2')));
    });
  });

  group('record', () {
    Map<String, dynamic> record({required String outcome, String? referral}) => {
          'appointment_id': 'p1',
          'case_id': 'c1',
          'case_number': 'BT-1',
          'animal_id': 'a1',
          'animal_name': 'لونا',
          'consultation_date': '2026-11-02',
          'starts_at': '2026-11-02T07:00:00Z',
          'vet_name': 'سارة العتيبي',
          'description': 'لونا تحك أذنها',
          'has_voice': true,
          'outcome_status': outcome,
          'findings': 'التهاب في الأذن الخارجية',
          'guidance': 'تنظيف الأذن مرتين يومياً',
          'owner_notes': null,
          'approved_at': '2026-11-02T08:00:00Z',
          'referral_reason': referral,
          'referral_instructions': referral == null ? null : 'زيارة عيادة خلال يومين',
          'referred_at': referral == null ? null : '2026-11-02T07:30:00Z',
        };

    test('shows the documented outcome only once it is approved', () {
      final approved = ConsultationRecord.fromMap(record(outcome: 'approved'));
      expect(approved.findings, 'التهاب في الأذن الخارجية');
      expect(approved.approvedAt, isNotNull);
      final pending = ConsultationRecord.fromMap(record(outcome: 'pending'));
      expect(pending.findings, isNull);
      expect(pending.guidance, isNull);
      expect(pending.approvedAt, isNull);
      expect(pending.description, 'لونا تحك أذنها');
    });

    test('carries the referral when there is one', () {
      expect(ConsultationRecord.fromMap(record(outcome: 'pending')).hasReferral, isFalse);
      final referred = ConsultationRecord.fromMap(record(outcome: 'approved', referral: 'يحتاج فحصاً بالمنظار'));
      expect(referred.hasReferral, isTrue);
      expect(referred.referralInstructions, 'زيارة عيادة خلال يومين');
      expect(referred.hasVoice, isTrue);
    });
  });
}
