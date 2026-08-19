import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snakecare_mobile/src/features/medical_reports/data/medical_report_repository.dart';
import 'package:snakecare_mobile/src/features/medical_reports/domain/medical_report.dart';
import 'package:snakecare_mobile/src/features/medical_reports/presentation/medical_reports_screen.dart';

Map<String, dynamic> reportJson() => {
      'id': '11111111-2222-3333-4444-555555555555',
      'title': 'Annual blood work',
      'category': 'lab_result',
      'report_date': '2026-08-01',
      'provider_name': 'Example Diagnostics',
      'notes': 'Annual checkup',
      'original_filename': 'blood-work.pdf',
      'content_type': 'application/pdf',
      'size_bytes': 2048,
      'sha256': 'a' * 64,
      'status': 'ready',
      'extracted_text': 'Hemoglobin 13.5 g/dL.',
      'ocr_engine': 'pymupdf-embedded-text',
      'ocr_confidence': 'unscored',
      'automated_summary': 'Laboratory blood test result.',
      'summary_method': 'local-extractive-v1',
      'summary_generated_at': '2026-08-06T12:00:00Z',
      'processing_error': null,
      'created_at': '2026-08-06T12:00:00Z',
      'updated_at': '2026-08-06T12:00:00Z',
    };

class FakeMedicalReportRepository extends MedicalReportRepository {
  FakeMedicalReportRepository(this.report) : super(Dio());
  final MedicalReport report;

  @override
  Future<MedicalReportPage> search(
    String token, {
    String? query,
    String? category,
    String? contentType,
  }) async =>
      MedicalReportPage(items: [report], total: 1, page: 1, pageSize: 100);
}

void main() {
  test('parses OCR, categorization, timeline, and automated summary data', () {
    final report = MedicalReport.fromJson(reportJson());
    expect(report.displayCategory, 'lab result');
    expect(report.timelineDate, '2026-08-01');
    expect(report.extractedText, contains('Hemoglobin'));
    expect(report.automatedSummary, isNotEmpty);
  });

  testWidgets('shows report search, filters, and timeline card',
      (tester) async {
    final report = MedicalReport.fromJson(reportJson());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          medicalReportRepositoryProvider.overrideWithValue(
            FakeMedicalReportRepository(report),
          ),
        ],
        child: const MaterialApp(
          home: MedicalReportsScreen(accessToken: 'test-token'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Medical Reports'), findsOneWidget);
    expect(find.text('Search reports and OCR text'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('File type'), findsOneWidget);
    expect(find.text('2026-08-01'), findsOneWidget);
    expect(find.text('Annual blood work'), findsOneWidget);
    expect(find.text('Upload report'), findsOneWidget);

    final searchBottom = tester.getBottomLeft(find.byType(TextField).first).dy;
    final firstFilter = find
        .byWidgetPredicate(
          (widget) => widget is DropdownButtonFormField<String?>,
        )
        .first;
    final filterTop = tester.getTopLeft(firstFilter).dy;
    expect(filterTop - searchBottom, greaterThanOrEqualTo(16));
  });

  testWidgets('labels automated summary and OCR provenance', (tester) async {
    final report = MedicalReport.fromJson(reportJson());
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: MedicalReportDetailScreen(
            accessToken: 'test-token',
            report: report,
          ),
        ),
      ),
    );

    expect(find.text('Automated summary'), findsOneWidget);
    expect(
      find.textContaining('may be incomplete or incorrect'),
      findsOneWidget,
    );
    expect(find.text('OCR and extracted text'), findsOneWidget);
    expect(find.textContaining('pymupdf-embedded-text'), findsOneWidget);
  });
}
