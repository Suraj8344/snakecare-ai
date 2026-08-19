# SnakeCare AI

SnakeCare AI is an extensible emergency-response platform. Modules 1–6 provide the engineering foundation, identity, Medical Passport, medical reports, conservative snakebite decision support, and hospital recommendation. Module 7 adds reviewed hospital operations and an approved antivenom-box QR workflow. Module 8 adds a consented, simulation-only 112 handoff rehearsal and a human-controlled dialler action; ambulance dispatch remains delegated to India's emergency service 112.

## Quick start

Prerequisites: Python 3.11+, PostgreSQL 16+, Flutter 3.24+ (Dart 3.5+), and optionally Docker Desktop.

```bash
cp .env.example .env
docker compose up --build
```

API documentation: `http://localhost:8000/docs`; health: `http://localhost:8000/api/v1/health`; readiness: `http://localhost:8000/api/v1/ready`.

Without Docker:

```bash
python -m venv .venv
# Windows: .venv\Scripts\activate
# macOS/Linux: source .venv/bin/activate
python -m pip install -e "./backend[dev]"
cd backend
alembic upgrade head
uvicorn app.main:app --reload
```

Mobile setup:

```bash
cd mobile
flutter create --platforms=android,ios,web --project-name snakecare_mobile .
flutter pub get
flutter run -d emulator-5554 --dart-define=FIREBASE_ENABLED=true --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

The checked-in FlutterFire client configuration targets the CodeBlooded1 Firebase project. The backend still requires its private Firebase service credential. See [Module 2 documentation](docs/module-02/README.md) for credential, bootstrap-admin, and environment configuration.

Firebase-enabled web build:

```bash
cd mobile
flutter build web --dart-define=FIREBASE_ENABLED=true --dart-define=API_BASE_URL=http://localhost:8000 --dart-define=PUBLIC_APP_URL=http://localhost:8080
```

Optional Module 8 Gemini voice rehearsal (backend only):

```dotenv
SNAKECARE_GEMINI_ENABLED=true
SNAKECARE_GEMINI_API_KEY=replace-with-your-private-key
SNAKECARE_GEMINI_MODEL=gemini-3.6-flash
SNAKECARE_GEMINI_TTS_MODEL=gemini-3.1-flash-tts-preview
SNAKECARE_GEMINI_TTS_VOICE=Kore
SNAKECARE_GEMINI_TTS_TIMEOUT_SECONDS=30
```

Never put the Gemini key in Flutter or commit the root `.env` file. The model only classifies caller-question intent; SnakeCare generates the source-bound answer and no real 112/ERSS connection is made.

Import public Pune hospital identities as explicitly unverified registry data:

```powershell
cd backend
..\.venv\Scripts\python.exe -m app.operations.import_pune_hospitals
```

This public map import does not claim antivenom, beds, emergency services, or
admission availability. Hospital administrators must verify those separately.

Run checks:

```bash
cd backend && ruff check . && mypy app && pytest
cd ../mobile && flutter analyze && flutter test
```

See [Module 8 documentation](docs/module-08/README.md), [architecture](docs/ARCHITECTURE.md), [roadmap](docs/ROADMAP.md), and [contributing guide](CONTRIBUTING.md).

> This software is not a medical device. Medical Passport and emergency data are patient-reported; OCR, automated summaries, and decision-support results may contain errors. Suspected snakebite requires urgent professional medical care.
