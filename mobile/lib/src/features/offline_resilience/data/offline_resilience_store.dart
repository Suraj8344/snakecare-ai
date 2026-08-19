import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

class OfflineResilienceStore {
  const OfflineResilienceStore._();

  static const boxName = 'snakecare_offline_resilience';
  static const _keyName = 'snakecare_offline_hive_key_v1';

  static Future<void> initialize() async {
    await Hive.initFlutter();
    if (Hive.isBoxOpen(boxName)) return;
    if (kIsWeb) {
      await Hive.openBox<dynamic>(boxName);
    } else {
      const storage = FlutterSecureStorage();
      var encoded = await storage.read(key: _keyName);
      if (encoded == null) {
        encoded = base64UrlEncode(Hive.generateSecureKey());
        await storage.write(key: _keyName, value: encoded);
      }
      await Hive.openBox<dynamic>(
        boxName,
        encryptionCipher: HiveAesCipher(base64Url.decode(encoded)),
      );
    }
    final box = Hive.box<dynamic>(boxName);
    if (!box.containsKey('hospital_snapshot')) {
      await box.put('hospital_snapshot', [
        {
          'name': 'Sassoon General Hospital',
          'distance_km': 1.2,
          'status': 'Hospital reported • call to confirm',
        },
        {
          'name': 'Jehangir Hospital',
          'distance_km': 2.8,
          'status': 'Hospital reported • call to confirm',
        },
        {
          'name': 'Ruby Hall Clinic',
          'distance_km': 3.6,
          'status': 'Stale snapshot • availability unknown',
        },
      ]);
      await box.put('hospital_snapshot_at', DateTime.now().toIso8601String());
    }
  }

  static Box<dynamic> get box => Hive.box<dynamic>(boxName);
  static bool get isReady => Hive.isBoxOpen(boxName);

  static List<Map<String, dynamic>> get hospitals =>
      (box.get('hospital_snapshot', defaultValue: const <dynamic>[]) as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(growable: false);

  static int get pendingCount =>
      (box.get('sos_outbox', defaultValue: const <dynamic>[]) as List).length;

  static Future<void> queueSos(Map<String, dynamic> payload) async {
    final current = List<dynamic>.from(
      box.get('sos_outbox', defaultValue: const <dynamic>[]) as List,
    );
    current.add({
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'attempts': 0,
      'status': 'pending',
      'next_attempt_at': DateTime.now().toUtc().toIso8601String(),
      'payload': payload,
    });
    await box.put('sos_outbox', current);
  }

  static Future<void> saveTrip({
    required String contact,
    required DateTime expectedReturn,
  }) =>
      box.put('active_trip', {
        'contact': contact,
        'expected_return': expectedReturn.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });
}
