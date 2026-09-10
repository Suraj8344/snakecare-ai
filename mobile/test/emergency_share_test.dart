import 'package:flutter_test/flutter_test.dart';
import 'package:snakecare_mobile/src/features/medical_passport/domain/medical_passport.dart';
import 'package:snakecare_mobile/src/features/offline_resilience/domain/emergency_share.dart';

void main() {
  test('missing GPS never shares the Pune demonstration coordinates', () {
    final text = emergencyLocationText(null, null);
    expect(text, contains('Location unavailable'));
    expect(text, isNot(contains('18.5204')));
    expect(text, isNot(contains('maps.google.com')));
    expect(emergencyLocationText(19, 74), contains('q=19.0,74.0'));
  });

  test('health share contains useful facts but excludes insurance and dosage',
      () {
    const passport = MedicalPassport(
      healthId: 'test-id',
      version: 1,
      fullName: 'Test Patient',
      biologicalSex: 'unknown',
      bloodGroup: 'O+',
      organDonor: false,
      insurancePolicyNumber: 'private-policy',
      allergies: [PassportAllergy(allergen: 'Penicillin', severity: 'severe')],
      conditions: [],
      medications: [
        PassportMedication(name: 'Test medicine', dosage: 'private-dose'),
      ],
      emergencyContacts: [],
      surgeries: [],
      familyHistory: [],
    );
    final text = emergencyHealthSummary(passport);
    expect(text, contains('Test Patient'));
    expect(text, contains('Penicillin'));
    expect(text, contains('Test medicine'));
    expect(text, contains('patient-reported'));
    expect(text, isNot(contains('private-policy')));
    expect(text, isNot(contains('private-dose')));
  });

  test('contact validation accepts formatted numbers and rejects empty input',
      () {
    expect(validEmergencyPhone('+91 98765 43210'), isTrue);
    expect(validEmergencyPhone(''), isFalse);
    expect(validEmergencyPhone('abc1234567'), isFalse);
  });
}
