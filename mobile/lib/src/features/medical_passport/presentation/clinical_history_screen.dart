import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snakecare_mobile/src/core/network/api_client.dart';

class ClinicalHistoryScreen extends ConsumerStatefulWidget {
  const ClinicalHistoryScreen({required this.accessToken, super.key});
  final String accessToken;
  @override
  ConsumerState<ClinicalHistoryScreen> createState() => _ClinicalHistoryState();
}

class _ClinicalHistoryState extends ConsumerState<ClinicalHistoryScreen> {
  final healthId = TextEditingController();
  final question = TextEditingController();
  Map<String, dynamic>? record;
  String? error;
  bool busy = false;
  @override
  void dispose() {
    healthId.dispose();
    question.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (busy) return;
    setState(() {
      busy = true;
      record = null;
      error = null;
    });
    try {
      final result = await ref.read(dioProvider).post<Map<String, dynamic>>(
            '/api/v1/clinical-history/${Uri.encodeComponent(healthId.text.trim())}',
            data: {'question': question.text.trim()},
            options: Options(
              headers: {'Authorization': 'Bearer ${widget.accessToken}'},
            ),
          );
      if (mounted) setState(() => record = result.data);
    } on DioException catch (e) {
      if (mounted) {
        setState(
          () => error = e.response?.statusCode == 403
              ? 'Access denied. The patient must grant your doctor account access in Medical Passport. Check the Health ID and grant expiry.'
              : 'Could not load history. Check the Health ID, connection and service availability.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Patient history for doctors')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Authorized record summary',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'The patient must first grant access to your doctor email in Medical Passport. Enter the Health ID from their QR card. Access is checked again for every request.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: healthId,
                  enabled: !busy,
                  decoration:
                      const InputDecoration(labelText: 'Patient Health ID'),
                  onChanged: (_) => setState(() {
                    record = null;
                    error = null;
                  }),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: question,
                  enabled: !busy,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'History topic (optional)',
                    hintText:
                        'Allergies, medications, surgery, family history...',
                  ),
                ),
                const Text(
                  'This first version retrieves recorded sections, not AI answers. Cloud AI is not enabled. It cannot answer treatment, interaction or diagnostic questions.',
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: busy ? null : load,
                  icon: const Icon(Icons.history),
                  label: Text(busy ? 'Loading...' : 'Load authorized summary'),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child:
                        Text(error!, style: const TextStyle(color: Colors.red)),
                  ),
                if (record != null) ...[
                  const Divider(height: 28),
                  Text(
                    '${record!['patient_name'] ?? 'Name not recorded'}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    'Health ID: ${record!['health_id']}\nUpdated: ${record!['updated_at']} | Version ${record!['version']}',
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('${record!['notice']}'),
                  ),
                  for (final raw in (record!['sections'] as List<dynamic>)
                      .cast<Map<String, dynamic>>())
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${raw['title']}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text('Source: ${raw['source']}'),
                            const SizedBox(height: 8),
                            SelectableText('${raw['text']}'),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      );
}
