import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyCapabilities {
  const EmergencyCapabilities({
    required this.platform,
    required this.smsComposer,
    required this.dialer,
    required this.bleAdvertiser,
    required this.bleEnabled,
    required this.foregroundService,
  });

  factory EmergencyCapabilities.fromMap(Map<Object?, Object?> value) =>
      EmergencyCapabilities(
        platform: value['platform'] as String? ?? 'unknown',
        smsComposer: value['smsComposer'] as bool? ?? false,
        dialer: value['dialer'] as bool? ?? false,
        bleAdvertiser: value['bleAdvertiser'] as bool? ?? false,
        bleEnabled: value['bleEnabled'] as bool? ?? false,
        foregroundService: value['foregroundService'] as bool? ?? false,
      );

  final String platform;
  final bool smsComposer;
  final bool dialer;
  final bool bleAdvertiser;
  final bool bleEnabled;
  final bool foregroundService;
}

class EmergencyPlatformService {
  const EmergencyPlatformService();

  static const _channel = MethodChannel('org.snakecare/emergency');

  Future<EmergencyCapabilities> capabilities() async {
    if (kIsWeb) {
      return const EmergencyCapabilities(
        platform: 'web',
        smsComposer: true,
        dialer: true,
        bleAdvertiser: false,
        bleEnabled: false,
        foregroundService: false,
      );
    }
    try {
      final value = await _channel.invokeMapMethod<Object?, Object?>(
        'capabilities',
      );
      return EmergencyCapabilities.fromMap(value ?? const {});
    } on MissingPluginException {
      return const EmergencyCapabilities(
        platform: 'unsupported',
        smsComposer: false,
        dialer: true,
        bleAdvertiser: false,
        bleEnabled: false,
        foregroundService: false,
      );
    }
  }

  Future<void> prepareSms({
    required String number,
    required String message,
  }) async {
    if (number.trim().isEmpty) {
      throw PlatformException(
        code: 'MISSING_GATEWAY',
        message: 'Configure a verified SMS gateway number first.',
      );
    }
    if (kIsWeb) {
      final uri = Uri(
        scheme: 'sms',
        path: number.trim(),
        queryParameters: {'body': message},
      );
      if (!await launchUrl(uri)) {
        throw PlatformException(
          code: 'SMS_UNAVAILABLE',
          message: 'No SMS application is available.',
        );
      }
      return;
    }
    await _channel.invokeMethod<void>('prepareSms', {
      'number': number.trim(),
      'message': message,
    });
  }

  Future<void> prepareMissedCall(String number) async {
    if (number.trim().isEmpty) {
      throw PlatformException(
        code: 'MISSING_GATEWAY',
        message: 'Configure a verified missed-call gateway first.',
      );
    }
    if (kIsWeb) {
      if (!await launchUrl(Uri(scheme: 'tel', path: number.trim()))) {
        throw PlatformException(
          code: 'DIALER_UNAVAILABLE',
          message: 'No phone dialer is available.',
        );
      }
      return;
    }
    await _channel.invokeMethod<void>('prepareMissedCall', {
      'number': number.trim(),
    });
  }

  Future<void> startBleBroadcast(String payload) =>
      _channel.invokeMethod<void>('startBleBroadcast', {'payload': payload});

  Future<void> stopBleBroadcast() =>
      _channel.invokeMethod<void>('stopBleBroadcast');

  Future<Map<Object?, Object?>> signalInfo() async {
    if (kIsWeb) {
      return const {'available': false, 'reason': 'Native Android only'};
    }
    return await _channel.invokeMapMethod<Object?, Object?>('signalInfo') ??
        const {'available': false};
  }
}
