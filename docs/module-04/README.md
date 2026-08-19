# Module 4 — Medical Reports, OCR, Timeline, and Summaries

## Architecture and rationale

Module 4 adds private patient-owned medical report storage. PostgreSQL stores
metadata, extracted text, processing state, provenance, and summaries; binary
PDF/image content is stored through a file-storage abstraction outside the
database. This keeps transactional metadata queryable while allowing local
storage to be replaced by encrypted object storage without changing the API.

Processing is isolated behind `ReportProcessor`: PDF text extraction, image
OCR, safe categorization, and an extractive summary run after validation. The
summary is explicitly an automated draft derived from report text, never a
diagnosis or verified clinical interpretation. Original files remain the
source of truth.

## Security and safety boundary

- Reports are private to the authenticated owner in Module 4.
- Download, search, timeline, and deletion all enforce ownership.
- Uploads are allow-listed to PDF, PNG, and JPEG, size limited, signature
  checked, renamed to random storage keys, and hashed with SHA-256.
- Filenames and storage paths never come from user-controlled path fragments.
- OCR text and summaries carry provenance and failure status.
- No executable formats, public file URLs, clinical advice, or autonomous
  treatment recommendations are permitted.

## Database design

`medical_reports` stores owner, title, report date, provider, category,
original filename, private storage key, MIME type, byte size, SHA-256 digest,
processing status, extracted text, OCR engine, automated summary, summary
method, failure reason, and timestamps. Indexes support owner-scoped timeline,
category, date, and processing-state filters.

## API contract

- `POST /api/v1/medical-reports` — multipart PDF/image upload and processing.
- `GET /api/v1/medical-reports` — paginated search and filters.
- `GET /api/v1/medical-reports/timeline` — chronological owner timeline.
- `GET /api/v1/medical-reports/{report_id}` — report details.
- `GET /api/v1/medical-reports/{report_id}/file` — authorized original file.
- `DELETE /api/v1/medical-reports/{report_id}` — delete metadata and file.

Filters include free text, category, processing status, content type, and date
range. API responses separate extracted text, automated summary, processing
method, and processing errors.

## Deployment

Local Docker uses a named private report volume mounted only into the API
container. Production must replace local storage with encrypted object storage,
malware scanning, managed keys, retention policy, backups, and asynchronous
workers. Tesseract OCR is installed in the API image for the local reference
deployment.

## Checklist

- [x] Architecture and rationale
- [x] Database and API design
- [x] Backend implementation
- [x] Flutter implementation
- [x] Unit and integration tests
- [x] Docker and migration verification
- [x] Module README and roadmap
- [ ] User approval
