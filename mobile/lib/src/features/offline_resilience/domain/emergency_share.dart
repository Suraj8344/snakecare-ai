import 'package:snakecare_mobile/src/features/medical_passport/domain/medical_passport.dart';

/// Plain text works both in SMS and in an offline-readable QR code.
/// Never contains access tokens, insurance identifiers or report links.
String emergencyHealthSummary(MedicalPassport passport) {
  String values(Iterable<String> items) =>
      items.isEmpty ? 'Not recorded' : items.join(', ');
  return 'SnakeCare emergency health card (patient-reported)\n'
      'Name: ${passport.fullName ?? 'Not recorded'}\n'
      'Health ID: ${passport.healthId}\n'
      'Blood group: ${passport.bloodGroup}\n'
      'Allergies: ${values(passport.allergies.map((a) => a.allergen))}\n'
      'Conditions: ${values(passport.conditions.map((c) => c.name))}\n'
      'Medications: ${values(passport.medications.map((m) => m.name))}';
}

bool validEmergencyPhone(String value) => RegExp(r'^\+?[0-9]{7,15}$')
    .hasMatch(value.replaceAll(RegExp(r'[\s()-]'), ''));

String emergencyLocationText(double? latitude, double? longitude) => latitude ==
            null ||
        longitude == null
    ? 'Location unavailable. Call the patient to confirm their location.'
    : 'GPS: ${latitude.toStringAsFixed(5)},${longitude.toStringAsFixed(5)}\n'
        'Map: https://maps.google.com/?q=$latitude,$longitude';
