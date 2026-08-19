import 'wav_audio_player_stub.dart'
    if (dart.library.html) 'wav_audio_player_web.dart' as implementation;

Future<bool> playWavBase64(String base64Audio) =>
    implementation.playWavBase64(base64Audio);

Future<bool> speakTextInBrowser(String text) =>
    implementation.speakTextInBrowser(text);
