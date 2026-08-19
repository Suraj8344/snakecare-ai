import 'package:snakecare_mobile/src/features/hospital_coordination/domain/hospital_recommendation.dart';

class HospitalClaim {
  const HospitalClaim({
    required this.id,
    required this.facilityId,
    required this.status,
    required this.verificationMethod,
    required this.evidenceReference,
    required this.facilityName,
    this.requesterEmail,
    this.reviewNote,
  });

  factory HospitalClaim.fromJson(Map<String, dynamic> json) => HospitalClaim(
        id: json['id'] as String,
        facilityId: json['facility_id'] as String,
        status: json['status'] as String,
        verificationMethod: json['verification_method'] as String,
        evidenceReference: json['evidence_reference'] as String,
        facilityName: json['facility_name'] as String,
        requesterEmail: json['requester_email'] as String?,
        reviewNote: json['review_note'] as String?,
      );

  final String id;
  final String facilityId;
  final String status;
  final String verificationMethod;
  final String evidenceReference;
  final String facilityName;
  final String? requesterEmail;
  final String? reviewNote;
}

class AntivenomBoxRecord {
  const AntivenomBoxRecord({
    required this.id,
    required this.boxSerial,
    required this.productName,
    required this.manufacturer,
    required this.batchNumber,
    required this.expiryDate,
    required this.initialVials,
    required this.availableVials,
    required this.status,
    this.qrToken,
    this.qrNotice,
  });

  factory AntivenomBoxRecord.fromJson(Map<String, dynamic> json) =>
      AntivenomBoxRecord(
        id: json['id'] as String,
        boxSerial: json['box_serial'] as String,
        productName: json['product_name'] as String,
        manufacturer: json['manufacturer'] as String,
        batchNumber: json['batch_number'] as String,
        expiryDate: DateTime.parse(json['expiry_date'] as String),
        initialVials: json['initial_vials'] as int,
        availableVials: json['available_vials'] as int,
        status: json['status'] as String,
        qrToken: json['qr_token'] as String?,
        qrNotice: json['qr_notice'] as String?,
      );

  final String id;
  final String boxSerial;
  final String productName;
  final String manufacturer;
  final String batchNumber;
  final DateTime expiryDate;
  final int initialVials;
  final int availableVials;
  final String status;
  final String? qrToken;
  final String? qrNotice;
}

class DepletionRequestRecord {
  const DepletionRequestRecord({
    required this.id,
    required this.boxId,
    required this.requestedUsedVials,
    required this.status,
  });

  factory DepletionRequestRecord.fromJson(Map<String, dynamic> json) =>
      DepletionRequestRecord(
        id: json['id'] as String,
        boxId: json['box_id'] as String,
        requestedUsedVials: json['requested_used_vials'] as int,
        status: json['status'] as String,
      );

  final String id;
  final String boxId;
  final int requestedUsedVials;
  final String status;
}

class HospitalInboxItem {
  const HospitalInboxItem({
    required this.id,
    required this.status,
    required this.expiresAt,
    required this.summary,
    this.emergencyId,
    this.latitude,
    this.longitude,
  });

  factory HospitalInboxItem.preAlert(Map<String, dynamic> json) =>
      HospitalInboxItem(
        id: json['id'] as String,
        status: json['status'] as String,
        expiresAt: DateTime.parse(json['expires_at'] as String),
        emergencyId: json['emergency_id'] as String,
        latitude: (((json['shared_payload'] as Map)['location']
                as Map?)?['latitude'] as num?)
            ?.toDouble(),
        longitude: (((json['shared_payload'] as Map)['location']
                as Map?)?['longitude'] as num?)
            ?.toDouble(),
        summary: Map<String, dynamic>.from(json['shared_payload'] as Map)
            .entries
            .map((entry) => '${entry.key}: ${entry.value}')
            .join('\n'),
      );

  factory HospitalInboxItem.resource(Map<String, dynamic> json) =>
      HospitalInboxItem(
        id: json['id'] as String,
        status: json['status'] as String,
        expiresAt: DateTime.parse(json['expires_at'] as String),
        summary: [
          if (json['antivenom_readiness'] == true) 'Antivenom readiness',
          if (json['emergency_bed'] == true) 'Emergency bed',
          if (json['icu_readiness'] == true) 'ICU readiness',
          if (json['ventilator_readiness'] == true) 'Ventilator readiness',
        ].join(', '),
      );

  final String id;
  final String status;
  final DateTime expiresAt;
  final String summary;
  final String? emergencyId;
  final double? latitude;
  final double? longitude;
}

class HospitalDashboardData {
  const HospitalDashboardData({
    required this.facility,
    required this.preAlerts,
    required this.resourceRequests,
    required this.boxes,
    required this.depletionRequests,
  });

  factory HospitalDashboardData.fromJson(Map<String, dynamic> json) =>
      HospitalDashboardData(
        facility: HospitalFacility.fromJson(
          Map<String, dynamic>.from(json['facility'] as Map),
        ),
        preAlerts: (json['pre_alerts'] as List<dynamic>)
            .map(
              (value) => HospitalInboxItem.preAlert(
                Map<String, dynamic>.from(value as Map),
              ),
            )
            .toList(),
        resourceRequests: (json['resource_requests'] as List<dynamic>)
            .map(
              (value) => HospitalInboxItem.resource(
                Map<String, dynamic>.from(value as Map),
              ),
            )
            .toList(),
        boxes: (json['boxes'] as List<dynamic>)
            .map(
              (value) => AntivenomBoxRecord.fromJson(
                Map<String, dynamic>.from(value as Map),
              ),
            )
            .toList(),
        depletionRequests: (json['depletion_requests'] as List<dynamic>)
            .map(
              (value) => DepletionRequestRecord.fromJson(
                Map<String, dynamic>.from(value as Map),
              ),
            )
            .toList(),
      );

  final HospitalFacility facility;
  final List<HospitalInboxItem> preAlerts;
  final List<HospitalInboxItem> resourceRequests;
  final List<AntivenomBoxRecord> boxes;
  final List<DepletionRequestRecord> depletionRequests;
}
