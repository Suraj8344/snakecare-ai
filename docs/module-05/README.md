# Module 5 — Snakebite Emergency Decision Support

## Architecture and rationale

Module 5 adds a patient-owned emergency case workflow. Flutter collects a
structured symptom checklist, an optional reviewed speech transcript, an
optional private photo, location, bite details, and vitals. FastAPI validates
and stores the case, then a versioned rules engine produces a conservative
urgency band, reasons, immediate actions, and first-aid guidance.

The engine is deliberately not a snake-species classifier, diagnosis, or
antivenom recommendation. Every suspected snakebite is directed to a health
facility without delay. Critical and high-risk bands only escalate that
message when danger signs are present; the lowest band is called
`urgent_assessment`, never “safe” or “mild”.

## Clinical safety basis

The safety content is derived from official guidance:

- [WHO snakebite first aid](https://www.who.int/teams/control-of-neglected-tropical-diseases/snakebite-envenoming/treatment)
- [WHO South-East Asia snakebite guidelines](https://www.who.int/southeastasia/publications/i/item/9789290225300)
- [Government of India Standard Treatment Guidelines](https://www.clinicalestablishments.mohfw.gov.in/sites/default/files/standard-treatment-guidelines/3941.pdf)

The app tells users to move away from danger, remove tight items, keep the
person and bitten limb still, arrange immediate transport, and use the recovery
position if vomiting or drowsy while monitoring breathing. It warns against
tight tourniquets, cutting, sucking, ice, electric shock, and traditional or
unproven remedies. It does not instruct users to administer antivenom or apply
a pressure bandage without trained local guidance.

## Database

`snakebite_emergencies` stores the authenticated owner, event time, bite site,
structured symptoms, free-text/voice transcript, location and accuracy, vitals,
private photo metadata, urgency result, triggered reasons, immediate actions,
ruleset version, guidance source version, and timestamps. Owner and chronology
indexes support later coordination modules without exposing a public case URL.

## API

- `POST /api/v1/snakebite-emergencies` — multipart case assessment with an
  optional PNG/JPEG photo.
- `GET /api/v1/snakebite-emergencies` — current user's case history.
- `GET /api/v1/snakebite-emergencies/{case_id}` — owner-scoped details.
- `GET /api/v1/snakebite-emergencies/{case_id}/photo` — authorized photo.

The response separates user-reported inputs from the computed urgency,
explanations, immediate actions, first aid, prohibitions, and model metadata.

## Deployment

The Docker reference deployment stores emergency photos in a private named
volume mounted only into the API container. Production must use encrypted
object storage, malware scanning, short retention, audit logs, and regional
data residency. Location and emergency health data must never be placed in
logs or analytics. The ruleset requires clinical governance, validation,
version control, and post-deployment monitoring before real-world clinical use.

## Checklist

- [x] Architecture, rationale, safety research, database, and API design
- [x] Backend implementation
- [x] Flutter implementation
- [x] Unit and integration tests
- [x] Docker and migration verification
- [x] README and roadmap
- [ ] User approval
