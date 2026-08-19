import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snakecare_mobile/src/core/localization/app_localizations.dart';
import 'package:snakecare_mobile/src/features/medical_reports/data/medical_report_repository.dart';
import 'package:snakecare_mobile/src/features/medical_reports/domain/medical_report.dart';

const reportCategories = <String>[
  'lab_result',
  'prescription',
  'imaging',
  'discharge_summary',
  'vaccination',
  'insurance',
  'surgery',
  'other',
];

class MedicalReportsScreen extends ConsumerStatefulWidget {
  const MedicalReportsScreen({required this.accessToken, super.key});
  final String accessToken;

  @override
  ConsumerState<MedicalReportsScreen> createState() =>
      _MedicalReportsScreenState();
}

class _MedicalReportsScreenState extends ConsumerState<MedicalReportsScreen> {
  final searchController = TextEditingController();
  String? category;
  String? contentType;
  late Future<MedicalReportPage> reports;

  @override
  void initState() {
    super.initState();
    reports = _load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<MedicalReportPage> _load() =>
      ref.read(medicalReportRepositoryProvider).search(
            widget.accessToken,
            query: searchController.text,
            category: category,
            contentType: contentType,
          );

  void _reload() => setState(() => reports = _load());

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(context.tr('medical_reports'))),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _upload,
          icon: const Icon(Icons.upload_file),
          label: const Text('Upload report'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: TextField(
                controller: searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _reload(),
                decoration: InputDecoration(
                  labelText: 'Search reports and OCR text',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    onPressed: _reload,
                    icon: const Icon(Icons.arrow_forward),
                    tooltip: 'Search',
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All')),
                        ...reportCategories.map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.replaceAll('_', ' ')),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        category = value;
                        _reload();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: contentType,
                      decoration: const InputDecoration(labelText: 'File type'),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('All')),
                        DropdownMenuItem(
                          value: 'application/pdf',
                          child: Text('PDF'),
                        ),
                        DropdownMenuItem(
                          value: 'image/jpeg',
                          child: Text('JPEG'),
                        ),
                        DropdownMenuItem(
                          value: 'image/png',
                          child: Text('PNG'),
                        ),
                      ],
                      onChanged: (value) {
                        contentType = value;
                        _reload();
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<MedicalReportPage>(
                future: reports,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _ReportError(onRetry: _reload);
                  }
                  final page = snapshot.data!;
                  if (page.items.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'No reports found. Upload a PDF or image to build your private timeline.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => _reload(),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                      itemCount: page.items.length,
                      itemBuilder: (context, index) {
                        final report = page.items[index];
                        final showDate = index == 0 ||
                            page.items[index - 1].timelineDate !=
                                report.timelineDate;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showDate)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                                child: Text(
                                  report.timelineDate,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                            _ReportCard(
                              report: report,
                              onTap: () async {
                                await Navigator.of(context).push<void>(
                                  MaterialPageRoute(
                                    builder: (_) => MedicalReportDetailScreen(
                                      accessToken: widget.accessToken,
                                      report: report,
                                    ),
                                  ),
                                );
                                _reload();
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );

  Future<void> _upload() async {
    const reportTypes = XTypeGroup(
      label: 'Medical reports',
      extensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );
    final file = await openFile(acceptedTypeGroups: const [reportTypes]);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    if (bytes.length > 10 * 1024 * 1024) {
      _message('Reports must be 10 MB or smaller.');
      return;
    }
    final draft = await showDialog<_UploadDraft>(
      context: context,
      builder: (_) => _UploadReportDialog(filename: file.name),
    );
    if (draft == null || !mounted) return;
    _message('Uploading and reading the report…');
    try {
      await ref.read(medicalReportRepositoryProvider).upload(
            widget.accessToken,
            filename: file.name,
            bytes: Uint8List.fromList(bytes),
            title: draft.title,
            reportDate: draft.reportDate,
            providerName: draft.providerName,
            notes: draft.notes,
            category: draft.category,
          );
      _reload();
      _message('Medical report uploaded securely.');
    } on DioException catch (error) {
      final data = error.response?.data;
      final detail =
          data is Map<String, dynamic> ? data['detail'] as String? : null;
      _message(detail ?? 'Upload failed. Check the file and try again.');
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.onTap});
  final MedicalReport report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          onTap: onTap,
          leading: Icon(
            report.contentType == 'application/pdf'
                ? Icons.picture_as_pdf
                : Icons.image_outlined,
          ),
          title: Text(report.title),
          subtitle: Text(
            '${report.displayCategory} • ${report.providerName ?? 'Provider not specified'}\n'
            '${report.status == 'ready' ? 'OCR and summary ready' : report.status}',
          ),
          isThreeLine: true,
          trailing: const Icon(Icons.chevron_right),
        ),
      );
}

class MedicalReportDetailScreen extends ConsumerWidget {
  const MedicalReportDetailScreen({
    required this.accessToken,
    required this.report,
    super.key,
  });
  final String accessToken;
  final MedicalReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(
          title: const Text('Report details'),
          actions: [
            IconButton(
              onPressed: () => _delete(context, ref),
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete report',
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              report.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                Chip(label: Text(report.displayCategory)),
                Chip(label: Text(report.timelineDate)),
                Chip(label: Text(report.status)),
              ],
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: Text(report.originalFilename),
              subtitle: Text(
                '${(report.sizeBytes / 1024).toStringAsFixed(1)} KB • ${report.contentType}',
              ),
            ),
            if (report.providerName != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.local_hospital_outlined),
                title: Text(report.providerName!),
                subtitle: const Text('Report provider'),
              ),
            if (report.processingError != null)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(report.processingError!),
                ),
              ),
            _DetailSection(
              title: 'Automated summary',
              icon: Icons.auto_awesome,
              body: report.automatedSummary ?? 'Summary is not available.',
              footer:
                  'AI/automated draft from extracted text. It may be incomplete or incorrect. Verify against the original report with a clinician.',
            ),
            _DetailSection(
              title: 'OCR and extracted text',
              icon: Icons.document_scanner_outlined,
              body: report.extractedText ?? 'No readable text was detected.',
              footer: report.ocrEngine == null
                  ? null
                  : 'Extraction method: ${report.ocrEngine}',
            ),
            if (report.notes != null)
              _DetailSection(
                title: 'Patient notes',
                icon: Icons.notes,
                body: report.notes!,
              ),
          ],
        ),
      );

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this report?'),
        content: const Text(
          'The original file, OCR text, and automated summary will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref
        .read(medicalReportRepositoryProvider)
        .delete(accessToken, report.id);
    if (context.mounted) Navigator.pop(context);
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.icon,
    required this.body,
    this.footer,
  });
  final String title;
  final IconData icon;
  final String body;
  final String? footer;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(top: 16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon),
                  const SizedBox(width: 8),
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 12),
              SelectableText(body),
              if (footer != null) ...[
                const Divider(height: 24),
                Text(footer!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
      );
}

