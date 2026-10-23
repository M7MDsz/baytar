import 'package:baytar/core/session.dart';
import 'package:baytar/features/consultation/join_window.dart';
import 'package:flutter_test/flutter_test.dart';

// US-14 (owner: 10 min before to 15 after) and US-19 (veterinarian: 15 before to 15 after).
void main() {
  final start = DateTime(2026, 10, 15, 18);

  test('owner can join from 10 minutes before until 15 minutes after the start', () {
    expect(canJoinNow(start, UserRole.owner, now: start.subtract(const Duration(minutes: 11))), isFalse);
    expect(canJoinNow(start, UserRole.owner, now: start.subtract(const Duration(minutes: 10))), isTrue);
    expect(canJoinNow(start, UserRole.owner, now: start.add(const Duration(minutes: 15))), isTrue);
    expect(canJoinNow(start, UserRole.owner, now: start.add(const Duration(minutes: 16))), isFalse);
  });

  test('veterinarian can join 15 minutes before the start', () {
    expect(canJoinNow(start, UserRole.vet, now: start.subtract(const Duration(minutes: 15))), isTrue);
    expect(canJoinNow(start, UserRole.vet, now: start.subtract(const Duration(minutes: 16))), isFalse);
  });

  test('the blocked reason says whether it is too early or too late', () {
    expect(joinBlockedReason(start, UserRole.owner, now: start.subtract(const Duration(hours: 1))), 'too_early');
    expect(joinBlockedReason(start, UserRole.owner, now: start.add(const Duration(minutes: 20))), 'too_late');
    expect(joinBlockedReason(start, UserRole.owner, now: start), isNull);
  });
}
