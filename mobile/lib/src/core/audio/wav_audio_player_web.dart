// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

html.AudioElement? _activeAudio;

Future<bool> playWavBase64(String base64Audio) async {
  if (base64Audio.isEmpty) return false;
  try {
    _activeAudio?.pause();
    final audio = html.AudioElement(
      'data:audio/wav;base64,$base64Audio',
    )
      ..autoplay = false
      ..volume = 1;
    _activeAudio = audio;
    await audio.play();
    return true;
  } catch (_) {
    return false;
  }
}

Future<bool> speakTextInBrowser(String text) async {
  if (text.trim().isEmpty) return false;
  final synthesis = html.window.speechSynthesis;
  if (synthesis == null) return false;

  try {
    _activeAudio?.pause();
    synthesis.cancel();
    final utterance = html.SpeechSynthesisUtterance(text.trim())
      ..lang = 'en-IN'
      ..rate = 0.9
      ..pitch = 1
      ..volume = 1;
    // Calling speak synchronously from the Play button preserves Chrome's
    // user-activation permission. Waiting for completion is intentionally
    // avoided because some Chrome builds never emit the completion event.
    synthesis.speak(utterance);
    return true;
  } catch (_) {
    return false;
  }
}
