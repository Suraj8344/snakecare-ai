# SnakeCare mobile foundation

The portable Flutter source is committed without generated platform runners. After installing Flutter, run `flutter create --platforms=android,ios,web --project-name snakecare_mobile .` once, then `flutter pub get`.

Configuration uses compile-time defines:

```bash
flutter run -d emulator-5554 --dart-define=FIREBASE_ENABLED=true --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Firebase packages are ready but Firebase is deliberately not initialized until Module 2. At that point, install FlutterFire CLI and run `flutterfire configure` separately for development, staging, and production. Native credentials remain ignored by Git.
