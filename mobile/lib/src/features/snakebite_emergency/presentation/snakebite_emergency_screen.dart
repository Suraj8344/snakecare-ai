import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:snakecare_mobile/src/core/localization/app_localizations.dart';
import 'package:snakecare_mobile/src/features/emergency_handoff/presentation/emergency_handoff_screen.dart';
import 'package:snakecare_mobile/src/features/hospital_coordination/presentation/hospital_recommendation_screen.dart';
import 'package:snakecare_mobile/src/features/snakebite_emergency/data/snakebite_emergency_repository.dart';
import 'package:snakecare_mobile/src/features/snakebite_emergency/domain/snakebite_assessment.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

const offlineFirstAidSteps = <String>[
  'Move away from the snake. Do not try to catch or kill it.',
  'Remove rings, anklets, shoes, and other tight items.',
  'Keep the person completely still and support the bitten limb with a splint.',
  'Carry the person and arrange transport to a health facility immediately.',
  'If vomiting or very drowsy, place the person on their side and monitor breathing.',
];

const offlineActionsToAvoid = <String>[
  'No tight tourniquet or tight band.',
  'Do not cut, burn, wash aggressively, or suck the wound.',
  'Do not apply ice, chemicals, electric shock, herbs, or black stones.',
  'Do not delay transport for home or traditional treatments.',
];

class SnakebiteEmergencyScreen extends ConsumerStatefulWidget {
  const SnakebiteEmergencyScreen({
    required this.accessToken,
    super.key,
    this.showVideo = true,
  });

  final String accessToken;
  final bool showVideo;

  @override
  ConsumerState<SnakebiteEmergencyScreen> createState() =>
      _SnakebiteEmergencyScreenState();
}

