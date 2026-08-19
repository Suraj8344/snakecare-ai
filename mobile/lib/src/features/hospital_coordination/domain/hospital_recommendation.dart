class HospitalRecommendationResult {
  HospitalRecommendationResult({required this.items, required this.notice});

  factory HospitalRecommendationResult.fromJson(Map<String, dynamic> json) =>
      HospitalRecommendationResult(
        items: (json['items'] as List<dynamic>)
            .map(
              (value) => HospitalRecommendation.fromJson(
                Map<String, dynamic>.from(value as Map),
              ),
            )
            .toList(),
        notice: json['notice'] as String,
      );

  final List<HospitalRecommendation> items;
  final String notice;
}

class HospitalDirectoryResult {
  HospitalDirectoryResult({
    required this.items,
    required this.total,
    required this.sourceAttribution,
    required this.notice,
  });

  factory HospitalDirectoryResult.fromJson(Map<String, dynamic> json) =>
      HospitalDirectoryResult(
        items: (json['items'] as List<dynamic>)
            .map(
              (value) => HospitalFacility.fromJson(
                Map<String, dynamic>.from(value as Map),
              ),
            )
            .toList(),
        total: json['total'] as int,
        sourceAttribution: json['source_attribution'] as String,
        notice: json['notice'] as String,
      );

  final List<HospitalFacility> items;
  final int total;
  final String sourceAttribution;
  final String notice;
}

class HospitalRecommendation {
  HospitalRecommendation({
    required this.hospital,
    required this.rank,
    required this.distanceKm,
    required this.score,
    required this.scoreComponents,
    required this.reasons,
    required this.warnings,
    required this.rulesetVersion,
  });

  factory HospitalRecommendation.fromJson(Map<String, dynamic> json) =>
      HospitalRecommendation(
        hospital: HospitalFacility.fromJson(
          Map<String, dynamic>.from(json['hospital'] as Map),
        ),
        rank: json['rank'] as int,
        distanceKm: (json['distance_km'] as num).toDouble(),
        score: (json['score'] as num).toDouble(),
        scoreComponents:
            Map<String, dynamic>.from(json['score_components'] as Map)
                .map((key, value) => MapEntry(key, (value as num).toDouble())),
        reasons: List<String>.from(json['reasons'] as List<dynamic>),
        warnings: List<String>.from(json['warnings'] as List<dynamic>),
        rulesetVersion: json['ruleset_version'] as String,
      );

  final HospitalFacility hospital;
  final int rank;
  final double distanceKm;
  final double score;
  final Map<String, double> scoreComponents;
  final List<String> reasons;
  final List<String> warnings;
  final String rulesetVersion;
}

class HospitalFacility {
  HospitalFacility({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.dataSource,
    required this.sourceUpdatedAt,
    required this.capabilities,
    this.managedByUserId,
    this.emergencyPhone,
    this.directionsUrl,
    this.availability,
  });

  factory HospitalFacility.fromJson(Map<String, dynamic> json) =>
      HospitalFacility(
        id: json['id'] as String,
        name: json['name'] as String,
        address: json['address'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        managedByUserId: json['managed_by_user_id'] as String?,
        emergencyPhone: json['emergency_phone'] as String?,
        directionsUrl: json['directions_url'] as String?,
        dataSource: json['data_source'] as String,
        sourceUpdatedAt: DateTime.parse(json['source_updated_at'] as String),
        capabilities: Map<String, dynamic>.from(json['capabilities'] as Map),
        availability: json['availability'] == null
            ? null
            : HospitalAvailability.fromJson(
                Map<String, dynamic>.from(json['availability'] as Map),
              ),
      );

  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String? managedByUserId;
  final String? emergencyPhone;
  final String? directionsUrl;
  final String dataSource;
  final DateTime sourceUpdatedAt;
  final Map<String, dynamic> capabilities;
  final HospitalAvailability? availability;

  String get sourceLabel => switch (dataSource) {
        'hfr_verified' => 'ABDM HFR verified',
        'government_verified' => 'Government verified',
        'hospital_reported' => 'Hospital reported',
        _ => 'Unverified data',
      };

  bool get isConnectedToSnakeCare => managedByUserId != null;
}

class HospitalAvailability {
  HospitalAvailability({
    required this.antivenomStatus,
    required this.dataSource,
    required this.recordedAt,
    required this.expiresAt,
    this.antivenomVials,
    this.emergencyBeds,
    this.icuBeds,
    this.ventilators,
  });

  factory HospitalAvailability.fromJson(Map<String, dynamic> json) =>
      HospitalAvailability(
        antivenomStatus: json['antivenom_status'] as String,
        antivenomVials: json['antivenom_vials'] as int?,
        emergencyBeds: json['emergency_beds'] as int?,
        icuBeds: json['icu_beds'] as int?,
        ventilators: json['ventilators'] as int?,
        dataSource: json['data_source'] as String,
        recordedAt: DateTime.parse(json['recorded_at'] as String),
        expiresAt: DateTime.parse(json['expires_at'] as String),
      );

  final String antivenomStatus;
  final int? antivenomVials;
  final int? emergencyBeds;
  final int? icuBeds;
  final int? ventilators;
  final String dataSource;
  final DateTime recordedAt;
  final DateTime expiresAt;

  bool get isCurrent => expiresAt.isAfter(DateTime.now());
  String get stockLabel => switch (antivenomStatus) {
        'available' => 'Antivenom reported available',
        'low' => 'Low antivenom stock reported',
        'out_of_stock' => 'Reported out of stock',
        _ => 'Antivenom stock unconfirmed',
      };
}
