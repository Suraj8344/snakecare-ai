class MedicalReport {
  const MedicalReport({
    required this.id,
    required this.title,
    required this.category,
    required this.originalFilename,
    required this.contentType,
    required this.sizeBytes,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.reportDate,
    this.providerName,
    this.notes,
    this.extractedText,
    this.ocrEngine,
    this.ocrConfidence,
    this.automatedSummary,
    this.summaryMethod,
    this.summaryGeneratedAt,
    this.processingError,
  });

  factory MedicalReport.fromJson(Map<String, dynamic> json) => MedicalReport(
        id: json['id'] as String,
        title: json['title'] as String,
        category: json['category'] as String,
        reportDate: json['report_date'] as String?,
        providerName: json['provider_name'] as String?,
        notes: json['notes'] as String?,
        originalFilename: json['original_filename'] as String,
        contentType: json['content_type'] as String,
        sizeBytes: json['size_bytes'] as int,
        status: json['status'] as String,
        extractedText: json['extracted_text'] as String?,
        ocrEngine: json['ocr_engine'] as String?,
        ocrConfidence: json['ocr_confidence'] as String?,
        automatedSummary: json['automated_summary'] as String?,
        summaryMethod: json['summary_method'] as String?,
        summaryGeneratedAt: json['summary_generated_at'] as String?,
        processingError: json['processing_error'] as String?,
        createdAt: json['created_at'] as String,
        updatedAt: json['updated_at'] as String,
      );

  final String id;
  final String title;
  final String category;
  final String? reportDate;
  final String? providerName;
  final String? notes;
  final String originalFilename;
  final String contentType;
  final int sizeBytes;
  final String status;
  final String? extractedText;
  final String? ocrEngine;
  final String? ocrConfidence;
  final String? automatedSummary;
  final String? summaryMethod;
  final String? summaryGeneratedAt;
  final String? processingError;
  final String createdAt;
  final String updatedAt;

  String get displayCategory => category.replaceAll('_', ' ');
  String get timelineDate => reportDate ?? createdAt.substring(0, 10);
}

class MedicalReportPage {
  const MedicalReportPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  factory MedicalReportPage.fromJson(Map<String, dynamic> json) =>
      MedicalReportPage(
        items: (json['items'] as List<dynamic>)
            .map(
              (item) => MedicalReport.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
        total: json['total'] as int,
        page: json['page'] as int,
        pageSize: json['page_size'] as int,
      );

  final List<MedicalReport> items;
  final int total;
  final int page;
  final int pageSize;
}
