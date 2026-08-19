class PassportAllergy {
  const PassportAllergy({
    required this.allergen,
    required this.severity,
    this.reaction,
  });
  factory PassportAllergy.fromJson(Map<String, dynamic> json) =>
      PassportAllergy(
        allergen: json['allergen'] as String,
        reaction: json['reaction'] as String?,
        severity: json['severity'] as String,
      );
  final String allergen;
  final String? reaction;
  final String severity;
  Map<String, dynamic> toJson() =>
      {'allergen': allergen, 'reaction': reaction, 'severity': severity};
}

class PassportCondition {
  const PassportCondition({
    required this.name,
    required this.status,
    this.diagnosedOn,
    this.notes,
  });
  factory PassportCondition.fromJson(Map<String, dynamic> json) =>
      PassportCondition(
        name: json['name'] as String,
        status: json['status'] as String,
        diagnosedOn: json['diagnosed_on'] as String?,
        notes: json['notes'] as String?,
      );
  final String name;
  final String status;
  final String? diagnosedOn;
  final String? notes;
  Map<String, dynamic> toJson() => {
        'name': name,
        'status': status,
        'diagnosed_on': diagnosedOn,
        'notes': notes,
      };
}

class PassportMedication {
  const PassportMedication({
    required this.name,
    this.dosage,
    this.frequency,
    this.route,
    this.notes,
  });
  factory PassportMedication.fromJson(Map<String, dynamic> json) =>
      PassportMedication(
        name: json['name'] as String,
        dosage: json['dosage'] as String?,
        frequency: json['frequency'] as String?,
        route: json['route'] as String?,
        notes: json['notes'] as String?,
      );
  final String name;
  final String? dosage;
  final String? frequency;
  final String? route;
  final String? notes;
  Map<String, dynamic> toJson() => {
        'name': name,
        'dosage': dosage,
        'frequency': frequency,
        'route': route,
        'notes': notes,
      };
}

class PassportEmergencyContact {
  const PassportEmergencyContact({
    required this.name,
    required this.relationship,
    required this.phoneNumber,
    this.priority = 1,
  });
  factory PassportEmergencyContact.fromJson(Map<String, dynamic> json) =>
      PassportEmergencyContact(
        name: json['name'] as String,
        relationship: json['relationship'] as String,
        phoneNumber: json['phone_number'] as String,
        priority: json['priority'] as int,
      );
  final String name;
  final String relationship;
  final String phoneNumber;
  final int priority;
  Map<String, dynamic> toJson() => {
        'name': name,
        'relationship': relationship,
        'phone_number': phoneNumber,
        'priority': priority,
      };
}

class PassportSurgery {
  const PassportSurgery({
    required this.procedure,
    this.performedOn,
    this.hospital,
    this.notes,
  });

  factory PassportSurgery.fromJson(Map<String, dynamic> json) =>
      PassportSurgery(
        procedure: json['procedure'] as String,
        performedOn: json['performed_on'] as String?,
        hospital: json['hospital'] as String?,
        notes: json['notes'] as String?,
      );

  final String procedure;
  final String? performedOn;
  final String? hospital;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'procedure': procedure,
        'performed_on': performedOn,
        'hospital': hospital,
        'notes': notes,
      };
}

class PassportFamilyHistory {
  const PassportFamilyHistory({
    required this.relationship,
    required this.condition,
    this.notes,
  });

  factory PassportFamilyHistory.fromJson(Map<String, dynamic> json) =>
      PassportFamilyHistory(
        relationship: json['relationship'] as String,
        condition: json['condition'] as String,
        notes: json['notes'] as String?,
      );

  final String relationship;
  final String condition;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'relationship': relationship,
        'condition': condition,
        'notes': notes,
      };
}

class MedicalPassport {
  const MedicalPassport({
    required this.healthId,
    required this.version,
    required this.biologicalSex,
    required this.bloodGroup,
    required this.organDonor,
    required this.allergies,
    required this.conditions,
    required this.medications,
    required this.emergencyContacts,
    required this.surgeries,
    required this.familyHistory,
    this.fullName,
    this.dateOfBirth,
    this.heightCm,
    this.weightKg,
    this.preferredLanguage,
    this.insuranceProvider,
    this.insurancePolicyNumber,
    this.insuranceMemberId,
    this.insuranceGroupNumber,
    this.insurancePlanName,
    this.insuranceValidThrough,
    this.insuranceEmergencyPhone,
  });

