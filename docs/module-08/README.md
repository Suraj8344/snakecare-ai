# Module 8 — Safety-gated 112 emergency handoff simulation

Module 8 prepares a consented, source-labelled emergency summary and lets a user rehearse a 112 operator handoff. It is deliberately **simulation-only**. It does not place calls, contact ERSS, impersonate a caller, dispatch an ambulance, or claim that silence means unconsciousness.

The always-available production action is **Call 112**, which opens the device dialler and leaves the call under human control.

## Architecture and rationale

```text
Snakebite assessment + Medical Passport + authenticated identity
                              |
                              v
                 Consent and disclosure policy
                              |
                              v
               Source-labelled handoff snapshot
                              |
             +----------------+----------------+
             |                                 |
      Manual 112 dialler              Local operator simulation
      (human-controlled)              (never leaves SnakeCare)
             |                                 |
             +----------------+----------------+
                              v
                     Minimal audit events
```

The handoff is stored as an immutable-at-preparation snapshot. That prevents a later Medical Passport edit from silently changing what the user consented to share. Answers are deterministic and restricted to verified Firebase identity, patient-entered emergency data, and patient-entered Medical Passport data. Missing information is stated as `unknown`; the system never invents an answer.

The optional Gemini voice rehearsal adds natural-language question recognition without giving the model authority to produce medical facts. Device speech recognition creates a temporary transcript, Gemini maps it to one allow-listed operator intent, SnakeCare selects the source-bound answer, and text-to-speech reads it aloud. If Gemini is unavailable or rate-limited, an explicit local keyword allow-list handles only clearly supported questions; ambiguous input remains out of scope. The backend does not store the raw transcript in the audit log and the Gemini key is never shipped to Flutter.

When location consent is enabled, SnakeCare may send the captured latitude and longitude to the configured OpenStreetMap Nominatim reverse-geocoding service to obtain a nearby place label. The source-of-truth coordinates are always included, and failure to resolve a label never removes or changes them.

## Safety case

### Intended use

- Help a conscious user or helper organize information before or during a manually controlled 112 call.
- Rehearse likely operator questions without contacting an emergency service.
- Preserve a minimal audit trail of consent, cancellation, manual-call intent, and simulated questions.

### Prohibited use

- Automatic calling, robocalling, SIP/PSTN integration, or ERSS transmission.
- Deciding that a patient is unconscious because no response was received.
- Diagnosing, prescribing, dispatching, or promising an emergency-service response.
- Recording or transcribing a real emergency call.
- Continuing a countdown when the user cancels.

### Safety claims and controls

| Claim | Control | Verification |
|---|---|---|
| The feature cannot contact real 112 | No telephony/provider adapter exists; API only records manual dialler intent | Unit test and code review |
| Silence is not treated as unconsciousness | State is `no_response`; medical consciousness remains the assessment value or `unknown` | Unit test |
| Shared facts are traceable | Every summary field carries a `source` and missing-data marker | Schema and unit test |
| The user can stop the workflow | Cancel is visible during the 15-second countdown and persisted | Widget/service tests |
| Unknown facts are not guessed | Gemini can only classify an allow-listed intent; the deterministic answer engine returns an explicit unknown answer | Unit test |
| Gemini credentials stay private | The client calls an authenticated SnakeCare endpoint; only FastAPI reads the key from its environment | Configuration review |

Residual risk remains: the device may have no network, location may be stale, Passport data may be wrong, the dialler may not open, and the user may delay calling. The UI therefore repeats: **do not wait for the app; call 112 now**.

## Consent model

Consent is explicit, purpose-limited, revocable before handoff, and recorded per emergency. The user separately chooses to disclose identity/callback, location, emergency findings, Medical Passport data, and sending a temporary caller-question transcript to Google Gemini for intent classification. The simulation requires all five switches so the prototype has one clear disclosure contract. Real call recording/transcription is not implemented and would require separate opt-in consent. The local microphone transcript is not persisted by SnakeCare and the consented medical snapshot is not sent to Gemini.

## Failure-mode analysis

| Failure | Detection | Safe response |
|---|---|---|
| No user response after countdown | Timer finishes without confirmation | Mark `no_response`, display “consciousness unknown”, never auto-call |
| Location absent or denied | Snapshot field missing | Say location is unknown and tell the user to give it verbally |
| Medical Passport absent/stale | Missing record or patient-entered source | Say unknown; show source and preparation time |
| API/network unavailable | Dio/server error | Keep Call 112 enabled; do not block the dialler |
| Dialler unsupported (for example web) | URL launcher returns false | Display 112 and ask the user to dial manually |
| Duplicate/replayed action | State transition validation | Return conflict without duplicating the audit event |
| Unsupported operator question | Allow-list rejection | Refuse to improvise and direct the human caller to answer |
| Gemini unavailable, rate-limited, slow, or malformed | Timeout, HTTP error, or schema validation failure | Use the strict local intent allow-list; leave ambiguous input out of scope and keep Call 112 available |
| Reverse geocoder unavailable or returns no place | Timeout, HTTP error, or empty response | Speak the original coordinates and state that the nearest place is unavailable |
| Speech recognition or TTS unavailable | Platform plugin reports failure | Allow typed questions and show the answer as text |

