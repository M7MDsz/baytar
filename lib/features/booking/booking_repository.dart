import '../../core/formatting.dart';
import '../../core/supabase.dart';
import 'owner_appointment.dart';

typedef FreeSlot = ({String id, DateTime startsAt});
typedef BookableCase = ({String id, String? caseNumber, String animalName});

const bookingErrors = {
  'slot_unavailable': 'لم يعد هذا الموعد متاحاً. اختر موعداً آخر.',
  'case_not_submitted': 'يجب إرسال الحالة قبل حجز موعد لها.',
  'case_already_booked': 'لهذه الحالة موعد محجوز بالفعل.',
  'case_not_found': 'لم يتم العثور على الحالة.',
};

class BookingRepository {
  Future<List<FreeSlot>> freeSlots(String vetId) async {
    final rows = await db.rpc('available_slots', params: {'p_vet': vetId}) as List;
    return [for (final r in rows.cast<Map<String, dynamic>>()) (id: r['id'] as String, startsAt: parseTs(r['starts_at']))];
  }

  Future<List<BookableCase>> bookableCases() async {
    final rows = await db.rpc('bookable_cases') as List;
    return [
      for (final r in rows.cast<Map<String, dynamic>>())
        (id: r['id'] as String, caseNumber: r['case_number'] as String?, animalName: r['animal_name'] as String),
    ];
  }

  Future<String> book({required String slotId, required String caseId}) async =>
      await db.rpc('book_appointment', params: {'p_slot': slotId, 'p_case': caseId}) as String;

  Future<List<OwnerAppointment>> mine() async {
    final rows = await db.rpc('my_appointments') as List;
    return rows.map((r) => OwnerAppointment.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<OwnerAppointment> byId(String id) async {
    final rows = await db.rpc('my_appointments', params: {'p_appointment': id}) as List;
    return OwnerAppointment.fromMap(rows.single as Map<String, dynamic>);
  }
}