class _SnakebiteEmergencyScreenState
    extends ConsumerState<SnakebiteEmergencyScreen> {
  static const _firstAidVideoId = 'q9rsEiQxSn8';
  final selectedSymptoms = <String>{};
  final age = TextEditingController();
  final notes = TextEditingController();
  final voiceTranscript = TextEditingController();
  final pulse = TextEditingController();
  final breathingRate = TextEditingController();
  final oxygen = TextEditingController();
  final systolic = TextEditingController();
  final diastolic = TextEditingController();
  final temperature = TextEditingController();
  final speech = SpeechToText();
  final scrollController = ScrollController();
  final symptomsKey = GlobalKey();
  YoutubePlayerController? videoController;

  String biteSite = 'unknown';
  String consciousness = 'alert';
  bool listening = false;
  bool submitting = false;
  Uint8List? photoBytes;
  String? photoFilename;
  Position? position;

  @override
  void initState() {
    super.initState();
    if (widget.showVideo) {
      videoController = YoutubePlayerController.fromVideoId(
        videoId: _firstAidVideoId,
        autoPlay: false,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          enableCaption: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    speech.stop();
    scrollController.dispose();
    videoController?.close();
    for (final controller in [
      age,
      notes,
      voiceTranscript,
      pulse,
      breathingRate,
      oxygen,
      systolic,
      diastolic,
      temperature,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(context.tr('snakebite_emergency')),
          actions: const [LanguageMenu()],
        ),
        body: Scrollbar(
          controller: scrollController,
          thumbVisibility: true,
          interactive: true,
          child: ListView(
            controller: scrollController,
            key: const Key('snakebite_form_scroll'),
            padding: const EdgeInsets.fromLTRB(16, 16, 24, 32),
            children: [
            _EmergencyBanner(onCall: _callEmergencyServices),
            const SizedBox(height: 16),
            const _FirstAidCard(),
            const SizedBox(height: 16),
            if (videoController != null)
              _EmergencyVideoCard(
                controller: videoController!,
                onContinue: _scrollToSymptoms,
              ),
            const SizedBox(height: 20),
            KeyedSubtree(
              key: symptomsKey,
              child: _Section(
                title: '1. ${context.tr('symptoms_now')}',
                subtitle: context.tr('select_symptoms'),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: symptomLabels.entries
                      .map(
                        (entry) => FilterChip(
                          label: Text(entry.value),
                          selected: selectedSymptoms.contains(entry.key),
                          onSelected: (selected) =>
                              _changeSymptom(entry.key, selected),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            _Section(
              title: '2. Describe what happened',
              subtitle:
                  'Voice uses your device speech service. Review it before sending; SnakeCare sends only the transcript.',
              child: Column(
                children: [
                  TextField(
                    controller: voiceTranscript,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Voice transcript or typed description',
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _toggleVoice,
                    icon: Icon(listening ? Icons.stop : Icons.mic_none),
                    label: Text(
                      listening ? 'Stop listening' : 'Start voice input',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notes,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Other symptoms or circumstances',
                    ),
                  ),
                ],
              ),
            ),
            _Section(
              title: '3. Bite details and photo',
              subtitle:
                  'A photo is optional and will not be used to identify a snake.',
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: biteSite,
                    decoration: const InputDecoration(
                      labelText: 'Bite location on body',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'unknown',
                        child: Text('Unknown'),
                      ),
                      DropdownMenuItem(value: 'hand', child: Text('Hand')),
                      DropdownMenuItem(value: 'arm', child: Text('Arm')),
                      DropdownMenuItem(value: 'foot', child: Text('Foot')),
                      DropdownMenuItem(value: 'leg', child: Text('Leg')),
                      DropdownMenuItem(
                        value: 'head_or_neck',
                        child: Text('Head or neck'),
                      ),
                      DropdownMenuItem(value: 'torso', child: Text('Torso')),
                    ],
                    onChanged: (value) => biteSite = value ?? 'unknown',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: age,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Patient age (optional)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (photoBytes != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        photoBytes!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(photoFilename ?? 'Selected photo'),
                  ],
                  OutlinedButton.icon(
                    onPressed: _pickPhoto,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: Text(
                      photoBytes == null ? 'Upload photo' : 'Change photo',
                    ),
                  ),
                ],
              ),
            ),
            _Section(
              title: '4. Current location',
              subtitle:
                  'Optional. Used only with this private emergency record.',
              child: Column(
                children: [
                  if (position != null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.location_on_outlined),
                      title: const Text('Location captured'),
                      subtitle: Text(
                        '${position!.latitude.toStringAsFixed(5)}, '
                        '${position!.longitude.toStringAsFixed(5)} '
                        '(±${position!.accuracy.toStringAsFixed(0)} m)',
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: _captureLocation,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Use current location'),
                  ),
                ],
              ),
            ),
            _Section(
              title: '5. Vitals (optional)',
              subtitle:
                  'Enter measured values only. Leave unknown values blank.',
              child: Column(
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _VitalField(controller: pulse, label: 'Pulse / min'),
                      _VitalField(
                        controller: breathingRate,
                        label: 'Breaths / min',
                      ),
                      _VitalField(controller: oxygen, label: 'Oxygen %'),
                      _VitalField(controller: systolic, label: 'Systolic BP'),
                      _VitalField(controller: diastolic, label: 'Diastolic BP'),
                      _VitalField(
                        controller: temperature,
                        label: 'Temperature °C',
                        decimal: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: consciousness,
                    decoration:
                        const InputDecoration(labelText: 'Responsiveness'),
                    items: const [
                      DropdownMenuItem(value: 'alert', child: Text('Alert')),
                      DropdownMenuItem(
                        value: 'responds_to_voice',
                        child: Text('Responds to voice'),
                      ),
                      DropdownMenuItem(
                        value: 'responds_to_pain',
                        child: Text('Responds only to pain'),
                      ),
                      DropdownMenuItem(
                        value: 'unresponsive',
                        child: Text('Unresponsive'),
                      ),
                    ],
                    onChanged: (value) => consciousness = value ?? 'alert',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
                minimumSize: const Size.fromHeight(54),
              ),
              icon: submitting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.health_and_safety_outlined),
              label: Text(
                submitting ? 'Assessing emergency…' : context.tr('assess_save'),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This decision support cannot diagnose envenoming or determine whether a bite is safe.',
              textAlign: TextAlign.center,
            ),
            ],
          ),
        ),
      );

  Future<void> _scrollToSymptoms() async {
    final target = symptomsKey.currentContext;
    if (target == null) return;
    await Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  void _changeSymptom(String symptom, bool selected) {
    setState(() {
      if (selected) {
        if (symptom == 'none_observed') {
          selectedSymptoms
            ..clear()
            ..add(symptom);
        } else {
          selectedSymptoms
            ..remove('none_observed')
            ..add(symptom);
        }
      } else {
        selectedSymptoms.remove(symptom);
      }
    });
  }

  Future<void> _toggleVoice() async {
    if (listening) {
      await speech.stop();
      if (mounted) setState(() => listening = false);
      return;
    }
    final available = await speech.initialize(
      onStatus: (status) {
        if (mounted && status == 'done') setState(() => listening = false);
      },
      onError: (_) {
        if (mounted) setState(() => listening = false);
      },
    );
    if (!available || !mounted) {
      _message(
        'Voice input is unavailable. You can type the description instead.',
      );
      return;
    }
    setState(() => listening = true);
    await speech.listen(
      onResult: (result) {
        voiceTranscript.text = result.recognizedWords;
        voiceTranscript.selection = TextSelection.collapsed(
          offset: voiceTranscript.text.length,
        );
      },
    );
  }

  Future<void> _pickPhoto() async {
    const images = XTypeGroup(
      label: 'Snakebite photo',
      extensions: ['png', 'jpg', 'jpeg'],
    );
    final file = await openFile(acceptedTypeGroups: const [images]);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    if (bytes.length > 8 * 1024 * 1024) {
      _message('The photo must be 8 MB or smaller.');
      return;
    }
    setState(() {
      photoBytes = bytes;
      photoFilename = file.name;
    });
  }

  Future<void> _captureLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _message('Turn on location services, then try again.');
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _message(
        'Location permission was not granted. You can continue without it.',
      );
      return;
    }
    final captured = await Geolocator.getCurrentPosition();
    if (mounted) setState(() => position = captured);
  }

  Future<void> _callEmergencyServices() async {
    final launched = await launchUrl(Uri(scheme: 'tel', path: '112'));
    if (!launched && mounted) {
      _message('Call your local emergency number now. In India, dial 112.');
    }
  }

  Future<void> _submit() async {
    if (selectedSymptoms.isEmpty) {
      _message('Select observed symptoms or “No listed symptom observed”.');
      return;
    }
    setState(() => submitting = true);
    final payload = <String, dynamic>{
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
      'patient_age_years': _integer(age.text),
      'bite_site': biteSite,
      'symptoms': selectedSymptoms.toList(),
      if (notes.text.trim().isNotEmpty) 'symptom_notes': notes.text.trim(),
      if (voiceTranscript.text.trim().isNotEmpty)
        'voice_transcript': voiceTranscript.text.trim(),
      if (position != null) ...{
        'latitude': position!.latitude,
        'longitude': position!.longitude,
        'location_accuracy_m': position!.accuracy,
      },
      'vitals': {
        'pulse_bpm': _integer(pulse.text),
        'respiratory_rate': _integer(breathingRate.text),
        'oxygen_saturation': _integer(oxygen.text),
        'systolic_bp': _integer(systolic.text),
        'diastolic_bp': _integer(diastolic.text),
        'temperature_c': _decimal(temperature.text),
        'consciousness': consciousness,
      },
    };
    try {
      final result =
          await ref.read(snakebiteEmergencyRepositoryProvider).assess(
                widget.accessToken,
                payload: payload,
                photoBytes: photoBytes,
                photoFilename: photoFilename,
              );
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => SnakebiteAssessmentScreen(
            assessment: result,
            accessToken: widget.accessToken,
          ),
        ),
      );
    } on DioException catch (error) {
      if (mounted) _message(_apiMessage(error));
    } catch (_) {
      if (mounted) {
        _message('The assessment could not be saved. Seek emergency care now.');
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  int? _integer(String value) => int.tryParse(value.trim());
  double? _decimal(String value) => double.tryParse(value.trim());

  String _apiMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['detail'] is String) {
      return data['detail'] as String;
    }
    return 'Unable to save the assessment. Seek emergency care without delay.';
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class SnakebiteAssessmentScreen extends StatelessWidget {
  const SnakebiteAssessmentScreen({
    required this.assessment,
    required this.accessToken,
    super.key,
  });

  final SnakebiteAssessment assessment;
  final String accessToken;

  @override
  Widget build(BuildContext context) {
    final critical = assessment.urgency == 'critical';
    final color = critical
        ? Theme.of(context).colorScheme.error
        : assessment.urgency == 'high_risk'
            ? Colors.deepOrange
            : Colors.amber.shade800;
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency assessment')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            color: color.withValues(alpha: 0.12),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 56, color: color),
                  const SizedBox(height: 10),
                  Text(
                    assessment.displayUrgency,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    assessment.assessmentNotice,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          _ResultSection(
            title: 'Why this result',
            items: assessment.explanation,
          ),
          _ResultSection(
            title: 'Do this now',
            items: assessment.immediateActions,
            icon: Icons.emergency,
          ),
          _ResultSection(title: 'First aid', items: assessment.firstAidSteps),
          _ResultSection(
            title: 'Do not do these things',
            items: assessment.actionsToAvoid,
            icon: Icons.block,
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.emergency_share_outlined),
              title: const Text('Emergency ID'),
              subtitle: SelectableText(assessment.id),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => EmergencyHandoffScreen(
                  accessToken: accessToken,
                  emergencyId: assessment.id,
                ),
              ),
            ),
            icon: const Icon(Icons.support_agent_outlined),
            label: const Text('Prepare 112 handoff (simulation)'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => HospitalRecommendationScreen(
                  accessToken: accessToken,
                  emergencyId: assessment.id,
                  latitude: assessment.latitude,
                  longitude: assessment.longitude,
                ),
              ),
            ),
            icon: const Icon(Icons.local_hospital_outlined),
            label: const Text('Find prepared hospitals'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => launchUrl(Uri(scheme: 'tel', path: '112')),
            icon: const Icon(Icons.call),
            label: const Text('Call 112 emergency services'),
          ),
          const SizedBox(height: 12),
          Text(
            'Rules: ${assessment.rulesetVersion} • Guidance: ${assessment.guidanceVersion}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _EmergencyBanner extends StatelessWidget {
  const _EmergencyBanner({required this.onCall});
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr('do_not_wait'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onCall,
                icon: const Icon(Icons.call),
                label: Text(context.tr('call_112_now')),
              ),
            ],
          ),
        ),
      );
}

class _FirstAidCard extends StatelessWidget {
  const _FirstAidCard();

  @override
  Widget build(BuildContext context) => Card(
        child: ExpansionTile(
          initiallyExpanded: true,
          leading: const Icon(Icons.health_and_safety_outlined),
          title: Text(context.tr('first_aid')),
          subtitle: Text(context.tr('first_aid_available')),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            ...[
              'move_away',
              'remove_tight',
              'keep_still',
              'carry_hospital',
              'recovery_position',
            ].map((key) => _Bullet(text: context.tr(key))),
            const Divider(),
            ...['no_tourniquet', 'no_cut', 'no_ice', 'no_delay'].map(
              (key) => _Bullet(
                text: context.tr(key),
                icon: Icons.close,
                color: Colors.red,
              ),
            ),
          ],
        ),
      );
}