class _UploadReportDialog extends StatefulWidget {
  const _UploadReportDialog({required this.filename});
  final String filename;

  @override
  State<_UploadReportDialog> createState() => _UploadReportDialogState();
}

class _UploadReportDialogState extends State<_UploadReportDialog> {
  late final TextEditingController title;
  final reportDate = TextEditingController();
  final provider = TextEditingController();
  final notes = TextEditingController();
  String? category;

  @override
  void initState() {
    super.initState();
    title = TextEditingController(
      text: widget.filename.replaceFirst(RegExp(r'\.[^.]+$'), ''),
    );
  }

  @override
  void dispose() {
    title.dispose();
    reportDate.dispose();
    provider.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Upload Medical Report'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.filename),
              const SizedBox(height: 12),
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Report title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reportDate,
                decoration: const InputDecoration(
                  labelText: 'Report date (YYYY-MM-DD)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: provider,
                decoration: const InputDecoration(labelText: 'Hospital or lab'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Detect automatically'),
                  ),
                  ...reportCategories.map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value.replaceAll('_', ' ')),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => category = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notes,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: title.text.trim().isEmpty
                ? null
                : () => Navigator.pop(
                      context,
                      _UploadDraft(
                        title: title.text.trim(),
                        reportDate: _optional(reportDate.text),
                        providerName: _optional(provider.text),
                        notes: _optional(notes.text),
                        category: category,
                      ),
                    ),
            child: const Text('Upload securely'),
          ),
        ],
      );

  String? _optional(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}

class _UploadDraft {
  const _UploadDraft({
    required this.title,
    this.reportDate,
    this.providerName,
    this.notes,
    this.category,
  });
  final String title;
  final String? reportDate;
  final String? providerName;
  final String? notes;
  final String? category;
}

class _ReportError extends StatelessWidget {
  const _ReportError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48),
            const SizedBox(height: 12),
            const Text('Unable to load Medical Reports.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
}
