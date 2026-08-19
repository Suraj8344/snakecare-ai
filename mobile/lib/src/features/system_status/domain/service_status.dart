class ServiceStatus {
  const ServiceStatus({
    required this.service,
    required this.status,
    required this.version,
    this.readiness = 'not checked',
    this.checkedAt = '',
    this.apiBaseUrl = '',
    this.readinessDetail,
  });

  factory ServiceStatus.fromJson(Map<String, Object?> json) {
    final Object? service = json['service'];
    final Object? status = json['status'];
    final Object? version = json['version'];
    if (service is! String || status is! String || version is! String) {
      throw const FormatException('Invalid service status response');
    }
    return ServiceStatus(service: service, status: status, version: version);
  }

  final String service;
  final String status;
  final String version;
  final String readiness;
  final String checkedAt;
  final String apiBaseUrl;
  final String? readinessDetail;

  ServiceStatus copyWith({
    String? readiness,
    String? checkedAt,
    String? apiBaseUrl,
    String? readinessDetail,
  }) =>
      ServiceStatus(
        service: service,
        status: status,
        version: version,
        readiness: readiness ?? this.readiness,
        checkedAt: checkedAt ?? this.checkedAt,
        apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
        readinessDetail: readinessDetail ?? this.readinessDetail,
      );
}