class _EmergencyVideoCard extends StatelessWidget {
  const _EmergencyVideoCard({
    required this.controller,
    required this.onContinue,
  });
  final YoutubePlayerController controller;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr('video_title'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: YoutubePlayer(controller: controller),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'First-aid education video. Call emergency services immediately; video guidance does not replace medical care.',
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: onContinue,
                icon: const Icon(Icons.keyboard_arrow_down),
                label: Text(context.tr('continue_symptoms')),
              ),
            ],
          ),
        ),
      );
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(subtitle),
                const SizedBox(height: 16),
                child,
              ],
            ),
          ),
        ),
      );
}

class _VitalField extends StatelessWidget {
  const _VitalField({
    required this.controller,
    required this.label,
    this.decimal = false,
  });
  final TextEditingController controller;
  final String label;
  final bool decimal;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 170,
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          decoration: InputDecoration(labelText: label),
        ),
      );
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({
    required this.title,
    required this.items,
    this.icon = Icons.check_circle_outline,
  });
  final String title;
  final List<String> items;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              ...items.map((text) => _Bullet(text: text, icon: icon)),
            ],
          ),
        ),
      );
}

class _Bullet extends StatelessWidget {
  const _Bullet({
    required this.text,
    this.icon = Icons.check,
    this.color,
  });
  final String text;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      );
}