  factory MedicalPassport.fromJson(Map<String, dynamic> json) =>
      MedicalPassport(
        healthId: json['health_id'] as String,
        version: json['version'] as int,
        fullName: json['full_name'] as String?,
        dateOfBirth: json['date_of_birth'] as String?,
        biologicalSex: json['biological_sex'] as String,
        bloodGroup: json['blood_group'] as String,
        heightCm: _optionalDouble(json['height_cm']),
        weightKg: _optionalDouble(json['weight_kg']),
        preferredLanguage: json['preferred_language'] as String?,
        organDonor: json['organ_donor'] as bool,
        insuranceProvider: json['insurance_provider'] as String?,
        insurancePolicyNumber: json['insurance_policy_number'] as String?,
        insuranceMemberId: json['insurance_member_id'] as String?,
        insuranceGroupNumber: json['insurance_group_number'] as String?,
        insurancePlanName: json['insurance_plan_name'] as String?,
        insuranceValidThrough: json['insurance_valid_through'] as String?,
        insuranceEmergencyPhone: json['insurance_emergency_phone'] as String?,
        allergies: (json['allergies'] as List<dynamic>)
            .map(
              (item) => PassportAllergy.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
        conditions: (json['conditions'] as List<dynamic>)
            .map(
              (item) =>
                  PassportCondition.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
        medications: (json['medications'] as List<dynamic>)
            .map(
              (item) =>
                  PassportMedication.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
        emergencyContacts: (json['emergency_contacts'] as List<dynamic>)
            .map(
              (item) => PassportEmergencyContact.fromJson(
                item as Map<String, dynamic>,
              ),
            )
            .toList(),
        surgeries: (json['surgeries'] as List<dynamic>)
            .map(
              (item) => PassportSurgery.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
        familyHistory: (json['family_history'] as List<dynamic>)
            .map(
              (item) => PassportFamilyHistory.fromJson(
                item as Map<String, dynamic>,
              ),
            )
            .toList(),
      );

  final String healthId;
  final int version;
  final String? fullName;
  final String? dateOfBirth;
  final String biologicalSex;
  final String bloodGroup;
  final double? heightCm;
  final double? weightKg;
  final String? preferredLanguage;
  final bool organDonor;
  final String? insuranceProvider;
  final String? insurancePolicyNumber;
  final String? insuranceMemberId;
  final String? insuranceGroupNumber;
  final String? insurancePlanName;
  final String? insuranceValidThrough;
  final String? insuranceEmergencyPhone;
  final List<PassportAllergy> allergies;
  final List<PassportCondition> conditions;
  final List<PassportMedication> medications;
  final List<PassportEmergencyContact> emergencyContacts;
  final List<PassportSurgery> surgeries;
  final List<PassportFamilyHistory> familyHistory;

  Map<String, dynamic> toUpdateJson() => {
        'version': version,
        'full_name': fullName,
        'date_of_birth': dateOfBirth,
        'biological_sex': biologicalSex,
        'blood_group': bloodGroup,
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'preferred_language': preferredLanguage,
        'organ_donor': organDonor,
        'insurance_provider': insuranceProvider,
        'insurance_policy_number': insurancePolicyNumber,
        'insurance_member_id': insuranceMemberId,
        'insurance_group_number': insuranceGroupNumber,
        'insurance_plan_name': insurancePlanName,
        'insurance_valid_through': insuranceValidThrough,
        'insurance_emergency_phone': insuranceEmergencyPhone,
        'allergies': allergies.map((item) => item.toJson()).toList(),
        'conditions': conditions.map((item) => item.toJson()).toList(),
        'medications': medications.map((item) => item.toJson()).toList(),
        'emergency_contacts':
            emergencyContacts.map((item) => item.toJson()).toList(),
        'surgeries': surgeries.map((item) => item.toJson()).toList(),
        'family_history': familyHistory.map((item) => item.toJson()).toList(),
      };
}

double? _optionalDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  throw FormatException(
    'Expected a numeric value, received ${value.runtimeType}',
  );
}

class PassportAccessGrant {
  const PassportAccessGrant({
    required this.id,
    required this.granteeUserId,
    required this.expiresAt,
    this.revokedAt,
  });

  factory PassportAccessGrant.fromJson(Map<String, dynamic> json) =>
      PassportAccessGrant(
        id: json['id'] as String,
        granteeUserId: json['grantee_user_id'] as String,
        expiresAt: json['expires_at'] as String,
        revokedAt: json['revoked_at'] as String?,
      );

  final String id;
  final String granteeUserId;
  final String expiresAt;
  final String? revokedAt;
}
