import 'package:baytar/features/booking/owner_appointment.dart';
import 'package:baytar/features/reschedule/appointment_change.dart';
import 'package:baytar/features/vet_registration/vet_application.dart';
import 'package:flutter_test/flutter_test.dart';

OwnerAppointment _appointment(DateTime startsAt, {String status = 'booked'}) => OwnerAppointment(
      id: 'a',
      caseId: 'c',
      animalName: 'Luna',
      vetId: 'v',
      vetName: 'Dr',
      startsAt: startsAt,
      status: status,
      hasOutcome: false,
    );

// US-12 / US-13: reschedule and cancel only more than 12 hours before the start. US-31 license file rules.
void main() {
  final now = DateTime(2026, 10, 15, 9);

  test('changes allowed more than 12 hours before the start', () {
    expect(canChangeAppointment(_appointment(now.add(const Duration(hours: 13))), now: now), isTrue);
    expect(canChangeAppointment(_appointment(now.add(const Duration(hours: 12))), now: now), isFalse);
    expect(canChangeAppointment(_appointment(now.add(const Duration(hours: 2))), now: now), isFalse);
  });

  test('cancelled appointments cannot be changed', () {
    expect(canChangeAppointment(_appointment(now.add(const Duration(days: 3)), status: 'cancelled'), now: now), isFalse);
  });

  test('license file must be PDF, JPG or PNG up to 10 MB', () {
    expect(licenseFileRejection('pdf', 1000), isNull);
    expect(licenseFileRejection('png', maxLicenseBytes), isNull);
    expect(licenseFileRejection('docx', 1000), isNotNull);
    expect(licenseFileRejection('jpg', maxLicenseBytes + 1), isNotNull);
  });
}
