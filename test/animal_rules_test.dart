import 'package:baytar/core/validators.dart';
import 'package:flutter_test/flutter_test.dart';

// US-01 / US-02 field rules.
void main() {
  test('name, species and sex are required', () {
    expect(requiredText('', 'اسم الحيوان'), isNotNull);
    expect(requiredText('  ', 'اسم الحيوان'), isNotNull);
    expect(requiredText('Luna', 'اسم الحيوان'), isNull);
    expect(requiredChoice(null, 'النوع'), isNotNull);
    expect(requiredChoice('cat', 'النوع'), isNull);
  });

  test('age or date of birth: at least one is required', () {
    expect(ageOrBirthDate(age: '', birthDate: null), isNotNull);
    expect(ageOrBirthDate(age: '3', birthDate: null), isNull);
    expect(ageOrBirthDate(age: '', birthDate: DateTime(2022, 5, 1)), isNull);
  });

  test('date of birth cannot be in the future and age must be sensible', () {
    expect(ageOrBirthDate(age: '', birthDate: DateTime.now().add(const Duration(days: 2))), isNotNull);
    expect(ageOrBirthDate(age: '-1', birthDate: null), isNotNull);
    expect(ageOrBirthDate(age: 'abc', birthDate: null), isNotNull);
  });

  test('optional weight must be positive when given', () {
    expect(optionalPositiveNumber('', 'الوزن'), isNull);
    expect(optionalPositiveNumber('4.5', 'الوزن'), isNull);
    expect(optionalPositiveNumber('0', 'الوزن'), isNotNull);
  });
}
