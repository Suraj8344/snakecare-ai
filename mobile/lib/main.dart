import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snakecare_mobile/firebase_options.dart';
import 'package:snakecare_mobile/src/app.dart';
import 'package:snakecare_mobile/src/core/config/app_config.dart';
import 'package:snakecare_mobile/src/features/offline_resilience/data/offline_resilience_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OfflineResilienceStore.initialize();
  if (AppConfig.firebaseEnabled) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  runApp(const ProviderScope(child: SnakeCareApp()));
}
