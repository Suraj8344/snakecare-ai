import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:snakecare_mobile/src/core/audio/wav_audio_player.dart';
import 'package:snakecare_mobile/src/features/emergency_handoff/data/emergency_handoff_repository.dart';
import 'package:snakecare_mobile/src/features/emergency_handoff/domain/emergency_handoff.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:url_launcher/url_launcher.dart';

String? selectPreferredSpeechLanguage(Iterable<Object?> languages) {
  final available = languages
      .whereType<String>()
      .where((language) => language.trim().isNotEmpty)
      .toList(growable: false);
  if (available.isEmpty) return null;

  for (final preferred in const ['en-IN', 'en-US', 'en-GB']) {
    for (final language in available) {
      if (language.toLowerCase() == preferred.toLowerCase()) return language;
    }
  }
  for (final language in available) {
    if (language.toLowerCase().startsWith('en')) return language;
  }
  return null;
}

class EmergencyHandoffScreen extends ConsumerStatefulWidget {
  const EmergencyHandoffScreen({
    required this.accessToken,
    super.key,
    this.emergencyId,
  });

  final String accessToken;
  final String? emergencyId;

  @override
  ConsumerState<EmergencyHandoffScreen> createState() =>
      _EmergencyHandoffScreenState();
}

class _EmergencyHandoffScreenState
    extends ConsumerState<EmergencyHandoffScreen> {
  late final TextEditingController emergencyId =
      TextEditingController(text: widget.emergencyId);
  final callerQuestion = TextEditingController();
  final speech = SpeechToText();
  final tts = FlutterTts();
  final consents = <String, bool>{
    'Share verified identity and callback': false,
    'Share emergency location': false,
    'Share symptoms, vitals, and reported consciousness': false,
    'Share Medical Passport summary': false,
    'Send a temporary caller-question transcript to Google Gemini for intent classification':
        false,
  };
  EmergencyHandoff? handoff;
  SimulatedOperatorAnswer? answer;
  VoiceAssistantAnswer? voiceAnswer;
  String selectedQuestion = operatorQuestions.keys.first;
  String? error;
  bool busy = false;
  bool listening = false;
  bool speaking = false;
  bool speechOutputReady = false;
  int? secondsRemaining;
  Timer? timer;

  bool get allConsented => consents.values.every((value) => value);

  @override
  void initState() {
    super.initState();
    tts.setStartHandler(() {
      if (mounted) setState(() => speaking = true);
    });
    tts.setCompletionHandler(() {
      if (mounted) setState(() => speaking = false);
    });
    tts.setCancelHandler(() {
      if (mounted) setState(() => speaking = false);
    });
    tts.setErrorHandler((_) {
      if (!mounted) return;
      setState(() {
        speaking = false;
        error = kIsWeb
            ? 'Chrome could not play the answer. Check that this tab and Windows are not muted, then press Play spoken answer again.'
            : 'Spoken output is unavailable on this device. The verified answer is shown as text.';
      });
    });
    unawaited(_configureSpeechOutput());
  }

  @override
  void dispose() {
    timer?.cancel();
    unawaited(speech.stop());
    unawaited(tts.stop());
    emergencyId.dispose();
    callerQuestion.dispose();
    super.dispose();
  }

  Future<void> prepare() async {
    if (!allConsented || emergencyId.text.trim().isEmpty) return;
    await _run(() async {
      handoff = await ref.read(emergencyHandoffRepositoryProvider).create(
            widget.accessToken,
            emergencyId: emergencyId.text.trim(),
          );
    });
  }

  Future<void> startCountdown() async {
    if (busy) return;
    final current = handoff;
    if (current == null) return;
    await _run(() async {
      final repository = ref.read(emergencyHandoffRepositoryProvider);
      try {
        handoff = await repository.action(
          widget.accessToken,
          current.id,
          'countdown',
        );
      } on DioException {
        // The first request may have succeeded while its response was lost, or
        // another action may have updated the workflow. Reconcile all failed
        // responses (including a browser-masked 500/CORS failure) before
        // deciding that the countdown actually failed.
        await Future<void>.delayed(const Duration(milliseconds: 250));
        try {
          handoff = await repository.get(widget.accessToken, current.id);
        } on DioException {
          rethrow;
        }
        if (handoff!.status != 'countdown_active' &&
            handoff!.status != 'simulation_active') {
          rethrow;
        }
      }
      if (handoff!.status == 'simulation_active') return;
      secondsRemaining = handoff!.countdownSeconds;
      timer?.cancel();
      timer = Timer.periodic(const Duration(seconds: 1), (ticker) {
        if (!mounted) return;
        final next = (secondsRemaining ?? 1) - 1;
        setState(() => secondsRemaining = next);
        if (next <= 0) {
          ticker.cancel();
          unawaited(recordNoResponse());
        }
      });
    });
  }

  Future<void> recordNoResponse() async {
    final current = handoff;
    if (current == null || current.status != 'countdown_active') return;
    await _run(() async {
      final repository = ref.read(emergencyHandoffRepositoryProvider);
      try {
        handoff = await repository.action(
          widget.accessToken,
          current.id,
          'no-response',
        );
      } on DioException {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        try {
          handoff = await repository.get(widget.accessToken, current.id);
        } on DioException {
          rethrow;
        }
        if (handoff!.status != 'simulation_active') rethrow;
      }
    });
  }

  Future<void> cancel() async {
    final current = handoff;
    if (current == null) return;
    timer?.cancel();
    await _run(() async {
      handoff = await ref.read(emergencyHandoffRepositoryProvider).action(
            widget.accessToken,
            current.id,
            'cancel',
          );
      secondsRemaining = null;
    });
  }

  Future<void> askQuestion() async {
    final current = handoff;
    if (current == null) return;
    timer?.cancel();
    await _run(() async {
      answer = await ref.read(emergencyHandoffRepositoryProvider).simulate(
            widget.accessToken,
            current.id,
            selectedQuestion,
          );
    });
  }

  Future<void> toggleListening() async {
    if (listening) {
      await speech.stop();
      if (mounted) setState(() => listening = false);
      return;
    }
    final available = await speech.initialize(
      onStatus: (status) {
        if (mounted && (status == 'done' || status == 'notListening')) {
          setState(() => listening = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => listening = false);
      },
    );
    if (!available || !mounted) {
      setState(() {
        error =
            'Microphone speech recognition is unavailable. Type the caller question instead.';
      });
      return;
    }
    setState(() {
      listening = true;
      error = null;
    });
    await speech.listen(
      onResult: (result) {
        callerQuestion.text = result.recognizedWords;
        callerQuestion.selection = TextSelection.collapsed(
          offset: callerQuestion.text.length,
        );
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> askGemini() async {
    final current = handoff;
    final transcript = callerQuestion.text.trim();
    if (current == null || transcript.length < 2) return;
    await speech.stop();
    if (mounted) setState(() => listening = false);
    await _run(() async {
      voiceAnswer = await ref
          .read(emergencyHandoffRepositoryProvider)
          .askVoiceAssistant(widget.accessToken, current.id, transcript);
      answer = voiceAnswer;
    });
    // Browsers permit speech most reliably when it starts directly from a
    // user gesture. The network request above consumes that gesture, so web
    // users explicitly press the playback button once the answer is ready.
    if (!kIsWeb && voiceAnswer != null && error == null) await speakAnswer();
  }

  Future<void> _configureSpeechOutput() async {
    try {
      final rawLanguages = await tts.getLanguages;
      final languages =
          rawLanguages is Iterable<Object?> ? rawLanguages : const <Object?>[];
      final language = selectPreferredSpeechLanguage(languages);
      if (language != null) await tts.setLanguage(language);
      await tts.setSpeechRate(0.45);
      await tts.setVolume(1.0);
      await tts.setPitch(1.0);
      // flutter_tts 4.2.5 can leave the web completion future unresolved when
      // Chrome rejects an utterance. Event handlers track web playback.
      await tts.awaitSpeakCompletion(!kIsWeb);
      if (mounted) setState(() => speechOutputReady = true);
    } catch (_) {
      if (mounted) setState(() => speechOutputReady = false);
    }
  }

  Future<void> speakAnswer() async {
    final text = voiceAnswer?.answer ?? answer?.answer;
    if (text == null || text.isEmpty) return;
    if (kIsWeb) {
      if (mounted) {
        setState(() {
          speaking = true;
          error = null;
        });
      }
      final spoken = await speakTextInBrowser(text);
      if (mounted) {
        setState(() {
          speaking = false;
          if (!spoken) {
            error =
                'Chrome could not start speech. Allow sound for localhost and press Play spoken answer again.';
          }
        });
      }
      return;
    }
    final cloudAudio = voiceAnswer?.audioBase64;
    if (cloudAudio != null && cloudAudio.isNotEmpty) {
      if (mounted) {
        setState(() {
          speaking = true;
          error = null;
        });
      }
      final played = await playWavBase64(cloudAudio);
      if (mounted) setState(() => speaking = false);
      if (played) return;
    }
    if (!speechOutputReady && !kIsWeb) {
      await _configureSpeechOutput();
      if (!speechOutputReady) {
        if (mounted) {
          setState(() {
            error =
                'Spoken output is not ready. Check the browser audio permission and try again.';
          });
        }
        return;
      }
    }
    try {
      if (!kIsWeb) await tts.stop();
      if (mounted) {
        setState(() {
          speaking = true;
          error = null;
        });
      }
      await tts.speak(text);
      if (!kIsWeb && mounted) setState(() => speaking = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          speaking = false;
          error = kIsWeb
              ? 'Secure audio and browser speech could not play. Allow sound for localhost, check the Windows volume mixer, and try again.'
              : 'Spoken output is unavailable. Check device sound, then try again.';
        });
      }
    }
  }

  Future<void> call112() async {
    final current = handoff;
    if (current != null) {
      try {
        handoff = await ref.read(emergencyHandoffRepositoryProvider).action(
              widget.accessToken,
              current.id,
              'manual-call-intent',
            );
      } catch (_) {
        // An API failure must never block the emergency dialler.
      }
    }
    var opened = false;
    try {
      opened = await launchUrl(Uri(scheme: 'tel', path: '112'));
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dialler unavailable. Dial 112 manually now.'),
        ),
      );
    }
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await operation();
    } catch (exception) {
      error = _errorMessage(exception);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _errorMessage(Object exception) {
    if (exception is DioException) {
      final data = exception.response?.data;
      if (exception.response?.statusCode == 409) {
        return 'This rehearsal has already moved to another step. Return and prepare a new rehearsal if needed.';
      }
      if (data is Map && data['detail'] is String) {
        return data['detail'] as String;
      }
    }
    return 'Unable to update the rehearsal. Please try again.';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('112 Emergency Handoff')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'SIMULATION ONLY — SnakeCare will not call 112, contact ERSS, or dispatch help. Do not wait for this screen in an emergency.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('manual_call_112'),
                onPressed: call112,
                icon: const Icon(Icons.call),
                label: const Text('Call 112 now (opens dialler)'),
              ),
              const SizedBox(height: 20),
              if (handoff == null)
                _consentForm(context)
              else
                _handoffBody(context),
              if (busy) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ],
              if (error != null) ...[
                const SizedBox(height: 16),
                Text(
                  error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      );

  Widget _consentForm(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Prepare a handoff rehearsal',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Complete a Snakebite Emergency assessment first, then use its Emergency ID. Nothing is sent outside SnakeCare.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: emergencyId,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Snakebite Emergency ID',
              prefixIcon: Icon(Icons.emergency_share_outlined),
            ),
          ),
          const SizedBox(height: 12),
          ...consents.keys.map(
            (label) => CheckboxListTile(
              value: consents[label],
              title: Text(label),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (value) =>
                  setState(() => consents[label] = value ?? false),
            ),
          ),
          const Text(
            'Real call recording and transcription are not enabled. Consent can be cancelled before the rehearsal starts.',
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('prepare_handoff'),
            onPressed:
                allConsented && emergencyId.text.trim().isNotEmpty && !busy
                    ? prepare
                    : null,
            child: const Text('Prepare simulation'),
          ),
        ],
      );

  Widget _handoffBody(BuildContext context) {
    final current = handoff!;
    final canStartCountdown = current.status == 'prepared' ||
        current.status == 'manual_call_requested';
    if (current.status == 'cancelled') {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('Handoff cancelled. No external service was contacted.'),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Consented summary ready',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text('Emergency ID: ${current.emergencyId}'),
        Text('State: ${current.status} • Response: ${current.responseStatus}'),
        const Text(
          'Every answer is source-labelled; missing information stays unknown.',
        ),
        const SizedBox(height: 16),
        if (canStartCountdown) ...[
          FilledButton.icon(
            onPressed: busy ? null : startCountdown,
            icon: const Icon(Icons.timer_outlined),
            label: const Text('Start 15-second rehearsal countdown'),
          ),
          TextButton(
            onPressed: cancel,
            child: const Text('Cancel and revoke consent'),
          ),
        ],
        if (current.status == 'countdown_active') ...[
          Text(
            '${secondsRemaining ?? current.countdownSeconds}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const Text(
            'If the timer ends, SnakeCare records “no response”; it does not infer unconsciousness and does not make a call.',
            textAlign: TextAlign.center,
          ),
          TextButton(onPressed: cancel, child: const Text('Cancel countdown')),
        ],
        if (!canStartCountdown) ...[
          const SizedBox(height: 20),
          const Divider(),
          Text(
            'Mock 112 operator',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Text('This is a local rehearsal. No operator is connected.'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Gemini voice rehearsal',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Text(
                    'With your consent, the temporary question transcript is sent to Google Gemini for intent classification only. SnakeCare builds the answer from consented facts and never lets AI invent medical information.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Supported questions: patient name, emergency location, reported symptoms, incident time, consciousness, allergies, medicines, callback number, emergency contact, and preferred language.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('voice_question'),
                    controller: callerQuestion,
                    minLines: 1,
                    maxLines: 3,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Caller question transcript',
                      hintText: 'For example: Where is the emergency?',
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    key: const Key('voice_listen'),
                    onPressed: busy ? null : toggleListening,
                    icon: Icon(listening ? Icons.stop : Icons.mic_none),
                    label: Text(
                      listening
                          ? 'Stop listening'
                          : 'Listen to caller question',
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    key: const Key('ask_gemini'),
                    onPressed: !busy && callerQuestion.text.trim().length >= 2
                        ? askGemini
                        : null,
                    icon: const Icon(Icons.psychology_alt_outlined),
                    label: const Text('Classify with Gemini and answer'),
                  ),
                  if (voiceAnswer != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      voiceAnswer!.answer,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text('Source: ${voiceAnswer!.source}'),
                    Text(
                      'Recognized intent: ${voiceAnswer!.question} '
                      '(${(voiceAnswer!.confidence * 100).round()}% confidence)',
                    ),
                    const Text(
                      'AI classified the question; AI did not generate the medical facts.',
                    ),
                    TextButton.icon(
                      key: const Key('speak_voice_answer'),
                      onPressed: speaking ? null : speakAnswer,
                      icon: Icon(speaking ? Icons.volume_off : Icons.volume_up),
                      label: Text(
                        speaking
                            ? 'Speaking...'
                            : kIsWeb
                                ? 'Play secure spoken answer'
                                : 'Speak answer again',
                      ),
                    ),
                    if (kIsWeb)
                      const Text(
                        'Chrome requires this tap before it can play speech.',
                        textAlign: TextAlign.center,
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: selectedQuestion,
            decoration: const InputDecoration(labelText: 'Simulated question'),
            items: operatorQuestions.entries
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => selectedQuestion = value!),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: busy ? null : askQuestion,
            icon: const Icon(Icons.record_voice_over_outlined),
            label: const Text('Rehearse answer'),
          ),
          if (answer != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(answer!.answer),
                    const SizedBox(height: 8),
                    Text('Source: ${answer!.source}'),
                    const Text('Simulation only — not sent to 112 or ERSS.'),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}