## ERSS integration proposal (not implemented)

A real integration may be considered only after the responsible 112/ERSS authority approves an official interface and a legal/privacy/security review is complete. The proposed adapter boundary would exchange the minimum consented fields, use mutual authentication, signed requests, idempotency keys, delivery receipts, revocation/retention rules, and end-to-end audit correlation. A controlled pilot must test multilingual accessibility, false/no-response cases, network loss, location accuracy, operator override, and human escalation.

No production flag can enable automatic 112 calls in this module because no real ERSS adapter is present.

## Database

`emergency_handoffs` stores the patient owner, snakebite emergency, explicit consent flags, 15-second countdown, response status, state, a JSONB source-labelled snapshot, and lifecycle timestamps. `emergency_handoff_events` stores safe audit metadata and simulated question/answer events. It does not store audio or a real-call transcript.

## API

| Method | Path | Purpose |
|---|---|---|
| POST | `/api/v1/emergency-handoffs` | Prepare a consented simulation snapshot |
| GET | `/api/v1/emergency-handoffs` | List the signed-in patient's handoffs |
| GET | `/api/v1/emergency-handoffs/{id}` | Read one owned handoff and its audit events |
| POST | `/api/v1/emergency-handoffs/{id}/countdown` | Start the local handoff countdown state |
| POST | `/api/v1/emergency-handoffs/{id}/no-response` | Record no response without inferring unconsciousness |
| POST | `/api/v1/emergency-handoffs/{id}/cancel` | Cancel before simulated handoff |
| POST | `/api/v1/emergency-handoffs/{id}/manual-call-intent` | Audit a human-controlled dialler action |
| POST | `/api/v1/emergency-handoffs/{id}/simulate` | Answer one allow-listed mock operator question |
| POST | `/api/v1/emergency-handoffs/{id}/voice-assistant` | Use Gemini to classify a temporary transcript, then return a deterministic source-bound answer |

Every endpoint requires the existing bearer token and enforces patient ownership.

## Frontend

The Flutter flow is accessible from a completed snakebite assessment and from the Module 8 preview. It provides the safety notice, five consent controls, a 15-second cancelable countdown, source-labelled summary, simulated operator questions, microphone or typed input, spoken output, unknown-data warnings, and a manual Call 112 action.

## Gemini configuration

Create the key in Google AI Studio and keep it only in the root `.env` file:

```dotenv
SNAKECARE_GEMINI_ENABLED=true
SNAKECARE_GEMINI_API_KEY=replace-with-your-private-key
SNAKECARE_GEMINI_MODEL=gemini-3.6-flash
SNAKECARE_GEMINI_TTS_MODEL=gemini-3.1-flash-tts-preview
SNAKECARE_GEMINI_TTS_VOICE=Kore
SNAKECARE_GEMINI_TTS_TIMEOUT_SECONDS=30
SNAKECARE_REVERSE_GEOCODING_ENABLED=true
SNAKECARE_REVERSE_GEOCODING_URL=https://nominatim.openstreetmap.org/reverse
SNAKECARE_REVERSE_GEOCODING_TIMEOUT_SECONDS=4
```

The backend may use Gemini TTS to read the already-approved, deterministic answer.
The browser never receives the Gemini API key, and Gemini does not create the medical
facts. Audio is temporary, returned as WAV data with the answer, and is not persisted.
The displayed source-labelled text remains authoritative if audio generation or playback
is unavailable.

Rebuild and recreate the API after changing these variables. Do not add a Gemini key to `--dart-define`, Firebase client configuration, Flutter source, screenshots, logs, or Git.

## Tests and deployment

Backend tests cover source-labelled snapshots, unknown answers, question allow-listing, schema-constrained Gemini classification, rejected model output, and the no-response invariant. Flutter tests cover JSON parsing, visible simulation labelling, consent gating, and countdown cancellation. Run migration `20260810_0013` before deploying the API, then deploy rebuilt Flutter clients. No telephony credentials are required or accepted.

## Completion checklist

- [x] Architecture and rationale documented
- [x] Safety case and consent model documented
- [x] Failure modes and ERSS proposal documented
- [x] Database migration and models implemented
- [x] Authenticated API and service implemented
- [x] Flutter consent/countdown/simulation interface implemented
- [x] Gemini intent classification and device speech I/O implemented behind explicit consent
- [x] Backend and Flutter tests added
- [x] Deployment boundaries documented
- [ ] Product owner approval received
- [ ] Module 9 started (intentionally not started)
