# MediShield AI — Zero to Hero Implementation Plan (Simple English)

**Document:** `implementation_plan_v2.md`  
**Status:** Proposed engineering specification · v2.0  
**Scope:** Hackathon MVP → final-year engineering project → research validation  
**Team:** Abhishek Gupta (Full-Stack & Systems Architecture), Akanksha Keshri (AI/ML & Research), Aman Dangi (IoT & Integration)

> [!IMPORTANT]
> This plan is for a synthetic-data research prototype, not an approved clinical product. Do not connect experimental sensors to people or use this software to make treatment decisions. All clinical thresholds, model intended uses, medication rules, and downtime procedures need clinical governance and independent validation before real-world use. Never represent proposed metrics as achieved results.

## Start here — understand the whole project in 5 minutes

MediShield AI is a hospital safety and patient-record prototype. It helps staff keep track of patients, medicines, vital readings, shift changes, reports and referrals. It does not replace a doctor. All demonstrations use fictional patients and simulated medical actions.

### Who does what?

| Person | Work in the system |
| --- | --- |
| Super Admin (`PLATFORM_ADMIN`) | Onboards hospitals, approves administrators, manages platform accounts and suspends or bans accounts. Cannot edit clinical records. |
| Hospital Admin (`HOSPITAL_ADMIN`) | Runs one hospital's staff, departments, wards, beds and local access. |
| Receptionist (`RECEPTIONIST`) | Registers patients, manages walk-in queue and admission coordination; cannot prescribe or verify clinical data. |
| Ward Staff / Compounder (`WARD_STAFF`) | Assigned ward operational tasks and bed readiness; clinical activity requires separate authorized credential. |
| Doctor (`DOCTOR`) | Reviews assigned patients, creates orders, reviews warnings and signs summaries. |
| Nurse (`NURSE`) | Scans wristbands and medicines, records observations and hands over tasks. |
| Lab staff (`LAB_TECH`) | Uploads reports and verifies extracted values when authorized. |
| Patient (`PATIENT`) | Views their own released records, manages sharing requests and requests corrections. |
| Authorized caregiver (`CAREGIVER`) | Accesses only the specific patient's approved scope and duration. |
| Receiving doctor (`REFERRAL_DOCTOR`) | Opens only the patient records explicitly shared with them. |
| Researcher (`RESEARCHER`) | Tests AI models on approved research data or fake data, separate from care. |
| Device / service | Restricted machine access, never a general human login. |

### Example: one patient visits the hospital

1. Super Admin creates a hospital application record, reviews it, invites its first Hospital Admin and activates the hospital. The Hospital Admin sets up departments, wards, beds and staff. Reception creates a patient record, coordinates admission with an authorized clinician and assigns a bed. A patient portal account is optional and separate.
2. The system creates a QR wristband that points to that admission.
3. A doctor creates a medication order; the backend creates individual dose tasks.
4. A nurse scans the patient and medicine. The server reserves the specific task if all safety checks pass. A second nurse cannot reserve that same task at the same time.
5. The nurse uses the separate start and confirmation steps in the simulated workflow. If the outcome is uncertain, staff must review it rather than retry the physical action.
6. An IoT simulator sends vital readings. The dashboard shows their quality and freshness; the warning system tracks alerts.
7. Staff upload a report or dictate a note, check the draft, and save the verified record.
8. At shift change, the incoming nurse receives the reviewed summary and outstanding tasks.
9. The doctor reviews the discharge or referral summary. An authorized receiving clinician may open allowed records and ask the chatbot questions with source citations.

### How to read this plan

- Read the simple goal and steps at the start of each module first.
- Then read its API examples when you begin coding. The expandable engineering notes keep the exact technical details from the full plan.
- Follow the dependency and weekly roadmap: a module should not be marked complete until its tests pass.
- The existing clinical API contracts are retained. The platform, hospital and patient account contracts are new; the hospital creation and invitation behavior is updated explicitly. Use the version 2 contract as the source of truth.

### Technical words in simple English

| Word | Meaning |
| --- | --- |
| Frontend / backend | The screen people use / the server that checks and processes requests. |
| API / endpoint | A way for two programs to talk / one specific API address. |
| Request / response | Information sent to the server / information sent back. |
| JSON | A standard text format for sending structured information. |
| RBAC / tenant | Permissions based on roles / a hospital's separate area of data. A role alone does not grant patient access. |
| JWT / session / MFA | Login token / a logged-in period / an additional login verification step. |
| PostgreSQL / transaction | The main database / a group of database changes that succeed together or fail together. |
| Row lock / atomic | Temporarily prevents competing updates to a database row / completes as one indivisible operation. |
| Idempotency | Repeating the same request with the same key does not repeat its effect. |
| Redis / BullMQ / worker | Temporary supporting storage / a task queue / a process that handles background work. |
| Outbox | A database table of events to publish reliably after a transaction succeeds. |
| MQTT / WebSocket | A messaging protocol for devices / a live connection to update screens. |
| QoS / deduplication | Message delivery guarantee / detecting repeats and storing only one copy. |
| Telemetry / stale | Measurements sent by devices / measurements too old to be relied on as current. |
| TimescaleDB / pgvector | PostgreSQL extensions for time-based data / vector similarity search. |
| NEWS2 / SBAR | A standardized early warning score / a structured shift handoff format. |
| OCR / LLM / RAG | Reading text from images / language AI / finding records before asking AI to answer from them. |
| Embedding / citation | Numbers that represent text meaning / a link to supporting evidence. |
| FHIR / ABHA | Healthcare data exchange standard / an Indian health account identifier. |
| Consent / grant | Permission to share information for a stated purpose / a specific access authorization. |
| Opaque token / digest | A random value that reveals no patient data / a protected lookup representation of a value. |
| Audit / provenance | Record of who did what / where information came from. |
| Migration / index | A controlled change to database structure / a structure that helps find data faster or enforce uniqueness. |
| Schema / Zod / Pydantic | Rules describing valid data / validation tools for TypeScript and Python. |
| OpenAPI | A machine-readable description of API routes and data formats. |
| CI / fixture | Automatic code checks / prepared test data with expected results. |
| PHI / TTL | Identifiable health information / how long something remains valid or cached. |
| OOD / abstain | Input outside the model’s supported data / refusing to produce an unsupported result. |
| p95 latency | The time within which 95% of measured requests finish. |

## Table of contents

- [0. Start from zero](#0-start-from-zero--master-build-order-and-product-boundaries)
- [1. Scope and architecture decisions](#1-scope-and-architecture-decisions)
- [2. System architecture and workflows](#2-system-architecture-and-workflows)
- [3. Repository and local setup](#3-repository-and-local-setup)
- [4. Authorization and API conventions](#4-authorization-and-api-conventions)
- [5. Database design and invariants](#5-database-design-and-invariants)
- [6. Module-by-module implementation and API contracts](#6-module-by-module-implementation-and-api-contracts)
- [7. Real-time events and asynchronous jobs](#7-real-time-events-and-asynchronous-jobs)
- [8. Client application implementation](#8-client-application-implementation)
- [9. Testing and research evaluation](#9-testing-and-research-evaluation)
- [10. Deployment and operational runbooks](#10-deployment-and-operational-runbooks)
- [11. 24-week roadmap and ownership](#11-24-week-roadmap-and-ownership)
- [12. MVP demonstration and release gates](#12-mvp-demonstration-and-release-gates)
- [13. Traceability and open decisions](#13-traceability-and-open-decisions)

## 0. Start from zero — master build order and product boundaries

The original PRD describes clinical workflows (FR1–FR7), staff and receiving doctors. It does not fully specify a platform owner, onboarding approval, account bans, patient login or caregiver access. These are **new proposed product requirements**, not features claimed in the source documents. The earlier README stack and all clinical modules are retained. The rapid MVP PDF (pp. 1–2) recommends a small stack and a simulator; the revision guide (pp. 1–3) requires clinical feature alignment, consistent technology and research evidence.

```mermaid
flowchart TD
  A[Secure first Super Admin] --> B[Review and approve hospital]
  B --> C[Invite and verify Hospital Admin]
  C --> D[Configure departments wards beds and staff]
  D --> E[Activate hospital and staff access]
  E --> F[Reception registers patient]
  F --> G[Optional verified patient portal link]
  F --> H[Clinician approves admission and bed assignment]
  H --> I[Doctor orders and nurse safety workflow]
  I --> J[IoT alerts reports notes and handoffs]
  J --> K[Discharge and verified patient history]
  K --> L[Consent scoped referral and RAG]
  K --> M[Patient views released documents]
```

### 0.1 What to build first

| Order | Module | Finish before moving forward |
| --- | --- | --- |
| 1 | M01 Foundation | Repository, database, Docker, shared schemas and test runner |
| 2 | M02 Authentication | Login, MFA, sessions, revocation, permissions and account recovery |
| 3 | M02A Super Admin and onboarding | First admin, application review, invitation, activation, platform moderation |
| 4 | M03 Hospital organization | Staff, departments, wards, beds and assigned permissions |
| 5 | M03A Hospital operations | Staff lifecycle, reception queue, ward tasks and operational dashboard |
| 6 | M04 Patient records | Local MRN, identity review, consent, admissions and wristband |
| 7 | M04A Patient and caregiver portal | Optional verified login, releases, corrections, grants and account recovery |
| 8 | M05–M08 Medication safety | Orders, dose events, locks, downtime and interaction review |
| 9 | M09–M12 Monitoring | Devices, vitals, NEWS2 and durable alerts |
| 10 | M13–M16 Clinical operations | Shifts, vault, reports and voice notes |
| 11 | M17–M18 Continuity | Scoped chatbot and secure referral |
| 12 | M19–M20 Research and release | Model studies, testing, deployment and documentation |

Do not start with AI or build dashboards with hardcoded patient permissions. Start with a real database and working authorization. For a hackathon, make a narrow working vertical slice of each required workflow rather than claiming every advanced module is ready. Never defer safety or tenant isolation to a later sprint.

### 0.2 Account and record separation

A user account means a person can log in. A membership means a staff user works in a particular hospital. A patient record is a medical identity and exists even if the person never uses the app. An admission is a visit/stay, not a new user account. A portal link proves an account belongs to a particular patient record. A caregiver grant is permission to access someone else's released records. These objects must not be treated as interchangeable. Removing a login does not erase a medical record or cancel a hospital admission.

## 1. Scope and architecture decisions

**In simple words:** We first choose one main technology stack. The original documents suggest different stacks. This plan uses the mobile and backend stack from the README, with simpler alternatives for the prototype.

### 1.1 Input documents and reconciliation

| Input | Requirements adopted |
| --- | --- |
| `autonomous_clinical_safety_continuity_platform_prd(1).md`, FR1–FR7, sections 5–9 | Registration, vitals, scans, voice, reports, referral/RAG, deterioration, interactions, specialized models, pre-operative and longitudinal advisory, NFRs and phases |
| `MediShield AI Prototyping Tech Stack & Use Cases(1).pdf`, pp. 1–2 | Rapid MVP stack; mock lab feeds; MQTT simulator fallback; unified vision/text provider; simple hosting |
| `MediShield AI Research Report Revision Guide(1).pdf`, pp. 1–3 | Dual extraction verification, QR + RAG integration, model/data mapping, stack consistency, research evaluation and missing diagrams |
| Previous `README.md` | React Native/Expo nurse app, Node/Express authoritative API, Python AI service, PostgreSQL row-lock dose state machine, 24-week schedule |

The source PRD describes ambitious autonomous diagnostic and error-prevention claims; this plan implements human-supervised decision support and measurable simulation outcomes instead. The sources disagree on FastAPI versus Express, direct realtime versus MQTT/worker, and PWA versus native app. The following are explicit proposed engineering decisions, not claims about an existing codebase.

### 1.2 Selected stack and MVP simplification

| Layer | Reference implementation | MVP simplification |
| --- | --- | --- |
| Nurse client | Expo + React Native + TypeScript, React Navigation, expo-camera, expo-audio, TanStack Query, Zustand, secure storage, SQLite | Scanner, tasks, vitals, notes; web PWA fallback shares REST contracts |
| Doctor/admin/referral | Next.js + TypeScript + Tailwind + Lucide | Single app with role-specific routes |
| Authoritative API | Node.js LTS, Express, Zod, Prisma plus parameterized SQL for row locks | One modular monolith; no Kubernetes/Kafka |
| AI/ML | FastAPI, Pydantic, PyTorch, Hugging Face, XGBoost, SHAP, Whisper/IndicWhisper, PaddleOCR, Gemini, LangChain (optional) | One vision/text provider + one speech adapter, mock inference fixtures |
| Data | PostgreSQL + pgvector; TimescaleDB for telemetry | Managed PostgreSQL/Supabase possible; ordinary partitioned telemetry table if Timescale unavailable |
| Jobs/realtime | Redis + BullMQ, Socket.IO, transactional outbox | One worker process; alternatively Supabase Realtime with scoped access; do not expose clinical tables directly |
| IoT | ESP32, Mosquitto MQTT/TLS, MAX30102, AD8232, DS18B20, HX711/load cell | Python simulator + synthetic MAX30102-like values; no patient-connected circuits |
| Files | S3-compatible private object storage | Local MinIO or private managed storage |
| Hosting | Docker Compose locally; Vercel web, container host API/worker/AI; private database/broker | One small deployment with separate service identities and fake data |

FastAPI-only is a viable alternative from the supplied MVP blueprint **if chosen before implementation**. Port the same REST contracts and SQL invariants to that service; never run Express and FastAPI as competing medication writers. Supabase service credentials stay server-side. Native encrypted SQLite requires a compatible development build and explicit encryption configuration; otherwise do not cache sensitive records.

### 1.3 Scope boundaries and milestones

- **MVP (target weeks 1–8, parallel tracks):** login, hospital/ward, synthetic patient and encounter, QR wristband, one clinician-created medication order, atomic reservation/start/confirmation, telemetry simulator, warning banner, referral token + scoped RAG with verified seed records, short voice draft. Physical ESP32 optional. Advanced modules may use visibly labeled fixtures, not fake model claims.
- **Full clinical workflow (weeks 9–20):** device management, full NEWS2 input capture, alert lifecycle, SBAR, longitudinal record vault, digital/OCR review, voice, interactions, FHIR adapter, referral lifecycle, RAG evaluation.
- **Research and integration (weeks 21–24, research training can start earlier):** specialized models, pre-surgical/trajectory research, safety hardening, benchmark runs, thesis figures and demo. Four disease models are stretch goals; deliver one or two properly evaluated tasks before expanding.
- **Not in this scope:** autonomous prescribing, real Aadhaar/ABHA lookup without authorized integration, clinical diagnosis or automatic risk treatment, billing/payment/appointment marketplace, live hospital deployment. These need separate requirements and approval.

## 2. System architecture and workflows

**In simple words:** The mobile app and website talk to the main API. The API checks permissions and saves important records in PostgreSQL. IoT readings arrive through MQTT. Background workers handle slow jobs, and the Python service handles AI. No AI or mobile app directly approves medicine administration.

```mermaid
flowchart TD
  MOB[Expo nurse app / PWA] --> GW[Express REST + authorization]
  WEB[Doctor / admin / referral web] --> GW
  GW --> PG[(PostgreSQL clinical state)]
  GW --> OBJ[(Private files)]
  PG --> OUT[Transactional outbox relay]
  OUT --> Q[Redis / BullMQ]
  Q --> WORK[Worker]
  WORK --> AI[Private FastAPI inference]
  WORK --> PG
  ESP[ESP32 or simulator] --> BROKER[MQTT TLS]
  BROKER --> WORK
  WORK --> TS[(TimescaleDB / partitions)]
  WORK --> RULE[Validated deterministic rule engine]
  RULE --> PG
  WORK --> RT[Authorized Socket.IO gateway]
  RT --> MOB
  RT --> WEB
  AI --> OBJ
  AI --> V[(Scoped pgvector retrieval)]
```

**Trust boundary:** API derives actor, tenant and permissions from authenticated context. No mobile client, QR string, AI model, device or queue message is allowed to mutate an authoritative clinical record without server validation. AI service returns drafts/results only. Workers use narrow service identities and call approved domain functions for writes. All requests recheck scope even after authentication.

```mermaid
flowchart LR
  A[Walk-in registration] --> B[Encounter / bed assignment]
  B --> C[Wristband issuance]
  C --> D[Doctor creates order]
  D --> E[Nurse scan / reserve / start / record]
  B --> F[Device telemetry / manual observations]
  F --> G[Quality checks and warning workflow]
  B --> H[Verified report and voice notes]
  E --> I[SBAR and longitudinal timeline]
  G --> I
  H --> I
  I --> J[Discharge / referral grant]
  J --> K[Authenticated receiving clinician]
  K --> L[Scoped record view / cited RAG]
```

### 2.1 Core engineering principles

Use database transactions for safety-critical state, transactional outbox for durable events, explicit clinical timestamps and provenance, tenant-scoped authorization, immutable record revisions, bounded retries, and visible unknown/stale/unavailable states. AI must abstain when data is absent; do not replace an unknown value with zero or a fabricated default. Synthetic and real data must never be mixed; production-mode features remain disabled pending governance.

## 3. Repository and local setup

**In simple words:** Put all project code in one repository. Keep the mobile app, website, main API, background worker, AI service and device code in separate folders. Start the shared services before starting the apps. The commands are proposed until the team creates the scripts.

```text
medishield-ai/
├── README.md
├── implementation_plan.md
├── design.md
├── agent.md
├── package.json / pnpm-workspace.yaml
├── docker-compose.yml / .env.example
├── apps/
│   ├── api/src/{modules,middleware,db,events,config,tests}/
│   ├── worker/src/{queues,processors,mqtt,outbox,tests}/
│   └── web/src/{app,features,components,lib}/
├── mobile/src/{features,api,navigation,services,components}/
├── packages/
│   ├── contracts/src/{schemas,events,errors}/
│   ├── clinical-rules/src/{medications,news2,interactions}/
│   └── test-fixtures/
├── services/ai-service/
│   ├── src/{api,adapters,rag,ocr,speech,models,evaluation}/
│   ├── pyproject.toml / uv.lock
│   └── tests/
├── firmware/esp32/{src,include,platformio.ini}
├── database/{prisma,migrations,seeds}/
├── infra/{docker,mqtt,monitoring}/
├── scripts/{simulate,benchmark,seed,restore}/
└── docs/{openapi,adr,runbooks,research}/
```

### 3.1 Bootstrap sequence (proposed commands; create scripts first)

```bash
corepack enable
pnpm install
cp .env.example .env
docker compose up -d postgres redis mqtt minio
pnpm db:migrate
pnpm db:seed:demo
pnpm dev:api
pnpm dev:worker
pnpm dev:web
# Separate terminal
cd services/ai-service && uv sync
uv run uvicorn src.api.main:app --host 127.0.0.1 --port 8000
# Separate terminal
cd mobile && pnpm exec expo start
```

Pin Node, Python and package versions after verifying actual compatibility; lock dependencies and run CI against the selected versions. Web development port 3000, API 4000, AI 8000 (private), MQTT TLS 8883 in deployed environment. Configure Docker DNS when processes are containerized rather than localhost.

```dotenv
APP_ENV=development
DEMO_MODE=true
DATABASE_URL=postgresql://demo:demo@localhost:5432/medishield
REDIS_URL=redis://localhost:6379
MQTT_URL=mqtt://localhost:1883
AI_SERVICE_URL=http://127.0.0.1:8000
OBJECT_STORAGE_ENDPOINT=http://localhost:9000
OBJECT_STORAGE_BUCKET=medishield-demo
JWT_SIGNING_KEY_FILE=/run/secrets/jwt_key
IDENTIFIER_HMAC_KEY_FILE=/run/secrets/id_key
GEMINI_API_KEY=replace_in_secret_manager
CORS_ALLOWED_ORIGINS=http://localhost:3000
# Mobile public configuration only:
EXPO_PUBLIC_API_URL=http://192.168.1.100:4000/api/v1
```

Do not commit `.env`, service keys, model tokens or patient records. Local cleartext ports are for isolated fake-data development only. Add `/health/live`, `/health/ready`, `/metrics` and OpenAPI generation to API scripts. CI: lint → typecheck → unit → migration on fresh DB → integration (actual PostgreSQL, Redis, MQTT) → client builds → security scan → contract diff → staging smoke.

## 4. Authorization and API conventions

**In simple words:** Login tells the server who you are. Authorization checks what you may do and which specific records you may access. Every API must check both. The server returns predictable JSON so all apps can handle success and failure the same way.

### 4.1 Role and object-scope policy

| Role | Allowed activities | Explicit restrictions |
| --- | --- | --- |
| PLATFORM_ADMIN (Super Admin) | Hospital onboarding, platform user status, administrator invitations, service policy and metadata audit | No default clinical access; cannot change clinical records, medical orders or consent |
| HOSPITAL_ADMIN | Staff membership, ward/bed/device metadata, audit administration | No default medication or clinical content access |
| DOCTOR | Assigned encounters: orders, results, discharge, referral, clinical reconciliation | No unrelated patient/tenant access |
| NURSE | Assigned ward/encounter: medication workflow, observations, alerts, handoff | Cannot prescribe or alter orders |
| RECEPTIONIST | Scoped intake, patient identity, queue and operational bed coordination | No clinical notes, prescribing, administration or full longitudinal access by default |
| WARD_STAFF | Assigned operational tasks, bed readiness and device assistance; intake only if separately granted | No medication administration or clinical review by default |
| PATIENT | Own verified portal links, released records, sharing and correction requests | Cannot edit signed clinical records or access other patients |
| CAREGIVER | Released records explicitly granted by patient/authorized representative | No wider access; grant must be active |
| LAB_TECH | Assigned report jobs, field corrections and verification per policy | Cannot prescribe or issue referrals |
| REFERRAL_DOCTOR | Authenticated recipient and active grant; scoped read/RAG | No source-hospital writes or broader search |
| RESEARCHER | De-identified or synthetic approved data and model experiments | No operational clinical access by default |
| DEVICE / SERVICE | Restricted topic, worker job or service-to-service capability | No general human session or broad PHI access |

Use permission strings plus role mapping, account status, hospital status, membership status, facility, ward, encounter, clinical assignment, consent/purpose and grant constraints. Super Admin is the display name for PLATFORM_ADMIN, not a second competing role. Platform sessions have no hospital context; patient sessions use verified portal links, not staff memberships. Every request rechecks live access status and version before sensitive actions. A person with multiple roles selects a context; never union unrelated permissions. `hospitalId` is selected from verified membership, never trusted from arbitrary headers. Return 404 for hidden object existence where appropriate. No public patient search, no bearer QR access to records. Revocation is effective on subsequent requests and subscriptions.

### 4.1A Who can change what?

| Action | Super Admin | Hospital Admin | Reception / ward staff | Doctor / nurse / lab | Patient / caregiver |
| --- | --- | --- | --- | --- | --- |
| Approve/activate hospital; global ban | Yes, reviewed | No | No | No | No |
| Edit hospital business fields | Yes, audited | Local allowlist only | No | No | No |
| Invite staff, assign ward, local suspend | First/replacement admin only | Own hospital | No | No unless dedicated permission | No |
| Register patient and coordinate bed | No | Not by default | Reception/intake authorized | Assigned clinician as allowed | No (account signup is separate) |
| Approve clinical admission | No | No | No | Assigned doctor | No |
| Prescribe / confirm dose | No | No | No | Assigned doctor / authorized nurse respectively | No |
| Verify report / sign discharge | No | No | No | Authorized reviewer / assigned doctor | No |
| View released own records | No by platform role | No by admin role | No by intake role | Assigned clinical access | Verified self or active caregiver grant |
| Request correction / manage sharing | No clinical edit | Authorized workflow only | Intake review only | Authorized clinician/consent reviewer | Own requests and applicable grants |

Roles are not permission shortcuts. Dedicated permissions can be granted only after review, in a narrow scope. Hospital Admin must not use account management to silently expand clinical access. Super Admin may update business and account metadata, not arbitrary patient/clinical data. Patient identity changes use M04, medical amendments use domain-specific clinical APIs and immutable history.

### 4.2 REST contract (applies to all endpoint examples)

An API example has five parts: the method and address, who is allowed to call it, the request, the success response and possible errors. All paths below start with `/api/v1` unless explicitly described as internal or infrastructure paths.

| Method | What it usually does |
| --- | --- |
| GET | Read information. Send filters in the URL, not a JSON body. |
| POST | Create something or request an action. |
| PATCH | Change selected fields. |
| DELETE | Remove or revoke something when the contract allows it. |

| Status | Meaning |
| --- | --- |
| 200 / 201 / 202 | Successful / created / job accepted but not finished. |
| 204 | Successful with no response body. |
| 400 / 422 | Request format or supplied data is invalid. |
| 401 / 403 | Not logged in / not allowed. |
| 404 / 410 | Record is missing or hidden / link or resource expired where disclosure is allowed. |
| 409 | Conflict, e.g. someone already reserved the dose. |
| 413 / 415 | File too large / file type not supported. |
| 429 / 503 | Too many requests / service unavailable. |

Most examples show only the `data` part of the response. Here is how a complete normal API response looks (the `/health/live` data example is used for illustration):

```json
{
  "data": { "status": "ok" },
  "meta": { "requestId": "req_01" }
}
```

For an authenticated mobile request, send `Authorization: Bearer <access_token>`. Where required, send a unique `Idempotency-Key` header as well. If a network request fails, retry the same logical request with the same key only as allowed by its contract; never repeat a physical action because a request timed out.

- Base: `/api/v1`; JSON UTF-8; UTC RFC3339 timestamps; IDs are opaque UUIDs in deployed schema. Readable `pat_01`, `enc_01`, etc. below are synthetic aliases only; fixtures map them to UUIDs. Numeric medical quantities carry units; dosage amounts use decimal strings.
- Bearer access token for native clients (short-lived); web may use secure HttpOnly session cookies + CSRF protection. Refresh token rotation, device/session revoke, rate limits and MFA for sensitive roles. Device/service auth uses separate identities.
- Success body: `{"data": <example>, "meta": {"requestId": "req_01"}}`. Every endpoint below shows `data` unless noted; 204 has no body. List data uses `{"items": [], "nextCursor": null}`. Error uses the full envelope below.
- Mutations accept `Idempotency-Key` UUID header where indicated or globally for safety/queued operations. Persist tenant + actor + route + key + canonical payload hash + status/result atomically with writes. Same key/payload returns original status/data; mismatch 409. Sensitive token issuance uses encrypted short-lived replay result or requires explicit replacement. Never store secrets in plaintext logs.
- Optimistic version on editable records (`expectedVersion` integer in body); conflict 409. Paths determine resource; do not allow conflicting body IDs. Query pagination `limit` default 25/max 100 and opaque cursor. Dates use inclusive `from`, exclusive `to` with bounded windows.
- Validate unknown fields, lengths, enums, units, uploaded types, range and relationships using Zod; internal AI contracts use Pydantic. Public contracts generated to OpenAPI, shared TS types and Python contract tests. Register static routes such as `/staff/invitations`, `/beds/availability`, `/medication-dose-events/review-queue` before parameter routes such as `/medication-dose-events/{doseEventId}` in Express. Optional field omitted unless nullable explicitly shown. All examples use synthetic non-actionable data.
- Standard statuses: 200 read/update/action, 201 create, 202 accepted job, 204 revoke/logout if specified, 400 malformed request, 401 unauthenticated, 403 forbidden, 404 missing/hidden, 409 conflict, 410 expired/revoked resource (only where scope permits disclosure), 413 too large, 415 unsupported media, 422 validation, 429 throttle, 503 dependency unavailable. Return `Retry-After` when applicable; never automatically repeat a physical action after 503.

```json
{
  "error": {
    "code": "DOSE_ALREADY_RESERVED",
    "message": "Dose is not available for electronic administration.",
    "details": {"doseEventId":"dose_01", "status":"RESERVED"},
    "retryable": false
  },
  "meta": {"requestId":"req_01"}
}
```

Error detail is scope-filtered; generic errors must not disclose patient names, other staff identities or records. Clients use stable machine codes, not message text. All list endpoints return only authorized objects; `GET` has no body. API returns `Cache-Control: no-store` for clinical content.

## 5. Database design and invariants

**In simple words:** Think of each database table as a sheet that stores one type of information. IDs connect related tables, such as a patient to their admissions and a prescription to its dose tasks. PostgreSQL is the final authority for medication state. Database constraints prevent duplicates even if two requests arrive together.

### 5.1 Relational schema inventory

All tenant-owned tables include `hospital_id`, UUID primary key, creation time, relevant actor, version when mutable, foreign keys and tenant-scoped indexes. Global `patients` identity is not globally discoverable; use `hospital_patient_links` and separately authorized sharing. Prefer composite `(hospital_id,id)` foreign keys to prevent cross-tenant linkage. Use `timestamptz`, `numeric` quantities and constrained enums. Do not cascade-delete finalized clinical records.

| Table | Key fields and constraints |
| --- | --- |
| hospitals | unique immutable code, display name, business contact, timezone, lifecycle status, access_version, version; no medical content |
| hospital_applications, onboarding_documents, onboarding_reviews | application, private evidence refs, review actor/reason/status, timestamps; one open application per normalized business reference where applicable |
| platform_role_assignments, platform_settings, moderation_actions | user, role, policy version, target, status, reason, reviewer, effective time; append-only status history |
| invitations, credential_reviews, access_requests | role scope, token digest, expiry, verified recipient, review status, one-use acceptance |
| departments, wards, beds | tenant hierarchy; unique department/ward codes and bed label within ward; active flag and bed readiness |
| reception_queue, ward_tasks | tenant, patient link/encounter if applicable, status, assignee, reason, version; no clinical treatment authorization |
| patient_portal_links, portal_link_requests | user, patient link, hospital, verification state, proof ref, reviewer, revocation; active link uniqueness per user and patient link; no competing self links without review |
| caregiver_grants, record_releases, correction_requests | verified subject, recipient, allowed record IDs/types, expiry, status, audit; signed source record unchanged by correction request |
| auth_challenges, password_reset_tokens, mfa_credentials | one-time digests, expiry, attempt count, purpose and account; secrets encrypted or hashed as appropriate |
| users, memberships, sessions | normalized unique login; role, tenant, status, hashed refresh, expiry; MFA policy |
| care_assignments | staff, ward/encounter, validity interval; active membership required |
| patients, hospital_patient_links | synthetic patient ID, demographics, link/MRN unique per tenant, identity verification status |
| patient_identifiers | type, keyed digest, last4, key version, verification state; unique digest in approved matching scope; no raw Aadhaar |
| consents | patient, tenant, purpose, scope, recipient, status, expiry, provenance; append revocation |
| admissions, bed_assignments | encounter status, doctor, start/end; partial unique index for active bed assignment; one active bed per encounter |
| wristbands | encounter, random token digest, expiry, revoked_at; one active band per encounter |
| allergies | patient, substance coding, reaction, verification status, source, revision; unknown distinct from none known |
| medication_catalog, product_barcodes | product, coding, strength, form, barcode; unique active barcode mapping, version |
| medication_orders, medication_order_revisions | encounter, prescriber, coded drug, dose/unit/route, schedule, effective window, status, immutable revisions |
| medication_dose_events | order revision, encounter, due_at, state, reservation owner/hash/expiry, started_at, version; unique `(order_revision_id, occurrence_key)` |
| medication_administration_records | dose_event, outcome, actor, timestamps, source, rationale; one confirmed final administration per dose; amendments linked |
| dose_reconciliations | dose, evidence refs, reviewer, resolution, second approval if policy requires; append-only |
| interaction_rule_versions, interaction_checks | source/version, severity, inputs hash, coverage, result, override/review reason |
| observations | encounter, coded observation, value/unit, observed_at, quality, provenance, revision, verification status |
| devices, device_credentials, device_assignments | device serial, credential ref, status; assignment validity; no overlapping binding |
| telemetry_samples | time, device, boot_id, sequence, assignment, metric values/quality; unique includes time partition key; separate ingest dedupe ledger |
| ecg_artifacts | encounter/device, sample rate, lead config, object key, quality and checksum |
| news2_assessments | encounter, input observation refs, rule version, missing fields, status, score nullable, timestamp |
| alerts, alert_actions | fingerprint, episode, severity, owner, status, escalation schedule; dedupe active episode, append action trail |
| notification_deliveries | alert, channel, recipient ref, delivery attempt, provider id, status; unique logical delivery key |
| shifts, handoffs, handoff_items | ward, outgoing/incoming users, snapshot cutoff, state, signed versions, outstanding item refs |
| objects, clinical_reports, report_fields | private file metadata/checksum, type, pipeline status, extraction versions, candidate and reviewed value, evidence locator |
| voice_jobs, clinical_notes | recording ref, transcript, extracted draft, reviewer, encounter, version, final status |
| timeline_events, discharge_summaries | encounter, source ref/revision, event time, verification, signed summary revision |
| referrals, referral_grants, referral_sessions | patient, encounter, recipient org, permitted scope, token digest, expiry, revoked_at; separate recipient session |
| rag_documents, rag_chunks, rag_queries | source/version, tenant, patient, consent tags, verified status, vector, citations, retrieval/model version; no cross-patient index query |
| model_registry, inference_jobs, inference_reviews | model ID/version, task, intended use, artifact hash, input refs, quality/OOD status, reviewer, output draft |
| advisory_jobs, advisory_reviews | input refs, rule/model version, evidence, limitations, review status |
| audit_events, idempotency_records, outbox_events | append-only audit; unique replay key; durable unpublished event and attempts |
| sync_operations | device/client op UUID, actor, encounter, payload hash, disposition and result ref |

```mermaid
erDiagram
  HOSPITAL ||--o{ WARD : contains
  WARD ||--o{ BED : contains
  PATIENT ||--o{ ADMISSION : has
  HOSPITAL ||--o{ ADMISSION : hosts
  ADMISSION ||--o{ MEDICATION_ORDER : has
  MEDICATION_ORDER ||--o{ DOSE_EVENT : schedules
  DOSE_EVENT ||--o{ ADMINISTRATION_RECORD : records
  ADMISSION ||--o{ DEVICE_ASSIGNMENT : binds
  DEVICE ||--o{ DEVICE_ASSIGNMENT : assigned
  ADMISSION ||--o{ OBSERVATION : captures
  ADMISSION ||--o{ ALERT : raises
  ADMISSION ||--o{ CLINICAL_REPORT : contains
  ADMISSION ||--o{ REFERRAL : creates
  REFERRAL ||--o{ REFERRAL_GRANT : authorizes
  CLINICAL_REPORT ||--o{ RAG_CHUNK : indexes
```

### 5.2 Migration order and indexes

1. Extensions (pgvector; Timescale only on supported deployment); users, platform roles, sessions, hospital applications, hospitals, invitations, memberships, department/ward/bed structure and access history.
2. Patients/consent → portal link requests/links and caregiver grants → reception queue → admissions/bed assignments → ward tasks/wristbands/allergies. Add record releases and correction requests after their referenced record tables exist.
3. Catalog → orders/revisions → dose events → administration/reconciliation → audit/outbox/idempotency.
4. Observations → devices/assignments → telemetry/dedupe → assessments/alerts/actions/deliveries.
5. Shifts/handoff → private objects/reports/fields → notes → timeline/discharge → referral → vector → registry/advisories.
6. Add indexes: tenant/status/due time for medication tasks; encounter/time for timeline; device/time telemetry; alert/next escalation; grant digest/expiry; tenant/patient/source verification filters for RAG. Run `EXPLAIN ANALYZE` on synthetic workloads; vector ANN only after verifying scoped recall. Avoid putting PHI in migration logs.

### 5.2A Additional constraints for platform and portal

- Unique hospital code and one provisioned hospital per approved application; application state and provisioning locked in one transaction.
- Unique active staff membership per user/hospital/role policy; role transitions are versioned. Protect last active approved platform and hospital admin with a serialized transaction, not an unlocked count.
- Store invitation/reset/challenge hashes, expiry, consumed timestamp, verified recipient and attempt limit. No public account enumeration. Session refresh token family and account/hospital/membership access versions checked on each sensitive request.
- Portal link foreign key points to the hospital patient link, not just a free-text patient ID. Release references an exact verified source revision; access policy applies to every metadata and download request. Grant expiry is checked at access time, not only scheduled cleanup.
- Operational queue/admission decisions must reference the same hospital, patient and queue item; an admission decision is consumed once. Occupancy comes from active bed assignment; readiness cannot bypass the active-bed uniqueness constraint.
- Moderation transaction writes audit and outbox with target and reason; revoke access even if notification delivery fails. Workers may retain audit evidence but must not expose clinical content to platform admin.

### 5.3 Critical SQL invariants (illustrative, align with migration names)

```sql
CREATE UNIQUE INDEX uq_dose_occurrence ON medication_dose_events
  (order_revision_id, occurrence_key);
CREATE UNIQUE INDEX uq_confirmed_admin ON medication_administration_records
  (dose_event_id) WHERE outcome = 'ADMINISTERED' AND superseded_at IS NULL;
CREATE UNIQUE INDEX uq_active_bed ON bed_assignments
  (hospital_id, bed_id) WHERE ended_at IS NULL;
CREATE UNIQUE INDEX uq_active_encounter_bed ON bed_assignments
  (hospital_id, admission_id) WHERE ended_at IS NULL;
```

Never release a potentially administered dose automatically. Use consistent lock order (admission → order → dose) in every related transaction. No external network calls inside transactions. Store audit and outbox records in the same transaction. PostgreSQL is authoritative even when Redis is down. Keep immutable corrections rather than rewriting history; database restrictions and service permissions should enforce transitions in addition to application checks.

## 6. Module-by-module implementation and API contracts

**In simple words:** Build the following 20 modules in dependency order. Every module has a goal, simple steps, checks for completion, and exact API examples. The expandable notes are for developers implementing the details.

Each module specifies dependency, owner, build steps, screens/services, endpoint examples and acceptance tests. Endpoints are a proposed v1 contract; implement and validate one module at a time. All examples are `data` payloads inside the success envelope in section 4, except raw file/health responses explicitly noted. `Auth` below is minimum role/capability, plus object-scope policy. IDs and timestamps are sample aliases, not production values.

### M01 — Foundation, health and contract infrastructure

**Dependencies:** None  
**Owner:** Abhishek  
**Status:** Planned

**In simple words — Set up the project:** Prepare a common working environment so the team can run all parts of the project on their own computers.

#### Implementation steps

1. Create the folders for the mobile app, website, backend, AI service and IoT code.
2. Start PostgreSQL, Redis and the MQTT broker using Docker.
3. Set up the API with input checks, a common error format and safe logs.
4. Add test users and fake patient data. Add health-check APIs so we know which services are running.
5. Set up automatic code checks and document how to start the project.

**How to know this module is working:** A new team member can run the project from a clean checkout, and the API reports if the database is unavailable.

<details>
<summary>Exact engineering steps and acceptance tests (developer reference)</summary>

1. Initialize workspace, configure lint/typecheck, environment schema, Docker Compose and separate service users.
2. Implement central request ID, safe logger, Zod validation, error handler, rate limiter and OpenAPI exporter.
3. Add readiness checks for database and critical dependencies; distinguish optional AI outage from core API outage.
4. Seed deterministic synthetic fixtures, test migrations and document local commands.
5. Establish CI, branch protections, migration review, secret scanning and feature flags.

**Acceptance criteria:** Fresh environment starts; invalid environment fails fast; no secrets in logs; readiness reflects DB failure; OpenAPI snapshot generated.

</details>

#### API contracts

##### M01.01 — `GET /health/live`

**Authorization:** Public minimal  
**Success:** HTTP 200

**Request:**

None

**Response (data):**

```json
{
  "status": "ok"
}
```

**Errors / constraints:** No internal dependency details.

##### M01.02 — `GET /health/ready`

**Authorization:** Internal deployment probe  
**Success:** HTTP 200

**Request:**

None

**Response (data):**

```json
{
  "status": "ready",
  "database": "ready",
  "worker": "ready",
  "ai": "degraded"
}
```

**Errors / constraints:** 503 NOT_READY when authoritative database unavailable.

##### M01.03 — `GET /openapi.json`

**Authorization:** Developer/internal  
**Success:** HTTP 200

**Request:**

None

**Response (data):**

Raw OpenAPI document (generated from validated contracts).

**Errors / constraints:** 404 in public production mode if disabled.

### M02 — Authentication, sessions and RBAC

**Dependencies:** M01  
**Owner:** Abhishek  
**Status:** Planned

**In simple words — Login and user permissions:** Make sure each person can log in and only see or change the records they are allowed to access.

#### Implementation steps

1. Create accounts, hospital memberships, patient assignments and login sessions.
2. Add login, logout and token refresh. Protect important accounts with MFA (a second login check).
3. Check the user’s role AND their hospital, ward or patient assignment on every request.
4. Store login tokens safely on mobile and protect website sessions.
5. Record login and permission changes in the audit log.

**How to know this module is working:** A nurse cannot prescribe or access another hospital; old or revoked sessions cannot be reused.

<details>
<summary>Exact engineering steps and acceptance tests (developer reference)</summary>

1. Create users, memberships, care assignments and sessions; use established auth library or managed identity, Argon2id for local passwords.
2. Add login, refresh rotation with replay detection, logout and membership selection; enforce MFA for privileged users, short access-token lifetime and session revocation.
3. Implement authorize(permission, resource) and DB tenant filters; deny by default.
4. Build web login and mobile secure token storage; web cookie sessions need CSRF.
5. Add audit for authentication and privilege changes; use fake users seeded locally.

**Acceptance criteria:** Wrong credentials generic; expired/replayed refresh rejected; cross-hospital access blocked; disabled membership invalidates active sessions.

</details>

#### API contracts

##### M02.01 — `POST /auth/login`

**Authorization:** Public rate-limited  
**Success:** HTTP 200

**Request:**

```json
{
  "email": "nurse@example.test",
  "password": "demo-only-password",
  "hospitalId": "hosp_01"
}
```

**Response (data):**

```json
{
  "accessToken": "<access>",
  "refreshToken": "<refresh>",
  "expiresIn": 900,
  "user": {
    "id": "usr_01",
    "role": "NURSE",
    "hospitalId": "hosp_01"
  }
}
```

**Errors / constraints:** 401 INVALID_CREDENTIALS; 403 MEMBERSHIP_INACTIVE, ACCOUNT_INACTIVE or HOSPITAL_INACTIVE; MFA_REQUIRED flow as below. Staff login includes hospitalId; platform and patient login omit hospitalId and select an explicit account context (add `contextType`: PLATFORM, STAFF or PATIENT). During setup only approved setup permissions are returned. Patient account may log in with zero links; never infer hospital staff membership.

##### M02.02 — `POST /auth/mfa/verify`

**Authorization:** Short-lived auth challenge  
**Success:** HTTP 200

**Request:**

```json
{
  "challengeId": "mfa_01",
  "code": "<one-time-code>"
}
```

**Response (data):**

```json
{
  "accessToken": "<access>",
  "refreshToken": "<refresh>",
  "expiresIn": 900
}
```

**Errors / constraints:** 401 INVALID_CHALLENGE; 429 RATE_LIMITED. Login requiring MFA returns 200 data {status:MFA_REQUIRED,challengeId} without access token.

##### M02.03 — `POST /auth/refresh`

**Authorization:** Refresh credential  
**Success:** HTTP 200

**Request:**

```json
{
  "refreshToken": "<refresh>"
}
```

**Response (data):**

```json
{
  "accessToken": "<new-access>",
  "refreshToken": "<new-refresh>",
  "expiresIn": 900
}
```

**Errors / constraints:** 401 REFRESH_REUSED or SESSION_EXPIRED; revoke token family on replay. Recheck current account, context, membership and hospital status on every refresh; never refresh a banned or revoked account.

##### M02.04 — `POST /auth/logout`

**Authorization:** Authenticated  
**Success:** HTTP 204

**Request:**

```json
{
  "refreshToken": "<refresh>"
}
```

**Response (data):**

No body.

**Errors / constraints:** 401 UNAUTHENTICATED.

##### M02.05 — `GET /auth/me`

**Authorization:** Authenticated  
**Success:** HTTP 200

**Request:**

None

**Response (data):**

```json
{
  "id": "usr_01",
  "hospitalId": "hosp_01",
  "role": "NURSE",
  "permissions": [
    "dose:reserve",
    "observation:create"
  ]
}
```

**Errors / constraints:** 403 MEMBERSHIP_INACTIVE.

##### M02.06 — `POST /auth/switch-hospital`

**Authorization:** Authenticated  
**Success:** HTTP 200

**Request:**

```json
{
  "hospitalId": "hosp_02"
}
```

**Response (data):**

```json
{
  "accessToken": "<access>",
  "refreshToken": "<refresh>",
  "expiresIn": 900
}
```

**Errors / constraints:** 403 MEMBERSHIP_REQUIRED; rotate selected session.

### M02A — Super Admin, hospital onboarding and platform management

**Dependencies:** M01–M02. **Owner:** Abhishek. **Status:** New proposed module.

**Goal:** One platform can serve multiple hospitals without mixing their data. The Super Admin manages the platform and accounts, not patients' treatment.

#### Build steps — from empty database to active hospital

1. Create the first PLATFORM_ADMIN using a one-time deployment CLI and a secret from the deployment secret store. No public super admin signup, default password or hardcoded credentials. Enroll MFA and disable bootstrap after first success. Audit it. Subsequent admins require independent approval; arrange a controlled out-of-band recovery process for the initial sole admin.
2. Build the Super Admin login and dashboard. Separate global platform routes from hospital routes. Platform accounts have no default patient query permission.
3. Build the hospital application form: legal/business name, contact, address/city, timezone, reference and private verification evidence. Use synthetic documents for demos. Save as draft. Verify uploaded documents and review decision. Request changes or reject with reason; never auto-approve an application just because a file was uploaded.
4. After approval use M03.01 to provision one tenant in SETUP_PENDING. Generate unique hospital code; the transaction creates default settings, audit and outbox. An idempotent retry cannot create another hospital.
5. Invite the first Hospital Admin through the verified email channel. The recipient verifies identity, enrolls MFA and waits for platform approval. An active admin membership can access setup only until hospital activation.
6. Hospital Admin creates departments, wards, beds and staff. Super Admin reviews setup checklist and activates hospital. Setup staff cannot access clinical APIs before activation.
7. Build platform list/detail/edit screens for hospitals and accounts, filters, audit history and status actions. Use version checks and reason fields. Never allow a generic PATCH to grant a role, bypass verification, edit patient records or change signed medical data.
8. Implement global account suspension/ban and tenant restrictions. Separate permanent login ban from hospital membership suspension. Before routine restrictions, arrange task reassignment and clinical continuity; for urgent compromise, revoke immediately and notify authorized supervisors to reconcile care. Never auto-cancel medication orders, discharge patients or assume a started dose was not administered.
9. On status/permission change, update DB state, increment access version, revoke relevant sessions, publish outbox event, disconnect sockets, invalidate caches and deny stale token use on every API. Recheck access in worker and download endpoints. Sensitive mutations serialize authorization and state change against revocation; do not rely only on JWT expiry or a socket event.
10. Restore only after reviewed reason. New login required. Never restore revoked grants automatically. Archive hospital only after reviewed continuity, retention, export and open obligation checks. Keep audit/clinical records intact.

#### Lifecycle rules

| Object | States and allowed movement |
| --- | --- |
| Hospital application | DRAFT → UNDER_REVIEW → APPROVED / CHANGES_REQUESTED / REJECTED; changes requested → DRAFT or resubmission; rejected requires new reviewed application |
| Hospital | SETUP_PENDING → ACTIVE → RESTRICTED / SUSPENDED → ACTIVE after review; ARCHIVED terminal after safe offboarding |
| User account | PENDING_VERIFICATION → ACTIVE → SUSPENDED / BANNED → ACTIVE only after review; password reset cannot clear ban |
| Staff membership | INVITED → PENDING_REVIEW → ACTIVE → SUSPENDED / REMOVED; restore only after verification; removed needs new invitation |
| Admin invitation | PENDING → ACCEPTED / EXPIRED / REVOKED; acceptance is atomic and recipient-bound |

Global ban blocks all ordinary login contexts, including patient portal. It does not end the patient's care or extinguish legitimate records access requests through an authorized independent channel. Hospital membership suspension affects only that hospital. Restricted hospital allows only explicitly authorized safe incident/recovery or continuity routes; suspended hospital blocks ordinary access; do not use platform admin as a clinical bypass. Establish independent institutional downtime and emergency contact procedures before any actual deployment. For prototype use, simulate incident actions and show task reconciliation, never affect real patients.

#### Permission enforcement example

```text
Authenticate session → check global account ACTIVE → check requested context
  PLATFORM: platform role + action permission + recent MFA where required
  STAFF: hospital status + active membership + role + assignment + object scope
  PATIENT: verified portal link + active grant if caregiver + release + purpose
  REFERRAL: authenticated receiving clinician + active recipient/grant + exact scope
  DEVICE: active credential + assigned hospital/device + topic scope
  Otherwise: DENY
```

#### API contracts

All mutations below require an idempotency key for retryable actions, audit, and a current version for mutable state; all use the shared response envelope in section 4. API provisioning `POST /hospitals` is M03.01, not duplicated here.

##### M02A.01 — `GET /platform/dashboard`

**Who can use it:** PLATFORM_ADMIN with matching permission and recent MFA  
**Success:** HTTP 200

**Request:**

None — no request body.

**Response (data):**

```json
{
  "hospitals": {
    "pending": 2,
    "active": 3,
    "restricted": 1
  },
  "users": {
    "active": 42,
    "banned": 1
  },
  "openReviews": 2
}
```

**Errors / rules:** 403 FORBIDDEN

**How it works:** Return aggregate operational metrics only; suppress sensitive small-cell breakdowns.

##### M02A.02 — `POST /platform/hospital-applications`

**Who can use it:** PLATFORM_ADMIN with matching permission and recent MFA  
**Success:** HTTP 201

**Request:**

```json
{
  "legalName": "Demo Hospital",
  "businessReference": "DEMO-REG-01",
  "contactEmail": "admin@example.test",
  "city": "Demo City",
  "timezone": "Asia/Kolkata"
}
```

**Response (data):**

```json
{
  "id": "hap_01",
  "status": "DRAFT",
  "version": 1
}
```

**Errors / rules:** 409 DUPLICATE_APPLICATION; 422 INVALID_CONTACT

**How it works:** Create an application; no hospital access yet.

##### M02A.03 — `GET /platform/hospital-applications`

**Who can use it:** PLATFORM_ADMIN with matching permission and recent MFA  
**Success:** HTTP 200

**Request:**

Query: status?, q?, cursor?, limit?

**Response (data):**

```json
{
  "items": [
    {
      "id": "hap_01",
      "legalName": "Demo Hospital",
      "status": "DRAFT",
      "version": 1
    }
  ],
  "nextCursor": null
}
```

**Errors / rules:** 403 FORBIDDEN

**How it works:** Search business metadata only.

##### M02A.04 — `GET /platform/hospital-applications/{applicationId}`

**Who can use it:** PLATFORM_ADMIN with matching permission and recent MFA  
**Success:** HTTP 200

**Request:**

None — no request body.

**Response (data):**

```json
{
  "id": "hap_01",
  "legalName": "Demo Hospital",
  "status": "DRAFT",
  "documents": [],
  "version": 1
}
```

**Errors / rules:** 404 APPLICATION_NOT_FOUND

**How it works:** Check the actor and resource scope, validate inputs, perform the action, and record the outcome where required.

##### M02A.05 — `PATCH /platform/hospital-applications/{applicationId}`

**Who can use it:** PLATFORM_ADMIN with matching permission and recent MFA  
**Success:** HTTP 200

**Request:**

```json
{
  "contactEmail": "admin2@example.test",
  "expectedVersion": 1,
  "reason": "Correct contact"
}
```

**Response (data):**

```json
{
  "id": "hap_01",
  "status": "DRAFT",
  "version": 2
}
```

**Errors / rules:** 409 VERSION_CONFLICT or APPLICATION_LOCKED

**How it works:** Only edit draft or changes-requested business fields; preserve earlier versions.

##### M02A.06 — `POST /platform/hospital-applications/{applicationId}/documents`

**Who can use it:** PLATFORM_ADMIN with matching permission and recent MFA  
**Success:** HTTP 202

**Request:**

Multipart: file, documentType=DEMO_REGISTRATION, expectedVersion=2

**Response (data):**

```json
{
  "documentId": "hdoc_01",
  "scanStatus": "PENDING",
  "applicationVersion": 3
}
```

**Errors / rules:** 413 FILE_TOO_LARGE; 415 UNSUPPORTED_MEDIA; 409 VERSION_CONFLICT

**How it works:** Private non-clinical upload, quarantine, checksum and malware scan.

##### M02A.07 — `POST /platform/hospital-applications/{applicationId}/submit`

**Who can use it:** PLATFORM_ADMIN with matching permission and recent MFA  
**Success:** HTTP 200

**Request:**

```json
{
  "expectedVersion": 3
}
```

**Response (data):**

```json
{
  "id": "hap_01",
  "status": "UNDER_REVIEW",
  "version": 4
}
```

**Errors / rules:** 422 APPLICATION_INCOMPLETE; 409 DOCUMENT_SCAN_PENDING

**How it works:** Freeze submitted evidence and create review task.

##### M02A.08 — `POST /platform/hospital-applications/{applicationId}/review`

**Who can use it:** PLATFORM_ADMIN with matching permission and recent MFA  
**Success:** HTTP 200

**Request:**

```json
{
  "decision": "APPROVE",
  "reason": "Demo documents reviewed",
  "expectedVersion": 4
}
```

**Response (data):**

```json
{
  "id": "hap_01",
  "status": "APPROVED",
  "version": 5
}
```

**Errors / rules:** 409 VERSION_CONFLICT; 403 REVIEWER_CONFLICT

**How it works:** Other decisions: REQUEST_CHANGES, REJECT. Require separate reviewer for production; record who reviewed which evidence.

##### M02A.09 — `GET /platform/hospitals`

**Who can use it:** PLATFORM_ADMIN with matching permission and recent MFA  
**Success:** HTTP 200

**Request:**

Query: status?, q?, cursor?, limit?

**Response (data):**

```json
{
  "items": [
    {
      "id": "hosp_01",
      "name": "Demo Hospital",
      "status": "SETUP_PENDING",
      "version": 1
    }
  ],
  "nextCursor": null
}
```

**Errors / rules:** 403 FORBIDDEN

**How it works:** Check the actor and resource scope, validate inputs, perform the action, and record the outcome where required.

##### M02A.10 — `GET /platform/hospitals/{hospitalId}`

**Who can use it:** PLATFORM_ADMIN with matching permission and recent MFA  
**Success:** HTTP 200

**Request:**

None — no request body.

**Response (data):**

```json
{
  "id": "hosp_01",
  "name": "Demo Hospital",
  "status": "SETUP_PENDING",
  "setup": {
    "adminVerified": false,
    "wardReady": false
  },
  "version": 1
}
```

**Errors / rules:** 404 HOSPITAL_NOT_FOUND

**How it works:** Check the actor and resource scope, validate inputs, perform the action, and record the outcome where required.

##### M02A.11 — `PATCH /platform/hospitals/{hospitalId}`

**Who can use it:** PLATFORM_ADMIN with matching permission and recent MFA  
**Success:** HTTP 200

**Request:**

```json
{
  "name": "Demo Hospital North",
  "contactEmail": "admin@example.test",
  "expectedVersion": 1,
  "reason": "Correct business profile"
}
```

**Response (data):**

```json
{
  "id": "hosp_01",
  "version": 2
}
```

**Errors / rules:** 409 VERSION_CONFLICT; 422 FIELD_NOT_EDITABLE

**How it works:** Allow business metadata only. Never accept clinical data or lifecycle status on generic PATCH.

##### M02A.12 — `POST /platform/hospitals/{hospitalId}/admin-invitations`

**Who can use it:** PLATFORM_ADMIN with matching permission and recent MFA  
**Success:** HTTP 201

**Request:**

```json
{
  "email": "admin@example.test",
  "displayName": "Demo Admin"
}
```

**Response (data):**

```json
{
  "id": "inv_admin_01",
  "status": "PENDING",
  "expiresAt": "2026-12-02T00:00:00Z"
}
```

**Errors / rules:** 409 ADMIN_INVITATION_EXISTS; 422 HOSPITAL_INELIGIBLE

**How it works:** Send single-use token to verified email channel; no plaintext token in logs.

##### M02A.13 — `POST /platform/admin-invitations/accept`

**Who can use it:** Verified invitation holder  
**Success:** HTTP 200

**Request:**

```json
{
  "token": "<one-use-token>"
}
```

**Response (data):**

```json
{
  "membershipId": "mem_admin_01",
  "status": "PENDING_REVIEW"
}
```

**Errors / rules:** 410 INVITATION_EXPIRED; 409 INVITATION_USED; 403 RECIPIENT_MISMATCH

**How it works:** Bind verified user account, require MFA enrollment, then wait for platform review.

##### M02A.14 — `POST /platform/hospitals/{hospitalId}/admin-memberships/{membershipId}/review`

**Who can use it:** PLATFORM_ADMIN with matching permission and recent MFA  
**Success:** HTTP 200

**Request:**

```json
{
  "decision": "APPROVE",
  "reason": "Identity and authority verified",
  "expectedVersion": 1
}
```

**Response (data):**

```json
{
  "membershipId": "mem_admin_01",
  "status": "ACTIVE",
  "version": 2
}
```

**Errors / rules:** 409 VERSION_CONFLICT; 422 MFA_OR_VERIFICATION_REQUIRED

**How it works:** Permit only setup operations while hospital is SETUP_PENDING.

##### M02A.15 — `POST /platform/hospitals/{hospitalId}/activate`

**Who can use it:** PLATFORM_ADMIN with matching permission and recent MFA  
**Success:** HTTP 200

**Request:**

```json
{
  "expectedVersion": 2,
  "reason": "Setup checklist complete"
}
```

**Response (data):**

```json
{
  "id": "hosp_01",
  "status": "ACTIVE",
  "version": 3
}
```

**Errors / rules:** 409 SETUP_INCOMPLETE; 409 VERSION_CONFLICT

**How it works:** Check approved application, active verified admin, configured wards/bed where applicable, approved policies, audit and downtime drill.

##### M02A.16 — `POST /platform/hospitals/{hospitalId}/restrictions`

**Who can use it:** PLATFORM_ADMIN with matching permission and recent MFA  
**Success:** HTTP 200

**Request:**

```json
{
  "action": "RESTRICT",
  "reason": "Demo security incident",
  "expectedVersion": 3
}
```

**Response (data):**

```json
{
  "id": "hosp_01",
  "status": "RESTRICTED",
  "version": 4,
  "reviewTaskId": "rev_01"
}
```

**Errors / rules:** 409 VERSION_CONFLICT; 422 REASON_REQUIRED

**How it works:** RESTRICT blocks affected normal writes; SUSPEND blocks routine tenant sessions; both require safe continuity/incident handling below. Never delete clinical history.

##### M02A.17 — `POST /platform/hospitals/{hospitalId}/restore`

**Who can use it:** PLATFORM_ADMIN with matching permission and recent MFA  
**Success:** HTTP 200

**Request:**

```json
{
  "expectedVersion": 4,
  "reason": "Incident reviewed",
  "reviewId": "rev_01"
}
```

**Response (data):**

```json
{
  "id": "hosp_01",
  "status": "ACTIVE",
  "version": 5
}
```

**Errors / rules:** 409 REVIEW_NOT_COMPLETE; 409 VERSION_CONFLICT

**How it works:** Confirm security and clinical continuity readiness; do not revive old sessions or grants.

##### M02A.18 — `POST /platform/hospitals/{hospitalId}/archive`

**Who can use it:** PLATFORM_ADMIN with matching permission and recent MFA  
**Success:** HTTP 200

**Request:**

```json
{
  "expectedVersion": 5,
  "reason": "Hospital offboarding complete",
  "reviewId": "rev_close_01"
}
```

**Response (data):**

```json
{
  "id": "hosp_01",
  "status": "ARCHIVED",
  "version": 6
}
```

**Errors / rules:** 409 ACTIVE_CARE_OR_RETENTION_HOLD; 409 REVIEW_NOT_COMPLETE

**How it works:** Check no unresolved active care or referral obligations and documented retention/export plan; archive is not deletion.

##### M02A.19 — `GET /platform/users`

**Who can use it:** PLATFORM_ADMIN with matching permission and recent MFA  
**Success:** HTTP 200

**Request:**

Query: role?, accountStatus?, hospitalId?, q?, cursor?, limit?

**Response (data):**

```json
{
  "items": [
    {
      "id": "usr_01",
      "displayName": "Demo Nurse",
      "accountStatus": "ACTIVE",
      "version": 1
    }
  ],
  "nextCursor": null
}
```

**Errors / rules:** 403 FORBIDDEN

**How it works:** Search login/business metadata only, no patient history.

##### M02A.20 — `GET /platform/users/{userId}`

**Who can use it:** PLATFORM_ADMIN with matching permission and recent MFA  
**Success:** HTTP 200

**Request:**

None — no request body.

**Response (data):**

```json
{
  "id": "usr_01",
  "displayName": "Demo Nurse",
  "accountStatus": "ACTIVE",
  "memberships": [
    {
      "hospitalId": "hosp_01",
      "role": "NURSE",
      "status": "ACTIVE"
    }
  ],
  "version": 1
}
```

**Errors / rules:** 404 USER_NOT_FOUND

**How it works:** Check the actor and resource scope, validate inputs, perform the action, and record the outcome where required.

##### M02A.21 — `PATCH /platform/users/{userId}`

**Who can use it:** PLATFORM_ADMIN with matching permission and recent MFA  
**Success:** HTTP 200

**Request:**

```json
{
  "displayName": "Demo Staff",
  "expectedVersion": 1,
  "reason": "Correct account name"
}
```

**Response (data):**

```json
{
  "id": "usr_01",
  "version": 2
}
```

**Errors / rules:** 409 VERSION_CONFLICT; 422 FIELD_NOT_EDITABLE

**How it works:** Allow non-clinical account metadata only; verified email change uses separate identity challenge.

##### M02A.22 — `POST /platform/users/{userId}/moderation`

**Who can use it:** PLATFORM_ADMIN with matching permission and recent MFA  
**Success:** HTTP 200

**Request:**

```json
{
  "action": "BAN",
  "reason": "Confirmed account misuse",
  "expectedVersion": 2
}
```

**Response (data):**

```json
{
  "id": "usr_01",
  "accountStatus": "BANNED",
  "version": 3,
  "actionId": "mod_01"
}
```

**Errors / rules:** 409 LAST_SUPER_ADMIN or VERSION_CONFLICT; 403 SELF_MODERATION_DENIED

**How it works:** SUSPEND or BAN globally, revoke sessions and socket access; preserve staff/patient records and route open tasks to supervisor.

##### M02A.23 — `POST /platform/users/{userId}/restore`

**Who can use it:** PLATFORM_ADMIN with matching permission and recent MFA  
**Success:** HTTP 200

**Request:**

```json
{
  "expectedVersion": 3,
  "reason": "Appeal approved",
  "reviewId": "mod_review_01"
}
```

**Response (data):**

```json
{
  "id": "usr_01",
  "accountStatus": "ACTIVE",
  "version": 4
}
```

**Errors / rules:** 409 REVIEW_NOT_COMPLETE

**How it works:** Restore login eligibility only; previous revoked membership, role, portal or referral grants are not restored.

##### M02A.24 — `GET /platform/moderation-actions`

**Who can use it:** PLATFORM_ADMIN with matching permission and recent MFA  
**Success:** HTTP 200

**Request:**

Query: targetType?, targetId?, cursor?, limit?

**Response (data):**

```json
{
  "items": [
    {
      "id": "mod_01",
      "targetId": "usr_01",
      "action": "BAN",
      "reason": "Confirmed account misuse"
    }
  ],
  "nextCursor": null
}
```

**Errors / rules:** 403 FORBIDDEN

**How it works:** Append-only moderation evidence; redact sensitive details.

##### M02A.25 — `POST /platform/users/{userId}/revoke-sessions`

**Who can use it:** PLATFORM_ADMIN with matching permission and recent MFA  
**Success:** HTTP 200

**Request:**

```json
{
  "reason": "Security review"
}
```

**Response (data):**

```json
{
  "revokedCount": 2
}
```

**Errors / rules:** 404 USER_NOT_FOUND

**How it works:** Invalidate refresh tokens, bump session version and disconnect active sockets.

##### M02A.26 — `POST /platform/admin-invitations`

**Who can use it:** PLATFORM_ADMIN with matching permission and recent MFA  
**Success:** HTTP 201

**Request:**

```json
{
  "email": "second-admin@example.test",
  "reason": "Approved platform admin staffing"
}
```

**Response (data):**

```json
{
  "id": "pinv_01",
  "status": "PENDING_APPROVAL"
}
```

**Errors / rules:** 409 INVITATION_EXISTS; 403 APPROVAL_REQUIRED

**How it works:** Require second authorized platform administrator approval; first admin bootstrap handled out of band.

##### M02A.27 — `POST /platform/admin-invitations/{invitationId}/approve`

**Who can use it:** PLATFORM_ADMIN with matching permission and recent MFA  
**Success:** HTTP 200

**Request:**

```json
{
  "expectedVersion": 1,
  "reason": "Separate administrator approval"
}
```

**Response (data):**

```json
{
  "id": "pinv_01",
  "status": "PENDING_ACCEPTANCE",
  "version": 2
}
```

**Errors / rules:** 403 REVIEWER_CONFLICT; 409 VERSION_CONFLICT

**How it works:** Different actor approves before token delivery.

##### M02A.28 — `POST /platform/admin-invitations/redeem`

**Who can use it:** Verified invitation holder  
**Success:** HTTP 200

**Request:**

```json
{
  "token": "<one-use-token>"
}
```

**Response (data):**

```json
{
  "userId": "usr_platform_02",
  "status": "MFA_ENROLLMENT_REQUIRED"
}
```

**Errors / rules:** 410 INVITATION_EXPIRED; 403 RECIPIENT_MISMATCH

**How it works:** Activate platform role only after verified identity and MFA enrollment.

##### M02A.29 — `GET /platform/settings`

**Who can use it:** PLATFORM_ADMIN with matching permission and recent MFA  
**Success:** HTTP 200

**Request:**

None — no request body.

**Response (data):**

```json
{
  "version": 1,
  "maintenanceBanner": null,
  "demoMode": true
}
```

**Errors / rules:** 403 FORBIDDEN

**How it works:** Check the actor and resource scope, validate inputs, perform the action, and record the outcome where required.

##### M02A.30 — `PATCH /platform/settings`

**Who can use it:** PLATFORM_ADMIN with matching permission and recent MFA  
**Success:** HTTP 200

**Request:**

```json
{
  "maintenanceBanner": "Scheduled demo maintenance",
  "expectedVersion": 1,
  "reason": "Notify users"
}
```

**Response (data):**

```json
{
  "version": 2,
  "maintenanceBanner": "Scheduled demo maintenance",
  "demoMode": true
}
```

**Errors / rules:** 409 VERSION_CONFLICT; 422 FIELD_NOT_EDITABLE

**How it works:** Allow non-clinical settings only; clinical safety rules and demo-mode changes use reviewed deployments.

##### M02A.31 — `GET /platform/audit`

**Who can use it:** PLATFORM_ADMIN with matching permission and recent MFA  
**Success:** HTTP 200

**Request:**

Query: actorId?, targetType?, from?, to?, cursor?, limit?

**Response (data):**

```json
{
  "items": [
    {
      "id": "aud_01",
      "action": "HOSPITAL_ACTIVATED",
      "targetId": "hosp_01",
      "actorId": "usr_platform_01"
    }
  ],
  "nextCursor": null
}
```

**Errors / rules:** 403 FORBIDDEN

**How it works:** Only platform operational audit, not clinical content.

##### M02A.32 — `POST /auth/password/forgot`

**Who can use it:** Public rate-limited  
**Success:** HTTP 202

**Request:**

```json
{
  "email": "person@example.test"
}
```

**Response (data):**

```json
{
  "status": "ACCEPTED"
}
```

**Errors / rules:** 429 RATE_LIMITED

**How it works:** Generic response regardless of account existence; send time-limited reset link to verified channel.

##### M02A.33 — `POST /auth/password/reset`

**Who can use it:** Reset challenge holder  
**Success:** HTTP 200

**Request:**

```json
{
  "token": "<reset-token>",
  "newPassword": "<new-password>"
}
```

**Response (data):**

```json
{
  "status": "PASSWORD_UPDATED"
}
```

**Errors / rules:** 410 CHALLENGE_EXPIRED; 422 PASSWORD_POLICY

**How it works:** Consume token atomically, revoke sessions; never unban account.

##### M02A.34 — `POST /auth/mfa/enrollment`

**Who can use it:** Verified limited enrollment session  
**Success:** HTTP 201

**Request:**

```json
{
  "method": "TOTP"
}
```

**Response (data):**

```json
{
  "enrollmentId": "mfa_enr_01",
  "setupUri": "<one-time-setup-uri>"
}
```

**Errors / rules:** 409 MFA_ALREADY_ENROLLED

**How it works:** Encrypt pending secret, expire challenge; no admin API access until verified.

##### M02A.35 — `POST /auth/mfa/enrollment/confirm`

**Who can use it:** Verified limited enrollment session  
**Success:** HTTP 200

**Request:**

```json
{
  "enrollmentId": "mfa_enr_01",
  "code": "<otp>"
}
```

**Response (data):**

```json
{
  "status": "ENROLLED"
}
```

**Errors / rules:** 401 INVALID_CHALLENGE; 429 RATE_LIMITED

**How it works:** Enable factor and issue recovery codes through protected one-time flow; approved roles only.

##### M02A.36 — `GET /auth/sessions`

**Who can use it:** Authenticated  
**Success:** HTTP 200

**Request:**

None — no request body.

**Response (data):**

```json
{
  "items": [
    {
      "id": "sess_01",
      "current": true,
      "createdAt": "2026-12-01T09:00:00Z"
    }
  ],
  "nextCursor": null
}
```

**Errors / rules:** 401 UNAUTHENTICATED

**How it works:** Own sessions only.

##### M02A.37 — `DELETE /auth/sessions/{sessionId}`

**Who can use it:** Authenticated  
**Success:** HTTP 204

**Request:**

None — no request body.

**Response (data):**

No body.

**Errors / rules:** 404 SESSION_NOT_FOUND

**How it works:** Revoke own session and its refresh family; disconnect its sockets.

##### M02A.38 — `POST /auth/email-change/request`

**Who can use it:** Authenticated with recent reauthentication  
**Success:** HTTP 202

**Request:**

```json
{
  "newEmail": "new@example.test"
}
```

**Response (data):**

```json
{
  "status": "PENDING_VERIFICATION"
}
```

**Errors / rules:** 429 RATE_LIMITED

**How it works:** Verify new channel and notify old channel; require additional review for privileged accounts.

##### M02A.39 — `POST /auth/email-change/confirm`

**Who can use it:** Authenticated + verification challenge  
**Success:** HTTP 200

**Request:**

```json
{
  "token": "<email-change-token>"
}
```

**Response (data):**

```json
{
  "status": "UPDATED"
}
```

**Errors / rules:** 409 EMAIL_IN_USE; 410 CHALLENGE_EXPIRED

**How it works:** Change verified login identifier atomically and revoke existing sessions.

**Acceptance tests:** First admin bootstrap runs once; second admin cannot self-approve; approval and creation are distinct; draft hospital cannot create clinical records; ban immediately rejects old access/refresh tokens and subscriptions; staff in two hospitals lose both contexts after global ban but only one after local suspension; last admin protection prevents accidental lockout; privileged status changes require MFA and audit; no platform clinical access; hospital restoration never revives grants; active admissions survive restrictions.

### M03 — Hospital, staff, wards and beds

**Dependencies:** M02, M02A  
**Owner:** Abhishek  
**Status:** Planned

**In simple words — Hospitals, staff, wards and beds:** Set up the hospital before registering patients. A ward is a group of beds managed by assigned staff.

#### Implementation steps

1. Use the hospital approved and provisioned by M02A. The first Hospital Admin accepts the verified invitation; only authorized setup endpoints work until activation.
2. Invite staff using a one-time invitation that expires. Assign their roles and wards.
3. Create wards and beds and show whether each bed is occupied.
4. Prevent duplicate bed labels and unsafe deletion of occupied beds.
5. Check assignments on every patient-related API and record permission changes.

**How to know this module is working:** Staff see only assigned wards; inactive staff are blocked and occupied beds cannot be removed.

<details>
<summary>Exact engineering steps and acceptance tests (developer reference)</summary>

1. Read the tenant provisioned by M02A; enable clinical permissions only after activation.
2. Implement hospital membership invitations (single-use token, expiry, verified email) and ward assignments.
3. Create wards, beds, occupancy screen and staff management; prevent removing active bed or disabling last authorized admin.
4. Enforce assignment on every subsequent clinical endpoint; log all role changes.

**Acceptance criteria:** Ward scoped nurses cannot see other wards; duplicate bed labels rejected; inactive staff blocked; concurrent bed assignment handled in M04.

</details>

#### API contracts

##### M03.01 — `POST /hospitals`

**Authorization:** PLATFORM_ADMIN  
**Success:** HTTP 201

**Request:**

```json
{
  "applicationId": "hap_01",
  "name": "Demo Hospital",
  "code": "DEMO",
  "timezone": "Asia/Kolkata"
}
```

**Response (data):**

```json
{
  "id": "hosp_01",
  "status": "SETUP_PENDING",
  "version": 1
}
```

**Errors / constraints:** 409 HOSPITAL_CODE_EXISTS or APPLICATION_NOT_APPROVED. This is the provisioning endpoint for M02A; it cannot directly activate a hospital. An approved application can provision only one tenant.

##### M03.02 — `GET /hospitals/current`

**Authorization:** Authenticated  
**Success:** HTTP 200

**Request:**

None

**Response (data):**

```json
{
  "id": "hosp_01",
  "name": "Demo Hospital",
  "timezone": "Asia/Kolkata"
}
```

**Errors / constraints:** 403 MEMBERSHIP_REQUIRED.

##### M03.03 — `POST /staff/invitations`

**Authorization:** HOSPITAL_ADMIN  
**Success:** HTTP 201

**Request:**

```json
{
  "email": "doctor@example.test",
  "role": "DOCTOR"
}
```

**Response (data):**

```json
{
  "id": "invite_01",
  "status": "PENDING",
  "expiresAt": "2026-12-02T00:00:00Z"
}
```

**Errors / constraints:** 409 MEMBERSHIP_EXISTS; 422 ROLE_NOT_GRANTABLE.

##### M03.04 — `POST /staff/invitations/accept`

**Authorization:** Invitation + verified identity  
**Success:** HTTP 200

**Request:**

```json
{
  "token": "<invite-token>"
}
```

**Response (data):**

```json
{
  "membershipId": "mem_02",
  "status": "PENDING_REVIEW"
}
```

**Errors / constraints:** 409 INVITATION_USED; 410 INVITATION_EXPIRED. Staff credentials and access scope must be approved before activation. For the first Hospital Admin, use the platform invitation and approval workflow in M02A.

##### M03.05 — `GET /staff`

**Authorization:** HOSPITAL_ADMIN  
**Success:** HTTP 200

**Request:**

Query: role?, status?, limit?, cursor?

**Response (data):**

```json
{
  "items": [
    {
      "id": "mem_02",
      "userId": "usr_02",
      "role": "DOCTOR",
      "status": "ACTIVE"
    }
  ],
  "nextCursor": null
}
```

**Errors / constraints:** 403 FORBIDDEN.

##### M03.06 — `PATCH /staff/{membershipId}`

**Authorization:** HOSPITAL_ADMIN  
**Success:** HTTP 200

**Request:**

```json
{
  "status": "SUSPENDED",
  "expectedVersion": 1
}
```

**Response (data):**

```json
{
  "id": "mem_02",
  "status": "SUSPENDED",
  "version": 2
}
```

**Errors / constraints:** 409 VERSION_CONFLICT or LAST_ADMIN. This route only changes allowed non-privileged staff fields/status; cannot activate an unreviewed clinician, grant PLATFORM_ADMIN or change a global account ban. Use explicit review/action endpoints in M03A for lifecycle changes.

##### M03.07 — `POST /wards`

**Authorization:** HOSPITAL_ADMIN  
**Success:** HTTP 201

**Request:**

```json
{
  "code": "W1",
  "name": "Demo Ward"
}
```

**Response (data):**

```json
{
  "id": "ward_01",
  "code": "W1",
  "version": 1
}
```

**Errors / constraints:** 409 WARD_EXISTS.

##### M03.08 — `POST /wards/{wardId}/beds`

**Authorization:** HOSPITAL_ADMIN  
**Success:** HTTP 201

**Request:**

```json
{
  "label": "B04"
}
```

**Response (data):**

```json
{
  "id": "bed_04",
  "label": "B04",
  "status": "AVAILABLE"
}
```

**Errors / constraints:** 409 BED_EXISTS.

##### M03.09 — `GET /wards`

**Authorization:** Staff with ward access  
**Success:** HTTP 200

**Request:**

Query: limit?, cursor?

**Response (data):**

```json
{
  "items": [
    {
      "id": "ward_01",
      "name": "Demo Ward"
    }
  ],
  "nextCursor": null
}
```

**Errors / constraints:** 403 FORBIDDEN.

##### M03.10 — `GET /wards/{wardId}/beds`

**Authorization:** Ward-scoped staff  
**Success:** HTTP 200

**Request:**

Query: status?, cursor?, limit?

**Response (data):**

```json
{
  "items": [
    {
      "id": "bed_04",
      "label": "B04",
      "status": "AVAILABLE"
    }
  ],
  "nextCursor": null
}
```

**Errors / constraints:** 404 WARD_NOT_FOUND.

##### M03.11 — `POST /care-assignments`

**Authorization:** HOSPITAL_ADMIN  
**Success:** HTTP 201

**Request:**

```json
{
  "membershipId": "mem_02",
  "wardId": "ward_01",
  "admissionId": null,
  "validFrom": "2026-12-01T00:00:00Z",
  "validUntil": "2026-12-02T00:00:00Z"
}
```

**Response (data):**

```json
{
  "id": "assign_01",
  "status": "ACTIVE"
}
```

**Errors / constraints:** 422 INVALID_SCOPE; 409 ASSIGNMENT_CONFLICT.

##### M03.12 — `DELETE /care-assignments/{assignmentId}`

**Authorization:** HOSPITAL_ADMIN  
**Success:** HTTP 204

**Request:**

None

**Response (data):**

No body.

**Errors / constraints:** 404 ASSIGNMENT_NOT_FOUND.

### M03A — Hospital administration, reception and ward operations

**Dependencies:** M02A, M03; patient intake routes depend on M04. Build M03A organization/staff slice first, then M04 patient creation, then integrate M03A reception/ward slice and M04 admission. **Owner:** Abhishek (Aman supports ward/device integration). **Status:** New proposed module.

#### Hospital Admin steps

1. Open a hospital-only admin dashboard with setup checklist and operational counts. Add department, ward and bed configuration. Department/ward/bed IDs always belong to the selected hospital.
2. Invite doctor, nurse, receptionist, ward staff or lab tech; record verified identity and required role credentials using synthetic evidence. No shared accounts. Admin cannot give themselves doctor access or create platform admins. A separate qualified reviewer is needed for clinical credentials.
3. Set assignment scope (department/ward/encounter where needed), expiry and role permissions. Membership acceptance alone is not clinical approval. Staff can log in only in approved context; setup-only screens are allowed during SETUP_PENDING.
4. Manage staff directory, invitation resends/revokes, versioned changes and local suspension/removal. Disable stale sessions and assignments; transfer pending responsibilities to an authorized supervisor. Protect last authorized hospital admin; platform-approved replacement first.
5. Do not hard-delete occupied beds, wards with active patients or departed staff with audit history. Occupancy is computed from bed assignments; cleaning/readiness is an independent status.

#### Reception / ward staff steps

1. Reception searches local MRN or authorized synthetic identifier, confirms patient match, or creates a provisional patient. No national ID or portal login required. Use patient registration APIs in M04.
2. Create walk-in queue item, mark arrival, forward to clinician. A clinician determines clinical triage and admission. Reception only coordinates logistics; emergency arrival must not be blocked by account verification.
3. Check ward/bed availability; clinician records approval; authorized intake staff uses M04.09 with admissionDecisionId. Assign bed atomically; create wristband. Outpatient visit can be completed without inpatient admission (no bed or wristband required by this proposed queue workflow).
4. Ward staff sees assigned operational tasks: bed readiness, transport coordination and equipment assistance. Do not grant medicine administration, prescribing, diagnosis or report verification merely because someone works on the ward.
5. Build staff/ward queues and show clear status, assignment, failure and stale information. Discharge and transfer are still governed by M04/M14; reception cannot independently discharge or cancel clinical care.

#### API contracts

##### M03A.01 — `PATCH /hospitals/current`

**Who can use it:** HOSPITAL_ADMIN in selected hospital  
**Success:** HTTP 200

**Request:**

```json
{
  "contactEmail": "ops@example.test",
  "expectedVersion": 3,
  "reason": "Update operations contact"
}
```

**Response (data):**

```json
{
  "id": "hosp_01",
  "version": 4
}
```

**Errors / rules:** 409 VERSION_CONFLICT; 422 FIELD_NOT_EDITABLE

**How it works:** Only approved local contact fields; legal name/code and lifecycle go through platform review.

##### M03A.02 — `POST /departments`

**Who can use it:** HOSPITAL_ADMIN in selected hospital  
**Success:** HTTP 201

**Request:**

```json
{
  "name": "General Medicine",
  "code": "MED"
}
```

**Response (data):**

```json
{
  "id": "dept_01",
  "status": "ACTIVE",
  "version": 1
}
```

**Errors / rules:** 409 DEPARTMENT_CODE_EXISTS

**How it works:** Create tenant-owned department.

##### M03A.03 — `GET /departments`

**Who can use it:** Active hospital staff  
**Success:** HTTP 200

**Request:**

Query: status?, cursor?, limit?

**Response (data):**

```json
{
  "items": [
    {
      "id": "dept_01",
      "name": "General Medicine",
      "status": "ACTIVE"
    }
  ],
  "nextCursor": null
}
```

**Errors / rules:** 403 SCOPE_DENIED

**How it works:** Return only accessible organizational metadata.

##### M03A.04 — `PATCH /departments/{departmentId}`

**Who can use it:** HOSPITAL_ADMIN in selected hospital  
**Success:** HTTP 200

**Request:**

```json
{
  "name": "General Ward Services",
  "expectedVersion": 1,
  "reason": "Rename department"
}
```

**Response (data):**

```json
{
  "id": "dept_01",
  "version": 2
}
```

**Errors / rules:** 409 VERSION_CONFLICT or ACTIVE_DEPENDENCIES

**How it works:** Allow rename or safe deactivation; do not delete wards.

##### M03A.05 — `PATCH /wards/{wardId}`

**Who can use it:** HOSPITAL_ADMIN in selected hospital  
**Success:** HTTP 200

**Request:**

```json
{
  "name": "Ward A",
  "departmentId": "dept_01",
  "expectedVersion": 1,
  "reason": "Assign department"
}
```

**Response (data):**

```json
{
  "id": "ward_01",
  "version": 2
}
```

**Errors / rules:** 409 ACTIVE_DEPENDENCIES; 422 INVALID_DEPARTMENT

**How it works:** Validate same tenant; deactivation requires no active encounters or assignments.

##### M03A.06 — `PATCH /beds/{bedId}`

**Who can use it:** HOSPITAL_ADMIN in selected hospital  
**Success:** HTTP 200

**Request:**

```json
{
  "label": "A-01",
  "expectedVersion": 1,
  "reason": "Correct bed label"
}
```

**Response (data):**

```json
{
  "id": "bed_01",
  "version": 2
}
```

**Errors / rules:** 409 BED_OCCUPIED or BED_EXISTS

**How it works:** Do not change occupancy manually; deactivate only when safe.

##### M03A.07 — `GET /staff/{membershipId}`

**Who can use it:** HOSPITAL_ADMIN in selected hospital  
**Success:** HTTP 200

**Request:**

None — no request body.

**Response (data):**

```json
{
  "id": "mem_02",
  "role": "DOCTOR",
  "status": "PENDING_REVIEW",
  "version": 1
}
```

**Errors / rules:** 404 MEMBERSHIP_NOT_FOUND

**How it works:** Check the actor and resource scope, validate inputs, perform the action, and record the outcome where required.

##### M03A.08 — `GET /staff/invitations`

**Who can use it:** HOSPITAL_ADMIN in selected hospital  
**Success:** HTTP 200

**Request:**

Query: status?, cursor?, limit?

**Response (data):**

```json
{
  "items": [
    {
      "id": "invite_01",
      "status": "PENDING",
      "role": "DOCTOR"
    }
  ],
  "nextCursor": null
}
```

**Errors / rules:** 403 FORBIDDEN

**How it works:** Check the actor and resource scope, validate inputs, perform the action, and record the outcome where required.

##### M03A.09 — `POST /staff/invitations/{invitationId}/revoke`

**Who can use it:** HOSPITAL_ADMIN in selected hospital  
**Success:** HTTP 200

**Request:**

```json
{
  "reason": "Incorrect recipient"
}
```

**Response (data):**

```json
{
  "id": "invite_01",
  "status": "REVOKED"
}
```

**Errors / rules:** 409 INVITATION_USED

**How it works:** Revoke invitation atomically; cannot revoke an accepted membership via this endpoint.

##### M03A.10 — `POST /staff/invitations/{invitationId}/resend`

**Who can use it:** HOSPITAL_ADMIN in selected hospital  
**Success:** HTTP 201

**Request:**

```json
{
  "reason": "Expired invitation"
}
```

**Response (data):**

```json
{
  "id": "invite_02",
  "status": "PENDING"
}
```

**Errors / rules:** 409 INVITATION_ALREADY_USED

**How it works:** Revoke old token and send fresh single-use token; throttle.

##### M03A.11 — `POST /staff/{membershipId}/credential-reviews`

**Who can use it:** HOSPITAL_ADMIN in selected hospital  
**Success:** HTTP 201

**Request:**

```json
{
  "decision": "APPROVE",
  "evidenceRef": "cred_demo_01",
  "reason": "Demo credentials and role scope checked",
  "expectedVersion": 1
}
```

**Response (data):**

```json
{
  "id": "mem_02",
  "status": "ACTIVE",
  "version": 2
}
```

**Errors / rules:** 422 EVIDENCE_REQUIRED; 409 VERSION_CONFLICT

**How it works:** Qualified credential reviewer required for clinical role; verify evidence and user status. No real credentials in demo.

##### M03A.12 — `POST /staff/{membershipId}/role-changes`

**Who can use it:** HOSPITAL_ADMIN in selected hospital  
**Success:** HTTP 200

**Request:**

```json
{
  "role": "RECEPTIONIST",
  "reason": "Changed duty",
  "expectedVersion": 2
}
```

**Response (data):**

```json
{
  "id": "mem_02",
  "status": "PENDING_REVIEW",
  "version": 3
}
```

**Errors / rules:** 422 ROLE_NOT_GRANTABLE; 409 ACTIVE_CARE_REVIEW_REQUIRED

**How it works:** Revoke old authorization; re-review new role and assignments. Admin role via platform process only.

##### M03A.13 — `POST /staff/{membershipId}/status`

**Who can use it:** HOSPITAL_ADMIN in selected hospital  
**Success:** HTTP 200

**Request:**

```json
{
  "action": "SUSPEND",
  "reason": "Local access review",
  "expectedVersion": 3
}
```

**Response (data):**

```json
{
  "id": "mem_02",
  "status": "SUSPENDED",
  "version": 4
}
```

**Errors / rules:** 409 LAST_ADMIN; 409 VERSION_CONFLICT

**How it works:** SUSPEND/REMOVE affects one hospital only; revoke scoped sessions, reassign tasks, reconcile uncertain medication actions. RESTORE requires valid credentials and active global user.

##### M03A.14 — `GET /hospital-admin/dashboard`

**Who can use it:** HOSPITAL_ADMIN in selected hospital  
**Success:** HTTP 200

**Request:**

Query: wardId?

**Response (data):**

```json
{
  "beds": {
    "available": 6,
    "occupied": 4,
    "cleaning": 1
  },
  "staff": {
    "active": 8,
    "pending": 2
  },
  "openOperationalTasks": 3
}
```

**Errors / rules:** 403 FORBIDDEN

**How it works:** Operational counts only; no patient clinical details.

##### M03A.15 — `GET /reception/queue`

**Who can use it:** RECEPTIONIST or explicitly intake-authorized WARD_STAFF  
**Success:** HTTP 200

**Request:**

Query: status?, cursor?, limit?

**Response (data):**

```json
{
  "items": [
    {
      "id": "visit_01",
      "mrn": "MRN-DEMO-001",
      "status": "WAITING",
      "version": 1
    }
  ],
  "nextCursor": null
}
```

**Errors / rules:** 403 SCOPE_DENIED

**How it works:** Filter by assigned intake area; no clinical note content.

##### M03A.16 — `POST /reception/queue`

**Who can use it:** RECEPTIONIST or explicitly intake-authorized WARD_STAFF  
**Success:** HTTP 201

**Request:**

```json
{
  "patientId": "pat_01",
  "visitType": "WALK_IN",
  "reasonCode": "GENERAL_VISIT"
}
```

**Response (data):**

```json
{
  "id": "visit_01",
  "status": "WAITING",
  "version": 1
}
```

**Errors / rules:** 404 PATIENT_NOT_FOUND; 409 OPEN_VISIT_EXISTS

**How it works:** Create queue entry after identity check. Emergency intake does not require a portal account.

##### M03A.17 — `PATCH /reception/queue/{visitId}`

**Who can use it:** RECEPTIONIST or explicitly intake-authorized WARD_STAFF  
**Success:** HTTP 200

**Request:**

```json
{
  "status": "CHECKED_IN",
  "expectedVersion": 1,
  "reason": "Patient arrived"
}
```

**Response (data):**

```json
{
  "id": "visit_01",
  "status": "CHECKED_IN",
  "version": 2
}
```

**Errors / rules:** 409 INVALID_TRANSITION or VERSION_CONFLICT

**How it works:** Allowed operational transitions: WAITING, CHECKED_IN, REFERRED_TO_CLINICIAN, COMPLETED, CANCELLED. Clinical triage priority is not set by reception.

##### M03A.18 — `POST /reception/queue/{visitId}/admission-decisions`

**Who can use it:** Assigned DOCTOR  
**Success:** HTTP 201

**Request:**

```json
{
  "decision": "APPROVE_ADMISSION",
  "wardId": "ward_01",
  "expectedVersion": 2
}
```

**Response (data):**

```json
{
  "id": "dec_01",
  "status": "APPROVED",
  "version": 1
}
```

**Errors / rules:** 403 CLINICIAN_REQUIRED; 409 INVALID_TRANSITION

**How it works:** Record clinician authorization; reception references decision in M04.09; never create medication orders here.

##### M03A.19 — `GET /beds/availability`

**Who can use it:** RECEPTIONIST or explicitly intake-authorized WARD_STAFF  
**Success:** HTTP 200

**Request:**

Query: wardId?, cursor?, limit?

**Response (data):**

```json
{
  "items": [
    {
      "id": "bed_01",
      "wardId": "ward_01",
      "status": "AVAILABLE"
    }
  ],
  "nextCursor": null
}
```

**Errors / rules:** 403 SCOPE_DENIED

**How it works:** Availability is advisory until transactional assignment succeeds.

##### M03A.20 — `GET /ward/tasks`

**Who can use it:** Assigned WARD_STAFF / NURSE / operational supervisor  
**Success:** HTTP 200

**Request:**

Query: wardId, status?, cursor?, limit?

**Response (data):**

```json
{
  "items": [
    {
      "id": "wt_01",
      "type": "BED_READINESS",
      "status": "OPEN",
      "version": 1
    }
  ],
  "nextCursor": null
}
```

**Errors / rules:** 403 SCOPE_DENIED

**How it works:** Only operational tasks in assigned ward.

##### M03A.21 — `POST /ward/tasks`

**Who can use it:** Assigned NURSE or HOSPITAL_ADMIN with operational task permission  
**Success:** HTTP 201

**Request:**

```json
{
  "wardId": "ward_01",
  "type": "BED_READINESS",
  "bedId": "bed_01",
  "assigneeMembershipId": "mem_ward_01"
}
```

**Response (data):**

```json
{
  "id": "wt_01",
  "status": "OPEN",
  "version": 1
}
```

**Errors / rules:** 422 INVALID_TASK_TYPE; 403 ASSIGNMENT_DENIED

**How it works:** Allow bed cleaning, transport coordination and equipment assistance only; no medication administration.

##### M03A.22 — `PATCH /ward/tasks/{taskId}`

**Who can use it:** Assigned task worker or supervisor  
**Success:** HTTP 200

**Request:**

```json
{
  "status": "COMPLETED",
  "expectedVersion": 1,
  "note": "Bed prepared in demo"
}
```

**Response (data):**

```json
{
  "id": "wt_01",
  "status": "COMPLETED",
  "version": 2
}
```

**Errors / rules:** 409 INVALID_TRANSITION or VERSION_CONFLICT

**How it works:** Validate task state and assignment; completion does not approve clinical action.

##### M03A.23 — `POST /beds/{bedId}/readiness`

**Who can use it:** Assigned WARD_STAFF or authorized ward supervisor  
**Success:** HTTP 200

**Request:**

```json
{
  "status": "READY",
  "expectedVersion": 2,
  "reason": "Cleaning completed"
}
```

**Response (data):**

```json
{
  "id": "bed_01",
  "readiness": "READY",
  "version": 3
}
```

**Errors / rules:** 409 BED_OCCUPIED; 409 VERSION_CONFLICT

**How it works:** Readiness separate from occupancy; occupied bed cannot be made available by this route.

**Acceptance tests:** Reception cannot prescribe or read full history; ward staff cannot reserve/administer a medication; staff cannot activate themselves; duplicate department/bed label rejected; one patient wins a bed race; local suspension preserves other hospital membership; completed cleaning cannot override occupancy; queue status cannot authorize treatment; clinician admission decision cannot be reused for another patient or bed assignment; all cross-tenant queries denied.

### M04 — Patient registration, consent, admissions and wristbands

**Dependencies:** M02–M03 and M02A; build patient registration first, then integrate M03A admission decision for reception admissions  
**Owner:** Abhishek  
**Status:** Planned

**In simple words — Patient registration and QR wristbands:** Register a patient, assign a bed, record sharing permission and give the patient a QR wristband.

#### Implementation steps

1. Create a local patient number even if the patient has no Aadhaar or ABHA. Use fake identifiers only in the demo.
2. Search for possible existing records; ask staff to verify matches. Do not assume a national ID proves identity.
3. Create the admission and bed assignment together so two patients cannot get the same bed.
4. Generate a random QR wristband token. Do not put the patient name or medical details in the QR. Disable replaced wristbands.
5. Record sharing permission (who, why, what and until when) and distinguish unknown allergies from no known allergies.

**How to know this module is working:** Only one admission wins a bed race; a replaced QR cannot be used; consent withdrawal blocks future sharing.

<details>
<summary>Exact engineering steps and acceptance tests (developer reference)</summary>

1. Implement local MRN and provisional patient intake without requiring national identifiers. Synthetic identifiers only in demo; never assume an Aadhaar/ABHA number authenticates a person.
2. For future authorized integration, use keyed HMAC digest with key version for exact match (rather than plain salted SHA-256 on low-entropy IDs); mask last four; no raw identifiers in logs, URLs, embeddings or analytics. No unrestricted cross-hospital lookup.
3. Lookup POST with rate limits, identity confirmation, candidate match and human duplicate review; allow emergency provisional record.
4. Create encounter + bed assignment atomically, issue opaque random QR with digest, revoke old band on replacement.
5. Capture consent purpose, recipient, scope, validity, withdrawal; allergies distinguish UNKNOWN from NO_KNOWN. Build registration and patient detail UI.

**Acceptance criteria:** Duplicate candidates require review; bed race exactly one winner; QR contains no PHI; revoked token rejected; consent withdrawal denies future sharing; provisional intake remains available.

</details>

#### API contracts

##### M04.01 — `POST /patients/lookup`

**Authorization:** Intake-scoped staff  
**Success:** HTTP 200

**Request:**

```json
{
  "identifierType": "DEMO_ABHA",
  "identifier": "DEMO-ID-0001"
}
```

**Response (data):**

```json
{
  "matchStatus": "CANDIDATE",
  "candidates": [
    {
      "patientId": "pat_01",
      "maskedIdentifier": "****0001",
      "verificationStatus": "UNVERIFIED"
    }
  ]
}
```

**Errors / constraints:** 422 UNSUPPORTED_IDENTIFIER; 429 RATE_LIMITED. No candidate data outside matching scope.

##### M04.02 — `POST /patients`

**Authorization:** Intake-scoped staff  
**Success:** HTTP 201

**Request:**

```json
{
  "displayName": "Synthetic Patient A",
  "dateOfBirth": "1980-01-01",
  "sex": "UNSPECIFIED",
  "identifier": {
    "type": "DEMO_ABHA",
    "value": "DEMO-ID-0001"
  },
  "identityStatus": "PROVISIONAL"
}
```

**Response (data):**

```json
{
  "id": "pat_01",
  "mrn": "MRN-DEMO-001",
  "identityStatus": "PROVISIONAL",
  "version": 1
}
```

**Errors / constraints:** 409 POSSIBLE_DUPLICATE; 422 INVALID_DEMOGRAPHICS. Identifier optional.

##### M04.03 — `GET /patients/{patientId}`

**Authorization:** Assigned care/intake staff  
**Success:** HTTP 200

**Request:**

None

**Response (data):**

```json
{
  "id": "pat_01",
  "mrn": "MRN-DEMO-001",
  "displayName": "Synthetic Patient A",
  "identityStatus": "PROVISIONAL",
  "allergyStatus": "UNKNOWN",
  "version": 1
}
```

**Errors / constraints:** 404 PATIENT_NOT_FOUND.

##### M04.04 — `PATCH /patients/{patientId}`

**Authorization:** Authorized intake reviewer  
**Success:** HTTP 200

**Request:**

```json
{
  "displayName": "Synthetic Patient A",
  "expectedVersion": 1,
  "reason": "Demo correction"
}
```

**Response (data):**

```json
{
  "id": "pat_01",
  "version": 2
}
```

**Errors / constraints:** 409 VERSION_CONFLICT; 422 IDENTITY_REVIEW_REQUIRED.

##### M04.05 — `POST /patients/{patientId}/identity-reviews`

**Authorization:** Authorized identity reviewer  
**Success:** HTTP 201

**Request:**

```json
{
  "decision": "VERIFIED_LOCAL",
  "evidenceRef": "fixture_01",
  "reason": "Synthetic identity review"
}
```

**Response (data):**

```json
{
  "id": "review_01",
  "identityStatus": "VERIFIED_LOCAL"
}
```

**Errors / constraints:** 422 EVIDENCE_REQUIRED; 409 DUPLICATE_REVIEW_PENDING.

##### M04.06 — `POST /patients/{patientId}/consents`

**Authorization:** Authorized consent staff  
**Success:** HTTP 201

**Request:**

```json
{
  "purpose": "REFERRAL",
  "scope": [
    "MEDICATIONS",
    "VERIFIED_REPORTS"
  ],
  "recipientOrgId": "hosp_02",
  "expiresAt": "2026-12-03T00:00:00Z",
  "evidenceRef": "fixture_consent"
}
```

**Response (data):**

```json
{
  "id": "consent_01",
  "status": "ACTIVE"
}
```

**Errors / constraints:** 422 CONSENT_EVIDENCE_REQUIRED.

##### M04.07 — `GET /patients/{patientId}/consents`

**Authorization:** Authorized consent staff/doctor  
**Success:** HTTP 200

**Request:**

Query: status?, cursor?, limit?

**Response (data):**

```json
{
  "items": [
    {
      "id": "consent_01",
      "purpose": "REFERRAL",
      "status": "ACTIVE"
    }
  ],
  "nextCursor": null
}
```

**Errors / constraints:** 404 PATIENT_NOT_FOUND.

##### M04.08 — `POST /consents/{consentId}/revoke`

**Authorization:** Authorized consent staff  
**Success:** HTTP 200

**Request:**

```json
{
  "reason": "Synthetic withdrawal"
}
```

**Response (data):**

```json
{
  "id": "consent_01",
  "status": "REVOKED"
}
```

**Errors / constraints:** 409 CONSENT_ALREADY_REVOKED (or idempotent return).

##### M04.09 — `POST /admissions`

**Authorization:** DOCTOR or intake staff with an authorized admission decision and bed scope  
**Success:** HTTP 201

**Request:**

```json
{
  "patientId": "pat_01",
  "wardId": "ward_01",
  "bedId": "bed_04",
  "attendingDoctorId": "usr_02",
  "reason": "Synthetic admission"
}
```

**Response (data):**

```json
{
  "id": "enc_01",
  "status": "ACTIVE",
  "bedId": "bed_04",
  "version": 1
}
```

**Errors / constraints:** 409 BED_OCCUPIED; 422 INVALID_DOCTOR_ASSIGNMENT or ADMISSION_AUTHORIZATION_REQUIRED. Reception must reference a valid clinician-approved admission decision (M03A); add `admissionDecisionId` to reception requests. Direct doctor requests require the clinician permission and assignment. Consume the decision atomically with the bed assignment.

##### M04.10 — `GET /admissions`

**Authorization:** Assigned staff  
**Success:** HTTP 200

**Request:**

Query: wardId?, status?, patientId?, limit?, cursor?

**Response (data):**

```json
{
  "items": [
    {
      "id": "enc_01",
      "patientId": "pat_01",
      "bedId": "bed_04",
      "status": "ACTIVE"
    }
  ],
  "nextCursor": null
}
```

**Errors / constraints:** 403 SCOPE_DENIED.

##### M04.11 — `GET /admissions/{admissionId}`

**Authorization:** Assigned staff  
**Success:** HTTP 200

**Request:**

None

**Response (data):**

```json
{
  "id": "enc_01",
  "patientId": "pat_01",
  "status": "ACTIVE",
  "wardId": "ward_01",
  "bedId": "bed_04",
  "version": 1
}
```

**Errors / constraints:** 404 ADMISSION_NOT_FOUND.

##### M04.12 — `POST /admissions/{admissionId}/transfer`

**Authorization:** Authorized intake/doctor  
**Success:** HTTP 200

**Request:**

```json
{
  "targetWardId": "ward_02",
  "targetBedId": "bed_08",
  "reason": "Demo transfer",
  "expectedVersion": 1
}
```

**Response (data):**

```json
{
  "id": "enc_01",
  "wardId": "ward_02",
  "bedId": "bed_08",
  "version": 2
}
```

**Errors / constraints:** 409 BED_OCCUPIED or ACTIVE_DOSE_REVIEW_REQUIRED.

##### M04.13 — `POST /admissions/{admissionId}/wristbands`

**Authorization:** Assigned intake/nurse  
**Success:** HTTP 201

**Request:**

```json
{
  "replaceExisting": false
}
```

**Response (data):**

```json
{
  "id": "band_01",
  "qrPayload": "ms:wristband:<opaque-token>",
  "expiresAt": "2026-12-10T00:00:00Z"
}
```

**Errors / constraints:** 409 ACTIVE_WRISTBAND_EXISTS; 422 ADMISSION_CLOSED.

##### M04.14 — `POST /wristbands/resolve`

**Authorization:** Assigned staff  
**Success:** HTTP 200

**Request:**

```json
{
  "qrPayload": "ms:wristband:<opaque-token>"
}
```

**Response (data):**

```json
{
  "admissionId": "enc_01",
  "patientId": "pat_01",
  "displayName": "Synthetic Patient A",
  "bandStatus": "ACTIVE"
}
```

**Errors / constraints:** 404 INVALID_OR_OUT_OF_SCOPE_BAND; 410 BAND_EXPIRED_OR_REVOKED for authorized actor.

##### M04.15 — `DELETE /wristbands/{wristbandId}`

**Authorization:** Assigned intake/nurse  
**Success:** HTTP 204

**Request:**

None

**Response (data):**

No body.

**Errors / constraints:** 404 WRISTBAND_NOT_FOUND.

##### M04.16 — `POST /patients/{patientId}/allergies`

**Authorization:** DOCTOR or authorized nurse  
**Success:** HTTP 201

**Request:**

```json
{
  "substanceCode": "DEMO-SUBSTANCE-01",
  "reaction": "Synthetic reaction",
  "verificationStatus": "REPORTED",
  "source": "PATIENT_REPORTED"
}
```

**Response (data):**

```json
{
  "id": "alg_01",
  "version": 1,
  "verificationStatus": "REPORTED"
}
```

**Errors / constraints:** 422 INVALID_SUBSTANCE; no AI-derived allergy automatically final.

##### M04.17 — `GET /patients/{patientId}/allergies`

**Authorization:** Assigned clinical staff  
**Success:** HTTP 200

**Request:**

None

**Response (data):**

```json
{
  "status": "REPORTED",
  "items": [
    {
      "id": "alg_01",
      "substanceCode": "DEMO-SUBSTANCE-01",
      "verificationStatus": "REPORTED"
    }
  ]
}
```

**Errors / constraints:** 404 PATIENT_NOT_FOUND.

### M04A — Patient accounts, patient portal and caregiver access

**Dependencies:** M02, M02A, M04 (identity/link slice); M14/M15 for released clinical records, M18 for referrals. **Owner:** Abhishek; Akanksha helps verify safe display. **Status:** New proposed module.

**Goal:** A patient can view their own authorized records after identity verification. The hospital can still treat a patient who has no smartphone, no email, no national ID or no portal account.

#### Step-by-step flow

1. Reception creates the medical patient record and local MRN first. Patient portal signup creates only a login account; email verification proves contact ownership, not patient identity. A verified account starts with zero record access.
2. Authorized intake identity reviewer checks patient identity and a verified contact through the hospital's approved process. Issue a short-lived recipient-bound invitation; never use a wristband QR or a supplied Aadhaar/ABHA number as a login credential.
3. Patient accepts invite and submits link request. Reviewer verifies exact match and approves; create active portal link. Multiple hospital records may be linked only after each hospital's verification/authorized exchange. No national/global patient search and no automatic merge.
4. Patient logs in through existing auth, selects their verified link, sees only released information: encounter summaries, reviewed reports, discharge documents and approved medication information where published. Do not expose raw telemetry, unreviewed AI results, staff notes or another patient's data by default. Display release date/version and source.
5. Patient downloads released documents via authenticated short-lived ticket. Each fetch rechecks access. A patient can request demographics correction or clinical record review; reviewer uses versioned amendment, not overwrite of signed records. Distinguish account name from medical identity.
6. Patient can see sharing status and request/revoke applicable permissions. Actual inter-hospital referral follows M18 with verified clinical recipient and purpose. Explain that withdrawal stops future sharing, not already downloaded copies or required retained records.
7. Optional caregiver access is a separate grant, not shared patient credentials. Verify caregiver account and patient's authority/capacity; scope and expiry; allow revocation. For minors or patients without capacity, use reviewed institutional proxy process, not automatic email matching.
8. If patient loses access, use account recovery + identity re-verification. Revoke compromised portal link and active grants as appropriate; do not erase records. Global ban or suspension routes legitimate record-access requests to an authorized independent channel. Emergency care never depends on portal login.
9. Keep patient notification content generic (no sensitive details on lock screen), audit sensitive reads, avoid cache of patient data on public/shared devices, and show demo labels. Patient portal is not an emergency service, prescribing app or autonomous AI diagnosis tool.

#### API contracts

##### M04A.01 — `POST /patient-portal/accounts`

**Who can use it:** Public rate-limited  
**Success:** HTTP 202

**Request:**

```json
{
  "email": "patient@example.test",
  "password": "<new-password>"
}
```

**Response (data):**

```json
{
  "status": "VERIFICATION_REQUIRED"
}
```

**Errors / rules:** 429 RATE_LIMITED

**How it works:** Create pending account or generic existing-account response; no patient records available.

##### M04A.02 — `POST /patient-portal/accounts/verify`

**Who can use it:** Email challenge holder  
**Success:** HTTP 200

**Request:**

```json
{
  "token": "<verification-token>"
}
```

**Response (data):**

```json
{
  "status": "VERIFIED_UNLINKED"
}
```

**Errors / rules:** 410 CHALLENGE_EXPIRED; 429 RATE_LIMITED

**How it works:** Verify login channel only; not medical identity.

##### M04A.03 — `POST /patients/{patientId}/portal-invitations`

**Who can use it:** Intake identity reviewer  
**Success:** HTTP 201

**Request:**

```json
{
  "verifiedContactRef": "contact_01",
  "reason": "Patient requested portal access"
}
```

**Response (data):**

```json
{
  "id": "p_inv_01",
  "status": "PENDING"
}
```

**Errors / rules:** 422 IDENTITY_REVIEW_REQUIRED; 409 INVITATION_EXISTS

**How it works:** Send invitation to independently verified contact; no Aadhaar or wristband login.

##### M04A.04 — `POST /patient-portal/link-requests`

**Who can use it:** Verified patient account  
**Success:** HTTP 201

**Request:**

```json
{
  "invitationToken": "<portal-token>"
}
```

**Response (data):**

```json
{
  "id": "plr_01",
  "status": "PENDING_REVIEW"
}
```

**Errors / rules:** 410 INVITATION_EXPIRED; 403 RECIPIENT_MISMATCH

**How it works:** Bind account and tenant patient link candidate; no medical content until reviewed.

##### M04A.05 — `GET /patient-portal/link-requests`

**Who can use it:** Verified patient account  
**Success:** HTTP 200

**Request:**

None — no request body.

**Response (data):**

```json
{
  "items": [
    {
      "id": "plr_01",
      "status": "PENDING_REVIEW"
    }
  ],
  "nextCursor": null
}
```

**Errors / rules:** 401 UNAUTHENTICATED

**How it works:** Own requests only.

##### M04A.06 — `POST /patients/{patientId}/portal-link-requests/{requestId}/review`

**Who can use it:** Authorized identity reviewer  
**Success:** HTTP 200

**Request:**

```json
{
  "decision": "APPROVE",
  "evidenceRef": "identity_review_01",
  "expectedVersion": 1,
  "reason": "Verified patient match"
}
```

**Response (data):**

```json
{
  "linkId": "plink_01",
  "status": "ACTIVE",
  "version": 1
}
```

**Errors / rules:** 409 DUPLICATE_LINK or VERSION_CONFLICT; 422 EVIDENCE_REQUIRED

**How it works:** Match hospital patient link, recipient and reviewed identity; separate proxy caregiver workflow.

##### M04A.07 — `POST /patients/{patientId}/portal-links/{linkId}/revoke`

**Who can use it:** Identity reviewer or linked patient with recent auth  
**Success:** HTTP 200

**Request:**

```json
{
  "reason": "Account compromised",
  "expectedVersion": 1
}
```

**Response (data):**

```json
{
  "id": "plink_01",
  "status": "REVOKED",
  "version": 2
}
```

**Errors / rules:** 404 LINK_NOT_FOUND; 409 VERSION_CONFLICT

**How it works:** Stop portal access and linked sessions; preserve care records and provide recovery.

##### M04A.08 — `GET /patient-portal/me`

**Who can use it:** Verified patient account  
**Success:** HTTP 200

**Request:**

None — no request body.

**Response (data):**

```json
{
  "userId": "usr_patient_01",
  "links": [
    {
      "id": "plink_01",
      "hospitalId": "hosp_01",
      "status": "ACTIVE",
      "displayName": "Synthetic Patient A"
    }
  ]
}
```

**Errors / rules:** 403 ACCOUNT_INACTIVE

**How it works:** Return only own links; empty links show verification onboarding screen.

##### M04A.09 — `GET /patient-portal/links/{linkId}/dashboard`

**Who can use it:** PATIENT or CAREGIVER with active scoped grant  
**Success:** HTTP 200

**Request:**

None — no request body.

**Response (data):**

```json
{
  "hospitalName": "Demo Hospital",
  "releasedReports": 2,
  "releasedSummaries": 1,
  "openCorrectionRequests": 0
}
```

**Errors / rules:** 404 LINK_NOT_FOUND

**How it works:** Self or caregiver grant, filtered to released and permitted data.

##### M04A.10 — `GET /patient-portal/links/{linkId}/encounters`

**Who can use it:** PATIENT or CAREGIVER with active scoped grant  
**Success:** HTTP 200

**Request:**

Query: cursor?, limit?

**Response (data):**

```json
{
  "items": [
    {
      "id": "enc_01",
      "status": "DISCHARGED",
      "admittedAt": "2026-12-01T09:00:00Z"
    }
  ],
  "nextCursor": null
}
```

**Errors / rules:** 404 LINK_NOT_FOUND

**How it works:** Only released encounter summaries; not raw internal notes.

##### M04A.11 — `GET /patient-portal/links/{linkId}/records`

**Who can use it:** PATIENT or CAREGIVER with active scoped grant  
**Success:** HTTP 200

**Request:**

Query: type?, cursor?, limit?

**Response (data):**

```json
{
  "items": [
    {
      "releaseId": "rel_01",
      "type": "DISCHARGE_SUMMARY",
      "status": "RELEASED"
    }
  ],
  "nextCursor": null
}
```

**Errors / rules:** 404 LINK_NOT_FOUND

**How it works:** Apply release and caregiver scope before pagination.

##### M04A.12 — `GET /patient-portal/links/{linkId}/records/{releaseId}`

**Who can use it:** PATIENT or CAREGIVER with active scoped grant  
**Success:** HTTP 200

**Request:**

None — no request body.

**Response (data):**

```json
{
  "releaseId": "rel_01",
  "type": "DISCHARGE_SUMMARY",
  "sourceVersion": 1,
  "summary": "Synthetic discharge summary"
}
```

**Errors / rules:** 404 RECORD_NOT_FOUND

**How it works:** Return only signed released revision; no AI draft.

##### M04A.13 — `POST /patient-portal/links/{linkId}/records/{releaseId}/download`

**Who can use it:** PATIENT or CAREGIVER with active scoped grant  
**Success:** HTTP 200

**Request:**

```json
{}
```

**Response (data):**

```json
{
  "downloadTicket": "<short-lived-ticket>",
  "expiresIn": 60
}
```

**Errors / rules:** 404 RECORD_NOT_FOUND; 410 RELEASE_WITHDRAWN

**How it works:** Authenticated download gateway rechecks current grant each fetch; no public storage URL.

##### M04A.14 — `POST /patients/{patientId}/record-releases`

**Who can use it:** Assigned DOCTOR or authorized records officer  
**Success:** HTTP 201

**Request:**

```json
{
  "sourceType": "DISCHARGE_SUMMARY",
  "sourceId": "summary_01",
  "sourceVersion": 1,
  "audience": "PATIENT",
  "reason": "Reviewed patient copy"
}
```

**Response (data):**

```json
{
  "id": "rel_01",
  "status": "RELEASED",
  "version": 1
}
```

**Errors / rules:** 422 UNVERIFIED_SOURCE; 403 SCOPE_DENIED

**How it works:** Release specific signed record revision; audit and enforce institutional disclosure policy.

##### M04A.15 — `POST /record-releases/{releaseId}/withdraw`

**Who can use it:** Authorized records officer / doctor  
**Success:** HTTP 200

**Request:**

```json
{
  "reason": "Incorrect revision; replacement pending",
  "expectedVersion": 1
}
```

**Response (data):**

```json
{
  "id": "rel_01",
  "status": "WITHDRAWN",
  "version": 2
}
```

**Errors / rules:** 409 VERSION_CONFLICT

**How it works:** Stop portal delivery; preserve original and disclose corrections under policy; prior downloads cannot be recalled.

##### M04A.16 — `POST /patient-portal/links/{linkId}/correction-requests`

**Who can use it:** PATIENT with verified self portal link  
**Success:** HTTP 201

**Request:**

```json
{
  "targetType": "DEMOGRAPHICS",
  "targetId": "pat_01",
  "description": "Please review spelling of my name"
}
```

**Response (data):**

```json
{
  "id": "cor_01",
  "status": "OPEN",
  "version": 1
}
```

**Errors / rules:** 422 INVALID_TARGET; 404 LINK_NOT_FOUND

**How it works:** Request review, not direct edit; clinical corrections must use authorized amendment workflow.

##### M04A.17 — `GET /patient-portal/links/{linkId}/correction-requests`

**Who can use it:** PATIENT with verified self portal link  
**Success:** HTTP 200

**Request:**

Query: status?, cursor?, limit?

**Response (data):**

```json
{
  "items": [
    {
      "id": "cor_01",
      "status": "OPEN"
    }
  ],
  "nextCursor": null
}
```

**Errors / rules:** 404 LINK_NOT_FOUND

**How it works:** Check the actor and resource scope, validate inputs, perform the action, and record the outcome where required.

##### M04A.18 — `GET /patients/{patientId}/correction-requests`

**Who can use it:** Authorized identity reviewer / assigned clinician  
**Success:** HTTP 200

**Request:**

Query: status?, cursor?, limit?

**Response (data):**

```json
{
  "items": [
    {
      "id": "cor_01",
      "targetType": "DEMOGRAPHICS",
      "status": "OPEN"
    }
  ],
  "nextCursor": null
}
```

**Errors / rules:** 404 PATIENT_NOT_FOUND

**How it works:** Check the actor and resource scope, validate inputs, perform the action, and record the outcome where required.

##### M04A.19 — `POST /correction-requests/{requestId}/review`

**Who can use it:** Authorized reviewer for target record type  
**Success:** HTTP 200

**Request:**

```json
{
  "decision": "ACCEPT",
  "amendmentRef": "amend_01",
  "reason": "Verified correction",
  "expectedVersion": 1
}
```

**Response (data):**

```json
{
  "id": "cor_01",
  "status": "RESOLVED",
  "version": 2
}
```

**Errors / rules:** 422 AMENDMENT_REQUIRED; 409 VERSION_CONFLICT

**How it works:** Use existing domain correction API first or atomically in same service; no destructive edit of signed records.

##### M04A.20 — `GET /patient-portal/links/{linkId}/sharing`

**Who can use it:** PATIENT with verified self portal link  
**Success:** HTTP 200

**Request:**

None — no request body.

**Response (data):**

```json
{
  "items": [
    {
      "id": "grant_01",
      "type": "REFERRAL",
      "status": "ACTIVE",
      "recipient": "Demo Receiving Hospital"
    }
  ],
  "nextCursor": null
}
```

**Errors / rules:** 404 LINK_NOT_FOUND

**How it works:** Show active and past scope/recipient/expiry; do not expose credentials.

##### M04A.21 — `POST /patient-portal/links/{linkId}/sharing-requests`

**Who can use it:** PATIENT with verified self portal link  
**Success:** HTTP 201

**Request:**

```json
{
  "recipientHospitalId": "hosp_02",
  "scope": [
    "DISCHARGE_SUMMARY"
  ],
  "purpose": "CONTINUITY_OF_CARE"
}
```

**Response (data):**

```json
{
  "id": "share_req_01",
  "status": "PENDING_REVIEW"
}
```

**Errors / rules:** 422 INVALID_SCOPE; 404 LINK_NOT_FOUND

**How it works:** Patient asks to share; clinician/consent staff validate and create grant through M18.

##### M04A.22 — `POST /patient-portal/links/{linkId}/sharing/{grantId}/revoke`

**Who can use it:** PATIENT with verified self portal link  
**Success:** HTTP 200

**Request:**

```json
{
  "reason": "Sharing permission withdrawn"
}
```

**Response (data):**

```json
{
  "id": "grant_01",
  "status": "REVOKED"
}
```

**Errors / rules:** 404 GRANT_NOT_FOUND

**How it works:** Revoke applicable grant and future retrieval, streams and downloads; preserve audit.

##### M04A.23 — `POST /patient-portal/links/{linkId}/caregiver-grants`

**Who can use it:** PATIENT with verified self portal link  
**Success:** HTTP 201

**Request:**

```json
{
  "recipientEmail": "caregiver@example.test",
  "scope": [
    "RELEASED_SUMMARIES"
  ],
  "expiresAt": "2026-12-31T00:00:00Z",
  "reason": "Patient requested support"
}
```

**Response (data):**

```json
{
  "id": "cg_01",
  "status": "PENDING_ACCEPTANCE",
  "version": 1
}
```

**Errors / rules:** 422 INVALID_SCOPE; 403 REPRESENTATION_REVIEW_REQUIRED

**How it works:** Verify capacity/authority as applicable and use invitation. Minor/guardian cases require institutional review.

##### M04A.24 — `POST /patient-portal/caregiver-grants/accept`

**Who can use it:** Verified recipient account  
**Success:** HTTP 200

**Request:**

```json
{
  "token": "<caregiver-token>"
}
```

**Response (data):**

```json
{
  "id": "cg_01",
  "status": "ACTIVE"
}
```

**Errors / rules:** 410 INVITATION_EXPIRED; 403 RECIPIENT_MISMATCH

**How it works:** Bind recipient and verify active source link; no broad patient permission.

##### M04A.25 — `GET /patient-portal/caregiver-grants`

**Who can use it:** Verified patient or caregiver account  
**Success:** HTTP 200

**Request:**

None — no request body.

**Response (data):**

```json
{
  "items": [
    {
      "id": "cg_01",
      "linkId": "plink_01",
      "status": "ACTIVE",
      "scope": [
        "RELEASED_SUMMARIES"
      ]
    }
  ],
  "nextCursor": null
}
```

**Errors / rules:** 403 ACCOUNT_INACTIVE

**How it works:** Only grants issued by or to actor.

##### M04A.26 — `POST /patient-portal/caregiver-grants/{grantId}/revoke`

**Who can use it:** Grant issuer or authorized representative  
**Success:** HTTP 200

**Request:**

```json
{
  "reason": "Access no longer required",
  "expectedVersion": 1
}
```

**Response (data):**

```json
{
  "id": "cg_01",
  "status": "REVOKED",
  "version": 2
}
```

**Errors / rules:** 404 GRANT_NOT_FOUND; 409 VERSION_CONFLICT

**How it works:** Invalidate access immediately; no deletion of clinical data.

**Acceptance tests:** Signup alone cannot access records; portal invitation cannot be reused or accepted by wrong account; duplicate patient links require manual review; only released record versions visible; withdrawn release no longer downloadable; caregiver expiry/revoke denies next call; patient cannot edit medication orders, clinical notes or signed reports; correction creates review request; revoked session or banned account cannot access portal; patient with no login can still be admitted and receive care via approved processes.

### M05 — Medication catalog, orders, schedules and task list

**Dependencies:** M04 and the minimal M08 interaction-check fixture API (build the fixture before orders; expand M08 after M05)  
**Owner:** Abhishek with clinical reviewer  
**Status:** Planned

**In simple words — Doctor prescriptions and nurse medication tasks:** Turn a doctor’s prescription into individual scheduled dose tasks for the nurse.

#### Implementation steps

1. Create a demo medicine catalog with product codes, barcodes and units.
2. Let an authorized doctor enter an order with dose, route, times, start and end dates. Run allergy and interaction checks before approval.
3. Create one database row for each planned dose. Give each occurrence a unique key to avoid duplicates.
4. If a doctor changes an order, keep the old version and cancel only eligible future tasks; preserve completed and uncertain doses.
5. Show due, overdue and blocked tasks to nurses. Leave complex dosing schedules outside the first release.

**How to know this module is working:** Running the scheduler twice does not create duplicate doses; nurses cannot prescribe; completed history cannot be overwritten.

<details>
<summary>Exact engineering steps and acceptance tests (developer reference)</summary>

1. Seed clearly labeled fictional products, versioned product code/barcode mapping and allowed units; OCR/YOLO can propose candidate identity but cannot authorize unknown product.
2. Doctor enters signed order, route, explicit schedule/timezone, start/end, dose unit and indication; check current allergies and interaction review.
3. Generate bounded horizon occurrence rows with deterministic occurrence key; do not use last administration time alone as schedule authority.
4. Order modifications create revision, cancel only future unstarted occurrences, prevent conflicts with reserved/in-progress/review-required events; never silently shift due time.
5. Nurse task list shows due/overdue/blocked states; scheduler uses unique index and reconciliation job. PRN, titration, infusions, split doses and complex schedules excluded until separately specified.

**Acceptance criteria:** Duplicate schedule job creates no duplicate doses; cancel never changes administered history; invalid dose or route rejected; unauthorized nurse cannot prescribe.

</details>

#### API contracts

##### M05.01 — `POST /medication-catalog/products`

**Authorization:** Authorized catalog admin  
**Success:** HTTP 201

**Request:**

```json
{
  "code": "DEMO-DRUG-A",
  "name": "Synthetic Product A",
  "strength": {
    "value": "1",
    "unit": "demo-unit"
  },
  "form": "DEMO_VIAL",
  "barcodes": [
    "DEMO-VIAL-A"
  ]
}
```

**Response (data):**

```json
{
  "id": "prod_01",
  "code": "DEMO-DRUG-A",
  "version": 1
}
```

**Errors / constraints:** 409 BARCODE_ALREADY_MAPPED; 422 UNSUPPORTED_UNIT.

##### M05.02 — `GET /medication-catalog/products`

**Authorization:** Clinical staff  
**Success:** HTTP 200

**Request:**

Query: q?, limit?, cursor?

**Response (data):**

```json
{
  "items": [
    {
      "id": "prod_01",
      "name": "Synthetic Product A",
      "code": "DEMO-DRUG-A"
    }
  ],
  "nextCursor": null
}
```

**Errors / constraints:** 403 FORBIDDEN.

##### M05.03 — `POST /admissions/{admissionId}/medication-orders`

**Authorization:** DOCTOR  
**Success:** HTTP 201

**Request:**

```json
{
  "productId": "prod_01",
  "dose": {
    "value": "1",
    "unit": "demo-unit"
  },
  "route": "DEMO_ROUTE",
  "schedule": {
    "type": "EXPLICIT_TIMES",
    "times": [
      "2026-12-01T10:00:00Z",
      "2026-12-01T22:00:00Z"
    ]
  },
  "indication": "Synthetic test only",
  "interactionCheckId": "check_01"
}
```

**Response (data):**

```json
{
  "id": "ord_01",
  "revisionId": "rev_01",
  "status": "ACTIVE",
  "doseEventIds": [
    "dose_01",
    "dose_02"
  ],
  "version": 1
}
```

**Errors / constraints:** 422 UNSUPPORTED_SCHEDULE or INTERACTION_REVIEW_REQUIRED; 409 ADMISSION_CLOSED.

##### M05.04 — `GET /admissions/{admissionId}/medication-orders`

**Authorization:** Assigned clinical staff  
**Success:** HTTP 200

**Request:**

Query: status?, cursor?, limit?

**Response (data):**

```json
{
  "items": [
    {
      "id": "ord_01",
      "productId": "prod_01",
      "status": "ACTIVE",
      "version": 1
    }
  ],
  "nextCursor": null
}
```

**Errors / constraints:** 404 ADMISSION_NOT_FOUND.

##### M05.05 — `POST /medication-orders/{orderId}/revisions`

**Authorization:** DOCTOR  
**Success:** HTTP 201

**Request:**

```json
{
  "dose": {
    "value": "1",
    "unit": "demo-unit"
  },
  "route": "DEMO_ROUTE",
  "schedule": {
    "type": "EXPLICIT_TIMES",
    "times": [
      "2026-12-02T10:00:00Z"
    ]
  },
  "interactionCheckId": "check_02",
  "reason": "Synthetic revision",
  "expectedVersion": 1
}
```

**Response (data):**

```json
{
  "id": "ord_01",
  "revisionId": "rev_02",
  "version": 2
}
```

**Errors / constraints:** 409 ACTIVE_DOSE_LOCK or VERSION_CONFLICT; 422 INTERACTION_REVIEW_REQUIRED.

##### M05.06 — `POST /medication-orders/{orderId}/cancel`

**Authorization:** DOCTOR  
**Success:** HTTP 200

**Request:**

```json
{
  "reason": "Synthetic discontinuation",
  "expectedVersion": 2
}
```

**Response (data):**

```json
{
  "id": "ord_01",
  "status": "CANCELLED",
  "version": 3
}
```

**Errors / constraints:** 409 ACTIVE_DOSE_REVIEW_REQUIRED.

##### M05.07 — `GET /admissions/{admissionId}/dose-events`

**Authorization:** Assigned clinical staff  
**Success:** HTTP 200

**Request:**

Query: from?, to?, status?, cursor?, limit?

**Response (data):**

```json
{
  "items": [
    {
      "id": "dose_01",
      "orderId": "ord_01",
      "dueAt": "2026-12-01T10:00:00Z",
      "status": "SCHEDULED",
      "version": 1
    }
  ],
  "nextCursor": null
}
```

**Errors / constraints:** 422 INVALID_TIME_RANGE.

##### M05.08 — `GET /medication-dose-events/{doseEventId}`

**Authorization:** Assigned clinical staff  
**Success:** HTTP 200

**Request:**

None

**Response (data):**

```json
{
  "id": "dose_01",
  "orderId": "ord_01",
  "status": "SCHEDULED",
  "dueAt": "2026-12-01T10:00:00Z",
  "version": 1
}
```

**Errors / constraints:** 404 DOSE_NOT_FOUND.

### M06 — Scan-to-administer dual lock and atomic administration

**Dependencies:** M05  
**Owner:** Abhishek  
**Status:** Planned

**In simple words — Scan medication and stop duplicate electronic approval:** Make two checks: the patient and medicine must match the order, and only one nurse may obtain permission for the same scheduled dose.

#### Implementation steps

1. Scan the patient wristband, then the medicine barcode. Show the exact prescribed dose task for review.
2. Send the reserve request to the server. The server checks identity, assignment, order, timing and safety review, then locks the dose row in PostgreSQL.
3. Save the reservation token, owner, expiry, audit entry and retry result in one database transaction.
4. Use a separate online start request before a simulated administration and a confirm request to record the outcome afterward.
5. If a request fails or the result is uncertain, show a warning and send it for review. Never repeat a physical action based on a timeout or approve it offline.
6. Test two nurses trying to reserve the same dose at the same time using real PostgreSQL.

**How to know this module is working:** One of 100 simultaneous reservation requests with different keys succeeds; incorrect scans fail; uncertain results are never automatically released.

<details>
<summary>Exact engineering steps and acceptance tests (developer reference)</summary>

1. Build scanner UI with patient wristband then product barcode; fetch exact dose event and display ordered identity, dose, route, due time, allergies, review flags.
2. Reserve checks role, assignment, active admission/order/revision, scanned patient/product, eligible schedule and policy; lock admission/order/dose rows consistently in PostgreSQL.
3. Persist reservation owner, opaque token digest and expiry, audit and idempotent result in one transaction.
4. Separate start authorization BEFORE physical action and final outcome AFTER simulated action. Require fresh server state and valid owner token for start.
5. Confirm consumes reservation outcome; network ambiguity enters reconciliation rather than retrying physical action. Implement red conflict modal, accessible audible cue and no offline reserve/start.
6. Test using real PostgreSQL concurrent clients, not mocked repositories.

**Acceptance criteria:** 100 simultaneous reserve requests for one dose: exactly one success with distinct keys; mismatched band or product never reserves; lost response replays same idempotent result; start after expiry rejected; no second finalized administration.

</details>

#### API contracts

##### M06.01 — `POST /medication-administrations/scan-check`

**Authorization:** NURSE  
**Success:** HTTP 200

**Request:**

```json
{
  "admissionId": "enc_01",
  "doseEventId": "dose_01",
  "patientScan": "ms:wristband:<opaque-token>",
  "medicationScan": "DEMO-VIAL-A"
}
```

**Response (data):**

```json
{
  "status": "MATCHED",
  "doseEventId": "dose_01",
  "productId": "prod_01",
  "dose": {
    "value": "1",
    "unit": "demo-unit"
  },
  "canAttemptReservation": true
}
```

**Errors / constraints:** 422 SCAN_MISMATCH or UNKNOWN_BARCODE; 409 DOSE_UNAVAILABLE. Advisory only, not a lock.

##### M06.02 — `POST /medication-administrations/reserve`

**Authorization:** NURSE + Idempotency-Key  
**Success:** HTTP 200

**Request:**

```json
{
  "admissionId": "enc_01",
  "medicationOrderId": "ord_01",
  "doseEventId": "dose_01",
  "patientScan": "ms:wristband:<opaque-token>",
  "medicationScan": "DEMO-VIAL-A"
}
```

**Response (data):**

```json
{
  "doseEventId": "dose_01",
  "status": "RESERVED",
  "reservationToken": "<opaque-token>",
  "expiresAt": "2026-12-01T10:02:00Z",
  "version": 2
}
```

**Errors / constraints:** 409 DOSE_ALREADY_RESERVED, DOSE_ALREADY_ADMINISTERED, DOSE_REVIEW_REQUIRED, ORDER_CHANGED; 422 SCAN_MISMATCH or SAFETY_REVIEW_REQUIRED; 503 SAFETY_LOCK_UNAVAILABLE.

##### M06.03 — `POST /medication-administrations/start`

**Authorization:** NURSE owner + Idempotency-Key  
**Success:** HTTP 200

**Request:**

```json
{
  "doseEventId": "dose_01",
  "reservationToken": "<opaque-token>",
  "bedsideChecksAcknowledged": true,
  "expectedVersion": 2
}
```

**Response (data):**

```json
{
  "doseEventId": "dose_01",
  "status": "IN_PROGRESS",
  "startedAt": "2026-12-01T10:00:30Z",
  "version": 3
}
```

**Errors / constraints:** 409 RESERVATION_EXPIRED, VERSION_CONFLICT; 403 RESERVATION_OWNER_MISMATCH; 503 SAFETY_LOCK_UNAVAILABLE.

##### M06.04 — `POST /medication-administrations/confirm`

**Authorization:** NURSE owner + Idempotency-Key  
**Success:** HTTP 200

**Request:**

```json
{
  "doseEventId": "dose_01",
  "reservationToken": "<opaque-token>",
  "outcome": "ADMINISTERED",
  "observedAt": "2026-12-01T10:00:40Z",
  "expectedVersion": 3
}
```

**Response (data):**

```json
{
  "administrationId": "admin_01",
  "doseEventId": "dose_01",
  "status": "ADMINISTERED",
  "recordedAt": "2026-12-01T10:00:42Z",
  "version": 4
}
```

**Errors / constraints:** 409 DOSE_REVIEW_REQUIRED or INVALID_TRANSITION; 422 OUTCOME_INVALID. Other outcomes NOT_ADMINISTERED or UNCERTAIN route to REVIEW_REQUIRED, with reason.

##### M06.05 — `POST /medication-administrations/release`

**Authorization:** NURSE owner + Idempotency-Key  
**Success:** HTTP 200

**Request:**

```json
{
  "doseEventId": "dose_01",
  "reservationToken": "<opaque-token>",
  "confirmedNotStarted": true,
  "reason": "Synthetic scan abandoned",
  "expectedVersion": 2
}
```

**Response (data):**

```json
{
  "doseEventId": "dose_01",
  "status": "SCHEDULED",
  "version": 3
}
```

**Errors / constraints:** 409 ALREADY_STARTED or RESERVATION_EXPIRED; uncertain state enters review.

##### M06.06 — `GET /admissions/{admissionId}/medication-administrations`

**Authorization:** Assigned clinical staff  
**Success:** HTTP 200

**Request:**

Query: from?, to?, cursor?, limit?

**Response (data):**

```json
{
  "items": [
    {
      "id": "admin_01",
      "doseEventId": "dose_01",
      "outcome": "ADMINISTERED",
      "observedAt": "2026-12-01T10:00:40Z"
    }
  ],
  "nextCursor": null
}
```

**Errors / constraints:** 404 ADMISSION_NOT_FOUND.

### M07 — Missed doses, downtime and reconciliation

**Dependencies:** M06  
**Owner:** Abhishek  
**Status:** Planned

**In simple words — Missed medication and internet outages:** Handle overdue tasks and situations where the system cannot tell whether a dose was actually given.

#### Implementation steps

1. Show overdue tasks separately from the dose’s actual administration status.
2. If a reservation expires or a started dose is not confirmed, mark it REVIEW_REQUIRED, not automatically available again.
3. If the server is unreachable, show that electronic safety checks are unavailable. Follow the hospital’s approved downtime procedure in any future authorized use.
4. After recovery, an authorized reviewer checks evidence and records the outcome; allow a new attempt only if non-administration is verified and policy allows it.
5. Resolve uncertain records before discharge; save corrections as new records rather than deleting history.
6. Create a review queue for overdue and uncertain doses.

**How to know this module is working:** Offline actions cannot record an administered dose; retrying the same downtime record does not create a duplicate.

<details>
<summary>Exact engineering steps and acceptance tests (developer reference)</summary>

1. Use overdue flag/task independent of administration state.
2. Expiry worker moves expired RESERVED and timed-out IN_PROGRESS to REVIEW_REQUIRED, never blindly to SCHEDULED.
3. Offline observation queue does not contain executable medication actions; show electronic lock unavailable and hospital-approved downtime instructions.
4. On recovery, authorized reviewer records evidence, outcome and approval; close missed/not-given with reason, or reissue only after verified non-administration and policy approval.
5. Reconcile all uncertain/downtime records before discharge or transfer; append correction not deletion.
6. Add operational dashboard for overdue, stuck and review-required doses.

**Acceptance criteria:** No offline mutation can create ADMINISTERED; stale start response never prompts repeat; review only authorized; original audit survives correction; duplicate downtime record is idempotent.

</details>

#### API contracts

##### M07.01 — `GET /medication-dose-events/review-queue`

**Authorization:** DOCTOR/authorized clinical reviewer  
**Success:** HTTP 200

**Request:**

Query: wardId?, reason?, cursor?, limit?

**Response (data):**

```json
{
  "items": [
    {
      "id": "dose_03",
      "status": "REVIEW_REQUIRED",
      "reason": "RESERVATION_EXPIRED"
    }
  ],
  "nextCursor": null
}
```

**Errors / constraints:** 403 SCOPE_DENIED.

##### M07.02 — `POST /medication-dose-events/{doseEventId}/reconcile`

**Authorization:** Authorized clinical reviewer + Idempotency-Key  
**Success:** HTTP 200

**Request:**

```json
{
  "resolution": "VERIFIED_NOT_ADMINISTERED",
  "disposition": "REISSUE",
  "evidenceRefs": [
    "fixture_evidence"
  ],
  "reason": "Synthetic review",
  "expectedVersion": 4
}
```

**Response (data):**

```json
{
  "id": "rec_01",
  "doseEventId": "dose_03",
  "status": "SCHEDULED",
  "version": 5
}
```

**Errors / constraints:** 409 REVIEW_NOT_PENDING or SECOND_APPROVAL_REQUIRED; 422 EVIDENCE_REQUIRED. Alternative disposition CLOSE_NOT_GIVEN; verified administration closes as ADMINISTERED; unknown stays blocked.

##### M07.03 — `POST /medication-dose-events/{doseEventId}/downtime-records`

**Authorization:** Assigned nurse/reviewer + Idempotency-Key  
**Success:** HTTP 201

**Request:**

```json
{
  "outcome": "UNCERTAIN",
  "observedAt": "2026-12-01T10:10:00Z",
  "evidenceRef": "fixture_paper_record",
  "reason": "Synthetic network outage"
}
```

**Response (data):**

```json
{
  "id": "down_01",
  "doseEventId": "dose_03",
  "status": "REVIEW_REQUIRED"
}
```

**Errors / constraints:** 409 EXISTING_FINAL_OUTCOME; 422 EVIDENCE_REQUIRED. Not an administration authorization.

##### M07.04 — `GET /wards/{wardId}/medication-tasks`

**Authorization:** Assigned clinical staff  
**Success:** HTTP 200

**Request:**

Query: from?, to?, overdue?, cursor?, limit?

**Response (data):**

```json
{
  "items": [
    {
      "doseEventId": "dose_03",
      "status": "REVIEW_REQUIRED",
      "overdue": true
    }
  ],
  "nextCursor": null
}
```

**Errors / constraints:** 403 SCOPE_DENIED.

### M08 — Drug-drug, drug-food and diet safety review

**Dependencies:** M04 for the minimal synthetic interaction-check fixture; M05 for full active-order integration  
**Owner:** Akanksha + Abhishek  
**Status:** Planned

**In simple words — Medicine, food and allergy checks:** Help doctors review possible medicine-medicine, medicine-food and allergy conflicts.

#### Implementation steps

1. Use fake, clearly labeled interaction rules for the demo. For real use, obtain licensed sources and clinical review.
2. Convert medicine and food names to known codes and compare them with current orders, allergy records and verified notes.
3. If a medicine is unknown or evidence is missing, return UNKNOWN instead of saying it is safe.
4. Save the exact rule version and order details used in a check. Recheck if the order or its context changes.
5. Let nurses record food intake and doctors review warnings. AI can suggest a review but cannot clear a block or prescribe.

**How to know this module is working:** Known test conflicts are flagged; unknown entries are not called safe; outdated checks cannot approve a changed order.

<details>
<summary>Exact engineering steps and acceptance tests (developer reference)</summary>

1. Build versioned clinically reviewed rules from licensed authoritative sources; do not infer interaction severity directly from LLM/OpenFDA label mentions.
2. Normalize coded product/ingredient and food entries; compare against active order list, allergies and relevant verified notes. Unknown ingredient or missing source returns UNKNOWN, not SAFE.
3. MVP synthetic fixtures simulate review; later use BioBERT/ClinicalBERT only to extract candidate relations for approval.
4. Hash exact evaluated order context and rule version; bind check to order creation and recheck under transaction if context changed.
5. Nurse diet/food log records observation; AI can draft a warning, not prescribe or change diet. Doctor acknowledges review with rationale; prohibited policy cannot be overridden.

**Acceptance criteria:** Known synthetic conflict flagged; unrecognized code UNKNOWN; stale check rejected; no AI-only unblock; diet entry never creates order.

</details>

#### API contracts

##### M08.01 — `POST /admissions/{admissionId}/interaction-checks`

**Authorization:** DOCTOR / NURSE for diet review  
**Success:** HTTP 201

**Request:**

```json
{
  "kind": "MEDICATION",
  "candidateProductId": "prod_01",
  "candidateDose": {
    "value": "1",
    "unit": "demo-unit"
  },
  "route": "DEMO_ROUTE"
}
```

**Response (data):**

```json
{
  "id": "check_01",
  "status": "REVIEW_REQUIRED",
  "ruleVersion": "demo-rules-v1",
  "findings": [
    {
      "code": "DEMO_RULE_01",
      "severity": "UNKNOWN",
      "evidenceRef": "fixture_rule"
    }
  ],
  "coverage": "PARTIAL"
}
```

**Errors / constraints:** 422 UNKNOWN_PRODUCT; 503 RULES_UNAVAILABLE. DIET kind accepts foodCode instead.

##### M08.02 — `POST /interaction-checks/{checkId}/review`

**Authorization:** DOCTOR  
**Success:** HTTP 200

**Request:**

```json
{
  "decision": "ACKNOWLEDGED",
  "reason": "Synthetic rule review"
}
```

**Response (data):**

```json
{
  "id": "check_01",
  "status": "REVIEWED",
  "decision": "ACKNOWLEDGED"
}
```

**Errors / constraints:** 409 CONTEXT_CHANGED; 422 NON_OVERRIDABLE_POLICY.

##### M08.03 — `POST /admissions/{admissionId}/diet-logs`

**Authorization:** Assigned nurse + Idempotency-Key  
**Success:** HTTP 201

**Request:**

```json
{
  "foodCode": "DEMO-FOOD-01",
  "description": "Synthetic meal",
  "observedAt": "2026-12-01T12:00:00Z",
  "interactionCheckId": "check_food_01"
}
```

**Response (data):**

```json
{
  "id": "diet_01",
  "status": "RECORDED",
  "reviewStatus": "REVIEW_REQUIRED"
}
```

**Errors / constraints:** 422 INVALID_TIME or MISSING_CHECK; logging factual intake does not imply authorization.

##### M08.04 — `GET /admissions/{admissionId}/diet-logs`

**Authorization:** Assigned care staff  
**Success:** HTTP 200

**Request:**

Query: from?, to?, limit?, cursor?

**Response (data):**

```json
{
  "items": [
    {
      "id": "diet_01",
      "description": "Synthetic meal",
      "reviewStatus": "REVIEW_REQUIRED"
    }
  ],
  "nextCursor": null
}
```

**Errors / constraints:** 404 ADMISSION_NOT_FOUND.

### M09 — Device provisioning, assignment and MQTT ingestion

**Dependencies:** M03–M04  
**Owner:** Aman + Abhishek  
**Status:** Planned

**In simple words — Connect IoT devices to the system:** Set up ESP32 devices or a Python simulator to send fake vital readings through MQTT.

#### Implementation steps

1. Write firmware for bench testing and a simulator for demos; give each message a device ID, boot ID, sequence and timestamp.
2. Create a separate credential for each device and restrict which MQTT topic it can use.
3. Assign the device to one admission for a specific time period. The server, not the sensor, decides which patient owns a reading.
4. Send readings with MQTT QoS 1 and retry safely; ignore duplicate messages using device, boot and sequence IDs.
5. Reject wrong-device messages, invalid assignments and malformed readings. Save quality and time information.
6. Show online/offline device status and label simulated readings clearly. Do not attach experimental devices to people.

**How to know this module is working:** Replayed messages are stored only once; a device moved to a new patient cannot mix their records.

<details>
<summary>Exact engineering steps and acceptance tests (developer reference)</summary>

1. Implement bench-only ESP32 firmware and deterministic Python simulator, device boot ID, monotonic sequence, UTC sync state and local ring buffer.
2. Provision unique device identity/credential with restricted MQTT topic; rotate/revoke credentials, no shared hardcoded secrets.
3. Bind device to encounter with start/end; validate historical binding at measurement time and current credential; do not trust patient ID supplied by device.
4. MQTT QoS 1, bounded payload, dedupe by device/boot/seq, backoff with jitter, retain=false for clinical telemetry.
5. Worker validates schema, records ingress and measured time, quality and source; rejects or quarantines mismatches.
6. Implement device health dashboard and simulator controls behind DEMO_MODE only.

**Acceptance criteria:** Replay produces one sample; wrong topic/device rejected; reassigned device cannot contaminate previous patient; stale/invalid signal not normal; simulator labeled.

</details>

#### API contracts

##### M09.01 — `POST /devices`

**Authorization:** HOSPITAL_ADMIN  
**Success:** HTTP 201

**Request:**

```json
{
  "serial": "DEMO-ESP-001",
  "kind": "ESP32",
  "source": "SIMULATOR",
  "capabilities": [
    "HR",
    "SPO2"
  ]
}
```

**Response (data):**

```json
{
  "id": "dev_01",
  "status": "PROVISIONING"
}
```

**Errors / constraints:** 409 DEVICE_SERIAL_EXISTS.

##### M09.02 — `POST /devices/{deviceId}/credentials`

**Authorization:** Device admin  
**Success:** HTTP 201

**Request:**

```json
{
  "credentialType": "CLIENT_CERT",
  "csrPem": "<device-CSR>"
}
```

**Response (data):**

```json
{
  "credentialId": "cred_01",
  "certificatePem": "<signed-cert>",
  "expiresAt": "2027-01-01T00:00:00Z"
}
```

**Errors / constraints:** 422 INVALID_CSR; 409 DEVICE_REVOKED. Private key stays on device.

##### M09.03 — `POST /devices/{deviceId}/assignments`

**Authorization:** Assigned authorized staff  
**Success:** HTTP 201

**Request:**

```json
{
  "admissionId": "enc_01",
  "effectiveFrom": "2026-12-01T09:00:00Z"
}
```

**Response (data):**

```json
{
  "id": "da_01",
  "deviceId": "dev_01",
  "admissionId": "enc_01",
  "status": "ACTIVE"
}
```

**Errors / constraints:** 409 DEVICE_ALREADY_ASSIGNED; 422 ADMISSION_CLOSED.

##### M09.04 — `POST /devices/{deviceId}/assignments/{assignmentId}/end`

**Authorization:** Assigned authorized staff  
**Success:** HTTP 200

**Request:**

```json
{
  "reason": "Synthetic device removal"
}
```

**Response (data):**

```json
{
  "id": "da_01",
  "status": "ENDED"
}
```

**Errors / constraints:** 409 ASSIGNMENT_ALREADY_ENDED.

##### M09.05 — `POST /devices/{deviceId}/revoke`

**Authorization:** Device admin  
**Success:** HTTP 200

**Request:**

```json
{
  "reason": "Synthetic credential rotation"
}
```

**Response (data):**

```json
{
  "id": "dev_01",
  "status": "REVOKED"
}
```

**Errors / constraints:** 404 DEVICE_NOT_FOUND. Revoke broker ACL/session too.

##### M09.06 — `GET /devices`

**Authorization:** Assigned ward staff / admin metadata scope  
**Success:** HTTP 200

**Request:**

Query: wardId?, status?, limit?, cursor?

**Response (data):**

```json
{
  "items": [
    {
      "id": "dev_01",
      "status": "ONLINE",
      "source": "SIMULATOR",
      "lastSeenAt": "2026-12-01T10:00:00Z"
    }
  ],
  "nextCursor": null
}
```

**Errors / constraints:** 403 SCOPE_DENIED.

##### M09.07 — `POST /demo/telemetry-scenarios`

**Authorization:** Demo operator + DEMO_MODE  
**Success:** HTTP 202

**Request:**

```json
{
  "deviceId": "dev_01",
  "scenario": "SYNTHETIC_DETERIORATION",
  "durationSeconds": 30
}
```

**Response (data):**

```json
{
  "jobId": "job_sim_01",
  "status": "QUEUED"
}
```

**Errors / constraints:** 404 if demo disabled; 422 REAL_DEVICE_NOT_ALLOWED.

### M10 — Telemetry storage, observations and live vitals

**Dependencies:** M09  
**Owner:** Aman + Abhishek  
**Status:** Planned

**In simple words — Store and display patient vitals:** Save sensor readings and staff-entered observations, and display current and past values.

#### Implementation steps

1. Create time-series storage and a unique record of received messages so duplicates are ignored.
2. Check units and quality; store when a reading was measured and when the server received it.
3. Store ECG data as small waveform chunks with sampling and lead information instead of huge JSON messages.
4. Allow authorized staff to enter observations manually; preserve original values when correcting them.
5. Add APIs for latest values, history and trends. Simplify chart data only for display, not for medical scoring.
6. Display a clear warning when readings are old, missing or unreliable.

**How to know this module is working:** Late data cannot replace newer readings; missing values are not treated as zero; other patients’ readings are inaccessible.

<details>
<summary>Exact engineering steps and acceptance tests (developer reference)</summary>

1. Create dedupe ledger and partitioned/hypertable storage; transactional sample + ledger + outbox with partition-compatible unique key.
2. Validate metric units and sensor quality, maintain latest snapshot with age and event ordering; late data must not overwrite newer measurements.
3. Store ECG waveform as bounded chunks/artifact with sampling frequency and lead metadata, not enormous JSON every second.
4. Support manual observations with clinician role, value/unit, observed time, provenance and review status; corrections append revision.
5. Provide latest/trend/history APIs, downsample display only, never feed chart aggregates into clinical scoring.
6. Render stale/missing/bad quality states in nurse and doctor dashboard.

**Acceptance criteria:** Clock skew quarantine; null not zero; wrong units rejected; no cross-patient data; history bounded; late messages preserved but do not overwrite current.

</details>

#### API contracts

##### M10.01 — `POST /telemetry/batches`

**Authorization:** DEVICE or ingestion service + Idempotency-Key  
**Success:** HTTP 202

**Request:**

```json
{
  "deviceId": "dev_01",
  "bootId": "boot_01",
  "samples": [
    {
      "seq": 1,
      "measuredAt": "2026-12-01T10:00:00Z",
      "metrics": [
        {
          "code": "HR",
          "value": 82,
          "unit": "beats/min",
          "quality": "VALID"
        }
      ]
    }
  ]
}
```

**Response (data):**

```json
{
  "batchId": "batch_01",
  "accepted": 1,
  "duplicates": 0,
  "rejected": 0
}
```

**Errors / constraints:** 422 INVALID_METRIC or NO_ACTIVE_ASSIGNMENT; 503 INGEST_UNAVAILABLE. 202 means durable queued/accepted, not scored.

##### M10.02 — `GET /admissions/{admissionId}/vitals/latest`

**Authorization:** Assigned clinical staff  
**Success:** HTTP 200

**Request:**

None

**Response (data):**

```json
{
  "asOf": "2026-12-01T10:00:01Z",
  "metrics": [
    {
      "code": "HR",
      "value": 82,
      "unit": "beats/min",
      "observedAt": "2026-12-01T10:00:00Z",
      "quality": "VALID",
      "freshness": "FRESH",
      "source": "SIMULATOR"
    }
  ]
}
```

**Errors / constraints:** 404 ADMISSION_NOT_FOUND. Missing metric returns explicit MISSING in configured profile.

##### M10.03 — `GET /admissions/{admissionId}/vitals/history`

**Authorization:** Assigned clinical staff  
**Success:** HTTP 200

**Request:**

Query: metric=HR, from, to, resolution=RAW|MINUTE|HOUR, cursor?, limit?

**Response (data):**

```json
{
  "items": [
    {
      "time": "2026-12-01T10:00:00Z",
      "value": 82,
      "unit": "beats/min",
      "quality": "VALID"
    }
  ],
  "nextCursor": null
}
```

**Errors / constraints:** 422 RANGE_TOO_LARGE or INVALID_METRIC.

##### M10.04 — `POST /admissions/{admissionId}/observations`

**Authorization:** Assigned nurse/doctor + Idempotency-Key  
**Success:** HTTP 201

**Request:**

```json
{
  "code": "RESP_RATE",
  "value": 18,
  "unit": "breaths/min",
  "observedAt": "2026-12-01T10:00:00Z",
  "source": "MANUAL",
  "quality": "REVIEWED"
}
```

**Response (data):**

```json
{
  "id": "obs_01",
  "verificationStatus": "VERIFIED",
  "version": 1
}
```

**Errors / constraints:** 422 INVALID_UNIT or TIME_INVALID; 409 ADMISSION_CLOSED.

##### M10.05 — `GET /admissions/{admissionId}/observations`

**Authorization:** Assigned care staff  
**Success:** HTTP 200

**Request:**

Query: code?, from?, to?, cursor?, limit?

**Response (data):**

```json
{
  "items": [
    {
      "id": "obs_01",
      "code": "RESP_RATE",
      "value": 18,
      "unit": "breaths/min",
      "version": 1
    }
  ],
  "nextCursor": null
}
```

**Errors / constraints:** 404 ADMISSION_NOT_FOUND.

##### M10.06 — `POST /observations/{observationId}/amendments`

**Authorization:** Authorized clinical reviewer  
**Success:** HTTP 201

**Request:**

```json
{
  "value": 19,
  "unit": "breaths/min",
  "reason": "Synthetic correction",
  "expectedVersion": 1
}
```

**Response (data):**

```json
{
  "id": "obs_02",
  "supersedes": "obs_01",
  "version": 2,
  "verificationStatus": "VERIFIED"
}
```

**Errors / constraints:** 409 VERSION_CONFLICT; 422 REASON_REQUIRED.

##### M10.07 — `GET /admissions/{admissionId}/ecg-artifacts`

**Authorization:** Assigned clinical staff  
**Success:** HTTP 200

**Request:**

Query: from?, to?, limit?, cursor?

**Response (data):**

```json
{
  "items": [
    {
      "id": "ecg_01",
      "leadConfiguration": "SIMULATED_SINGLE_LEAD",
      "sampleRateHz": 250,
      "quality": "RESEARCH_ONLY"
    }
  ],
  "nextCursor": null
}
```

**Errors / constraints:** 404 ADMISSION_NOT_FOUND.

### M11 — NEWS2 and experimental deterioration engine

**Dependencies:** M10  
**Owner:** Akanksha + Aman  
**Status:** Planned

**In simple words — Early warning score and AI research:** Calculate a rule-based NEWS2 assessment only from complete, eligible observations. Keep experimental AI predictions separate.

#### Implementation steps

1. Get a clinician-approved NEWS2 rule table and test cases before implementing scoring.
2. Collect respiratory rate, oxygen saturation, systolic blood pressure, pulse, temperature, consciousness/new confusion and oxygen support status.
3. Check freshness, reliability, units, eligibility and required oxygen scale. If a field is missing, return INCOMPLETE with no total.
4. Calculate the score using the approved rule table; save the source readings and rule version.
5. Train a separate research model using patient-level data splits and an explicit prediction target; compare results against baselines. Do not use it to make clinical decisions.

**How to know this module is working:** Approved test cases match; missing blood pressure never creates a normal score; AI failure does not disable the rule-based warning workflow.

<details>
<summary>Exact engineering steps and acceptance tests (developer reference)</summary>

1. Obtain clinician-approved NEWS2 specification and test fixtures; version the rule table; support only eligible populations and oxygen-scale selection by authorized clinician.
2. Capture all required components: respiratory rate, SpO2, systolic BP, pulse, temperature, consciousness/new confusion and supplemental oxygen status. ECG and IV weight are not NEWS2 components.
3. Validate units, source reliability, freshness, observation coherence, missingness and eligibility. Missing or invalid fields return INCOMPLETE with null total; show partial observations separately.
4. Compute deterministic assessment on eligible observations using approved test vectors; store input references and rule version.
5. Train experimental deterioration model separately with patient-level temporal splits, specified outcome horizon, leakage review, calibration, baseline comparisons; output research advisory only, never a substitute for NEWS2 or escalation.

**Acceptance criteria:** All approved reference fixtures match; unsupported population abstains; missing BP does not yield normal score; model unavailable does not stop deterministic warnings; no claim of cardiac arrest prediction without validation.

</details>

#### API contracts

##### M11.01 — `PUT /admissions/{admissionId}/ews-config`

**Authorization:** DOCTOR  
**Success:** HTTP 200

**Request:**

```json
{
  "eligibility": "DEMO_ELIGIBLE_ADULT",
  "oxygenScale": "SCALE_1",
  "reason": "Synthetic assessment",
  "expectedVersion": 1
}
```

**Response (data):**

```json
{
  "admissionId": "enc_01",
  "ruleVersion": "news2-reviewed-v1",
  "version": 2
}
```

**Errors / constraints:** 422 ELIGIBILITY_UNSUPPORTED or SCALE_REQUIRES_APPROVAL; 409 VERSION_CONFLICT.

##### M11.02 — `POST /admissions/{admissionId}/news2/assessments`

**Authorization:** Assigned clinical staff/service + Idempotency-Key  
**Success:** HTTP 201

**Request:**

```json
{
  "observationIds": [
    "obs_01"
  ],
  "asOf": "2026-12-01T10:00:00Z"
}
```

**Response (data):**

```json
{
  "id": "ews_01",
  "status": "INCOMPLETE",
  "score": null,
  "missing": [
    "SPO2",
    "SBP",
    "HR",
    "TEMP",
    "CONSCIOUSNESS",
    "SUPPLEMENTAL_OXYGEN"
  ],
  "ruleVersion": "news2-reviewed-v1"
}
```

**Errors / constraints:** 422 OBSERVATION_SCOPE_MISMATCH; 503 RULE_VERSION_UNAVAILABLE.

##### M11.03 — `GET /admissions/{admissionId}/news2/latest`

**Authorization:** Assigned clinical staff  
**Success:** HTTP 200

**Request:**

None

**Response (data):**

```json
{
  "id": "ews_01",
  "status": "INCOMPLETE",
  "score": null,
  "missing": [
    "SBP"
  ],
  "ruleVersion": "news2-reviewed-v1"
}
```

**Errors / constraints:** 404 ASSESSMENT_NOT_FOUND.

##### M11.04 — `POST /admissions/{admissionId}/deterioration-jobs`

**Authorization:** DOCTOR/research-authorized service  
**Success:** HTTP 202

**Request:**

```json
{
  "modelId": "model_deterioration_demo",
  "windowStart": "2026-12-01T09:00:00Z",
  "windowEnd": "2026-12-01T10:00:00Z"
}
```

**Response (data):**

```json
{
  "jobId": "inf_01",
  "status": "QUEUED",
  "intendedUse": "RESEARCH_ONLY"
}
```

**Errors / constraints:** 422 MODEL_NOT_APPROVED_FOR_RESEARCH or INSUFFICIENT_INPUT; 503 AI_UNAVAILABLE.

### M12 — Alert lifecycle, escalation and notifications

**Dependencies:** M11 (device stale alerts can start M09)  
**Owner:** Abhishek + Aman  
**Status:** Planned

**In simple words — Alerts and emergency escalation:** Notify assigned staff when a simulated warning occurs and track whether someone has responded.

#### Implementation steps

1. Create rules for alert type, severity, repeated readings and approved escalation timing.
2. Save an alert and its notification job together in the database.
3. Send test notifications to the nurse, ward station and remote doctor according to the escalation policy.
4. Record notification delivery, acknowledgement and resolution separately; acknowledging an alert does not resolve it.
5. Show alerts, delivery failures and stale readings in the dashboard; support visual and audible cues.
6. After an outage, recover unfinished escalation jobs and avoid duplicate notifications.

**How to know this module is working:** A duplicate event does not create repeated active alerts; lost push notifications do not silently resolve an alert.

<details>
<summary>Exact engineering steps and acceptance tests (developer reference)</summary>

1. Define versioned event rules with severity, fingerprint, active episode, debounce/hysteresis, ownership and configurable escalation timers approved for simulated workflow.
2. Persist alert + outbox atomically; worker schedules notification and escalation; acknowledgement stops only configured escalation, not clinical risk.
3. Implement nurse→ward station→remote doctor delivery, channel adapters and retries with delivery receipts; use mock push/SMS and no PHI in notifications.
4. Track acknowledged, assigned, escalated, resolved and reopened episodes; resolution requires authorized rationale.
5. Add alert queue, audible/visual accessibility, stale stream and notification failures; separate delivery status from acknowledgement.
6. Recover after worker outage by querying due escalation rows, dedupe each recipient/channel/level.

**Acceptance criteria:** Duplicate event produces one active episode; lost push escalates via durable timer; acknowledgment race deterministic; broker outage shown; notification failure never marks alert resolved.

</details>

#### API contracts

##### M12.01 — `GET /alerts`

**Authorization:** Assigned clinical staff  
**Success:** HTTP 200

**Request:**

Query: wardId?, admissionId?, severity?, status?, cursor?, limit?

**Response (data):**

```json
{
  "items": [
    {
      "id": "alert_01",
      "severity": "WARNING",
      "status": "OPEN",
      "source": "SIMULATOR",
      "version": 1
    }
  ],
  "nextCursor": null
}
```

**Errors / constraints:** 403 SCOPE_DENIED.

##### M12.02 — `GET /alerts/{alertId}`

**Authorization:** Assigned clinical staff  
**Success:** HTTP 200

**Request:**

None

**Response (data):**

```json
{
  "id": "alert_01",
  "status": "OPEN",
  "severity": "WARNING",
  "nextEscalationAt": "2026-12-01T10:01:00Z",
  "version": 1
}
```

**Errors / constraints:** 404 ALERT_NOT_FOUND.

##### M12.03 — `POST /alerts/{alertId}/acknowledge`

**Authorization:** Assigned nurse/doctor + Idempotency-Key  
**Success:** HTTP 200

**Request:**

```json
{
  "expectedVersion": 1,
  "note": "Synthetic acknowledgement"
}
```

**Response (data):**

```json
{
  "id": "alert_01",
  "status": "ACKNOWLEDGED",
  "version": 2
}
```

**Errors / constraints:** 409 VERSION_CONFLICT or ALERT_RESOLVED.

##### M12.04 — `POST /alerts/{alertId}/assign`

**Authorization:** Authorized ward lead/doctor  
**Success:** HTTP 200

**Request:**

```json
{
  "assigneeId": "usr_02",
  "expectedVersion": 2
}
```

**Response (data):**

```json
{
  "id": "alert_01",
  "assigneeId": "usr_02",
  "version": 3
}
```

**Errors / constraints:** 422 ASSIGNEE_OUT_OF_SCOPE; 409 VERSION_CONFLICT.

##### M12.05 — `POST /alerts/{alertId}/escalate`

**Authorization:** Authorized clinical staff/service + Idempotency-Key  
**Success:** HTTP 200

**Request:**

```json
{
  "reason": "Synthetic escalation",
  "expectedVersion": 3
}
```

**Response (data):**

```json
{
  "id": "alert_01",
  "escalationLevel": 2,
  "version": 4
}
```

**Errors / constraints:** 409 ALERT_RESOLVED or VERSION_CONFLICT.

##### M12.06 — `POST /alerts/{alertId}/resolve`

**Authorization:** Authorized clinician + Idempotency-Key  
**Success:** HTTP 200

**Request:**

```json
{
  "reason": "Synthetic case closed",
  "evidenceRefs": [
    "obs_02"
  ],
  "expectedVersion": 4
}
```

**Response (data):**

```json
{
  "id": "alert_01",
  "status": "RESOLVED",
  "version": 5
}
```

**Errors / constraints:** 422 EVIDENCE_REQUIRED; 409 VERSION_CONFLICT.

##### M12.07 — `GET /alerts/{alertId}/deliveries`

**Authorization:** Authorized alert supervisor  
**Success:** HTTP 200

**Request:**

Query: cursor?, limit?

**Response (data):**

```json
{
  "items": [
    {
      "id": "del_01",
      "channel": "MOCK_PUSH",
      "status": "DELIVERED",
      "level": 1
    }
  ],
  "nextCursor": null
}
```

**Errors / constraints:** 404 ALERT_NOT_FOUND.

##### M12.08 — `POST /notification-endpoints`

**Authorization:** Authenticated staff  
**Success:** HTTP 201

**Request:**

```json
{
  "platform": "ANDROID",
  "pushToken": "<device-push-token>"
}
```

**Response (data):**

```json
{
  "id": "notif_01",
  "status": "ACTIVE"
}
```

**Errors / constraints:** 422 INVALID_TOKEN; never echo full token.

##### M12.09 — `DELETE /notification-endpoints/{endpointId}`

**Authorization:** Owner  
**Success:** HTTP 204

**Request:**

None

**Response (data):**

No body.

**Errors / constraints:** 404 ENDPOINT_NOT_FOUND.

### M13 — Nursing shifts and SBAR handoff

**Dependencies:** M07,M10,M12  
**Owner:** Abhishek + Akanksha  
**Status:** Planned

**In simple words — Nurse shift changes and SBAR handoff:** Give the incoming nurse a reliable record of what happened and what still needs attention.

#### Implementation steps

1. Create shift start/end records and define who covers each ward.
2. At handoff, capture completed doses, pending tasks, recent verified vitals, open alerts and outstanding reports.
3. Build a structured SBAR summary (Situation, Background, Assessment, Recommendation). AI may shorten the recorded facts, not invent clinical advice.
4. Ask the outgoing nurse to review and sign, then the incoming nurse to review and accept. Show critical changes since the snapshot before acceptance.
5. If AI is down, show the structured facts anyway; track incomplete or unaccepted handoffs.

**How to know this module is working:** Pending tasks remain visible, signed summaries cannot be silently changed and critical new updates must be reviewed.

<details>
<summary>Exact engineering steps and acceptance tests (developer reference)</summary>

1. Create shift sessions and ward coverage with explicit ownership; no implicit care transfer on logout.
2. Generate deterministic cutoff snapshot of medication administrations, pending/overdue/review tasks, recent verified observations, open alerts and outstanding reports.
3. Build SBAR JSON (Situation, Background, Assessment, Recommendation); LLM draft summarizes only snapshot references, does not invent recommendations.
4. Outgoing nurse reviews/edits with evidence, signs immutable revision; incoming nurse reviews, acknowledges and accepts tasks; if critical update after cutoff, show delta and require review before acceptance.
5. Capture handoff completeness metrics and escalate unaccepted handoff to supervisor; AI failure falls back to structured snapshot.

**Acceptance criteria:** Unacknowledged handoff visible; missing data explicitly labeled; signed revision immutable; stale snapshot blocks acceptance until reviewed; pending dose states preserved.

</details>

#### API contracts

##### M13.01 — `POST /shifts`

**Authorization:** Assigned NURSE  
**Success:** HTTP 201

**Request:**

```json
{
  "wardId": "ward_01",
  "startsAt": "2026-12-01T08:00:00Z"
}
```

**Response (data):**

```json
{
  "id": "shift_01",
  "status": "ACTIVE"
}
```

**Errors / constraints:** 409 SHIFT_ALREADY_ACTIVE.

##### M13.02 — `POST /shifts/{shiftId}/handoffs`

**Authorization:** Outgoing NURSE + Idempotency-Key  
**Success:** HTTP 201

**Request:**

```json
{
  "incomingNurseId": "usr_03"
}
```

**Response (data):**

```json
{
  "id": "handoff_01",
  "status": "DRAFT",
  "cutoffAt": "2026-12-01T14:00:00Z",
  "version": 1,
  "sbar": {
    "situation": "Synthetic ward snapshot",
    "background": "See source refs",
    "assessment": "Open review items",
    "recommendation": "Review pending tasks"
  },
  "sourceRefs": [
    "dose_03",
    "alert_01"
  ]
}
```

**Errors / constraints:** 422 INCOMING_NURSE_NOT_ASSIGNED.

##### M13.03 — `POST /handoffs/{handoffId}/summary-jobs`

**Authorization:** Outgoing NURSE  
**Success:** HTTP 202

**Request:**

```json
{
  "expectedVersion": 1,
  "language": "en"
}
```

**Response (data):**

```json
{
  "jobId": "job_sbar_01",
  "status": "QUEUED"
}
```

**Errors / constraints:** 409 HANDOFF_SIGNED or VERSION_CONFLICT; 503 AI_UNAVAILABLE.

##### M13.04 — `GET /handoffs/{handoffId}`

**Authorization:** Authorized outgoing/incoming/supervisor  
**Success:** HTTP 200

**Request:**

None

**Response (data):**

```json
{
  "id": "handoff_01",
  "status": "DRAFT",
  "version": 1,
  "sourceRefs": [
    "dose_03"
  ],
  "pendingItems": [
    {
      "ref": "dose_03",
      "status": "REVIEW_REQUIRED"
    }
  ]
}
```

**Errors / constraints:** 404 HANDOFF_NOT_FOUND.

##### M13.05 — `PATCH /handoffs/{handoffId}`

**Authorization:** Outgoing NURSE  
**Success:** HTTP 200

**Request:**

```json
{
  "sbar": {
    "situation": "Synthetic situation",
    "background": "Verified context",
    "assessment": "Review pending",
    "recommendation": "Review assigned tasks"
  },
  "sourceRefs": [
    "dose_03"
  ],
  "expectedVersion": 1
}
```

**Response (data):**

```json
{
  "id": "handoff_01",
  "status": "DRAFT",
  "version": 2
}
```

**Errors / constraints:** 409 HANDOFF_SIGNED or VERSION_CONFLICT.

##### M13.06 — `POST /handoffs/{handoffId}/sign`

**Authorization:** Outgoing NURSE + Idempotency-Key  
**Success:** HTTP 200

**Request:**

```json
{
  "expectedVersion": 2,
  "reviewed": true
}
```

**Response (data):**

```json
{
  "id": "handoff_01",
  "status": "SIGNED",
  "version": 3
}
```

**Errors / constraints:** 409 SNAPSHOT_STALE; 422 REQUIRED_ITEMS_MISSING.

##### M13.07 — `POST /handoffs/{handoffId}/accept`

**Authorization:** Incoming NURSE + Idempotency-Key  
**Success:** HTTP 200

**Request:**

```json
{
  "expectedVersion": 3,
  "reviewedItemRefs": [
    "dose_03"
  ],
  "acknowledgedDeltaVersion": 1
}
```

**Response (data):**

```json
{
  "id": "handoff_01",
  "status": "ACCEPTED",
  "version": 4
}
```

**Errors / constraints:** 409 SNAPSHOT_STALE or UNREVIEWED_DELTA; 403 NOT_INCOMING_NURSE.

##### M13.08 — `POST /shifts/{shiftId}/close`

**Authorization:** Outgoing NURSE  
**Success:** HTTP 200

**Request:**

```json
{
  "handoffId": "handoff_01"
}
```

**Response (data):**

```json
{
  "id": "shift_01",
  "status": "CLOSED"
}
```

**Errors / constraints:** 409 HANDOFF_NOT_ACCEPTED.

### M14 — Patient longitudinal vault, discharge and FHIR export

**Dependencies:** M04,M05,M10,M13  
**Owner:** Abhishek  
**Status:** Planned

**In simple words — Patient history, discharge and record export:** Keep records from multiple visits in one authorized timeline and prepare a discharge summary.

#### Implementation steps

1. Build a timeline from verified records with event time, recorded time and source link.
2. Allow previous visits to be viewed only when the user has proper access and sharing permission.
3. Prepare a discharge draft for a doctor to review and sign. Check unresolved dose tasks before closing the admission and releasing the bed, device and wristband.
4. Map records to FHIR R4, a healthcare data exchange format, and validate the exported bundle.
5. Log exports and keep signed versions unchanged; corrections create a new version.

**How to know this module is working:** Unauthorized visits remain hidden; discharge does not bypass unresolved doses; an authorized reviewer can view the original summary.

<details>
<summary>Exact engineering steps and acceptance tests (developer reference)</summary>

1. Project timeline from verified source versions with event time and recorded time, encounter scope and source provenance.
2. Show previous visits only under lawful access and approved consent; no automatic sharing by identifier.
3. Create discharge summary draft from structured records and unresolved items; doctor reviews and signs, admission close transaction locks encounter and resolves device/bed/wristband lifecycle.
4. Build FHIR R4 mapping and versioned implementation-guide adapter: Patient, Encounter, Observation, AllergyIntolerance, MedicationRequest, MedicationAdministration, DiagnosticReport, DocumentReference, Composition, Consent and Provenance.
5. Validate bundles against chosen profile, no claim of ABDM certification; exports scoped and audited.
6. Add amendment workflow for signed records (new version, not overwrite).

**Acceptance criteria:** Cross-encounter access denied without grant; discharge blocks unresolved dose; timeline ordered deterministically; valid test bundle; original signed summary remains available to authorized reviewer.

</details>

#### API contracts

##### M14.01 — `GET /patients/{patientId}/timeline`

**Authorization:** Assigned clinical staff with continuity scope  
**Success:** HTTP 200

**Request:**

Query: admissionId?, category?, from?, to?, limit?, cursor?

**Response (data):**

```json
{
  "items": [
    {
      "id": "evt_01",
      "type": "MEDICATION_ADMINISTRATION",
      "admissionId": "enc_01",
      "sourceRef": "admin_01",
      "eventAt": "2026-12-01T10:00:40Z",
      "verificationStatus": "VERIFIED"
    }
  ],
  "nextCursor": null
}
```

**Errors / constraints:** 403 CONTINUITY_SCOPE_DENIED.

##### M14.02 — `POST /admissions/{admissionId}/discharge-summaries`

**Authorization:** DOCTOR  
**Success:** HTTP 201

**Request:**

```json
{
  "reason": "Synthetic discharge draft"
}
```

**Response (data):**

```json
{
  "id": "dis_01",
  "status": "DRAFT",
  "version": 1,
  "unresolvedRefs": [
    "dose_03"
  ]
}
```

**Errors / constraints:** 409 ADMISSION_CLOSED.

##### M14.03 — `PATCH /discharge-summaries/{summaryId}`

**Authorization:** DOCTOR  
**Success:** HTTP 200

**Request:**

```json
{
  "summaryText": "Synthetic course of stay",
  "sourceRefs": [
    "admin_01"
  ],
  "expectedVersion": 1
}
```

**Response (data):**

```json
{
  "id": "dis_01",
  "status": "DRAFT",
  "version": 2
}
```

**Errors / constraints:** 409 SIGNED_SUMMARY or VERSION_CONFLICT.

##### M14.04 — `POST /discharge-summaries/{summaryId}/sign`

**Authorization:** DOCTOR + Idempotency-Key  
**Success:** HTTP 200

**Request:**

```json
{
  "expectedVersion": 2,
  "reviewed": true
}
```

**Response (data):**

```json
{
  "id": "dis_01",
  "status": "SIGNED",
  "version": 3
}
```

**Errors / constraints:** 409 UNRESOLVED_SAFETY_ITEMS or SNAPSHOT_STALE.

##### M14.05 — `POST /admissions/{admissionId}/discharge`

**Authorization:** DOCTOR + Idempotency-Key  
**Success:** HTTP 200

**Request:**

```json
{
  "summaryId": "dis_01",
  "expectedVersion": 2
}
```

**Response (data):**

```json
{
  "id": "enc_01",
  "status": "DISCHARGED",
  "dischargedAt": "2026-12-01T16:00:00Z",
  "version": 3
}
```

**Errors / constraints:** 409 UNSIGNED_SUMMARY, ACTIVE_DOSE_REVIEW_REQUIRED, or VERSION_CONFLICT.

##### M14.06 — `POST /patients/{patientId}/fhir-exports`

**Authorization:** Authorized clinician with export scope  
**Success:** HTTP 202

**Request:**

```json
{
  "admissionIds": [
    "enc_01"
  ],
  "profile": "FHIR_R4_DEMO",
  "purpose": "SYNTHETIC_EXPORT"
}
```

**Response (data):**

```json
{
  "jobId": "job_fhir_01",
  "status": "QUEUED"
}
```

**Errors / constraints:** 403 EXPORT_SCOPE_DENIED; 422 PROFILE_UNSUPPORTED.

### M15 — Private file upload, digital parsing and OCR verification

**Dependencies:** M04,M14 foundation  
**Owner:** Akanksha + Abhishek  
**Status:** Planned

**In simple words — Upload reports and verify OCR results:** Turn a lab or scan report into structured data that a human verifies before it becomes part of the patient record.

#### Implementation steps

1. Upload to private storage using a short-lived URL. Check file size, type, checksum and malware risk.
2. Stage 1: read structured digital files directly when possible. Validate the patient, values and units.
3. Stage 2: for scanned paper, independently extract data with PaddleOCR and a vision AI; compare the results. A single-engine MVP is draft-only.
4. Stage 3: show the original report crop beside proposed values. A reviewer confirms every clinically important field or rejects uncertain data.
5. Save the verified version, update the timeline and send allowed content to the RAG index. Corrections remove outdated indexed content.
6. Handle duplicate uploads, malicious files, provider failures and expired file links.

**How to know this module is working:** Wrong-patient reports and unreviewed values cannot enter the verified timeline; disagreements are shown to reviewers.

<details>
<summary>Exact engineering steps and acceptance tests (developer reference)</summary>

1. Implement upload intent, signed upload URL, size/type/checksum allowlist, quarantine + malware scan; private object storage with no public bucket.
2. Stage 1: parse structured JSON/HL7/XML with safe parser (disable external entities), text PDF or DICOM metadata; validate schema, units and patient/encounter linkage. Digital parse still has errors; no automatic clinical accuracy promise.
3. Stage 2: PaddleOCR and Vision LLM independently extract field candidates, bounding boxes, units and evidence; reconcile normalized code/value/unit, track engine versions. MVP single Vision LLM drafts only and visibly labels reduced pipeline.
4. Stage 3: reviewer compares original crop and candidates; require all clinically consequential fields reviewed, including abnormal, missing or discrepant fields; reject uncertain documents.
5. Save verified immutable revision and index only verified permitted content; amendment invalidates prior RAG chunks.
6. Handle duplicate file checksum, malicious PDF, wrong patient, provider outage, retry/dead-letter and signed view authorization.

**Acceptance criteria:** Wrong patient blocked; no unreviewed field enters verified record; numerical/unit disagreement highlighted; malformed file rejected; signed file URL expires; accuracy measured on labeled fixture set.

</details>

#### API contracts

##### M15.01 — `POST /files/upload-intents`

**Authorization:** Assigned uploader  
**Success:** HTTP 201

**Request:**

```json
{
  "admissionId": "enc_01",
  "purpose": "CLINICAL_REPORT",
  "filename": "demo-report.pdf",
  "contentType": "application/pdf",
  "sizeBytes": 12345,
  "sha256": "<hex-sha256>"
}
```

**Response (data):**

```json
{
  "objectId": "obj_01",
  "uploadUrl": "<short-lived-signed-put-url>",
  "requiredHeaders": {
    "Content-Type": "application/pdf"
  },
  "expiresIn": 300
}
```

**Errors / constraints:** 413 FILE_TOO_LARGE; 415 UNSUPPORTED_TYPE.

##### M15.02 — `POST /files/{objectId}/complete`

**Authorization:** Original uploader + Idempotency-Key  
**Success:** HTTP 202

**Request:**

```json
{
  "sha256": "<hex-sha256>"
}
```

**Response (data):**

```json
{
  "objectId": "obj_01",
  "status": "QUARANTINED",
  "jobId": "job_scan_01"
}
```

**Errors / constraints:** 409 UPLOAD_INCOMPLETE; 422 CHECKSUM_MISMATCH.

##### M15.03 — `GET /files/{objectId}/status`

**Authorization:** Authorized uploader/reviewer  
**Success:** HTTP 200

**Request:**

None

**Response (data):**

```json
{
  "id": "obj_01",
  "status": "CLEAN",
  "contentType": "application/pdf"
}
```

**Errors / constraints:** 404 OBJECT_NOT_FOUND.

##### M15.04 — `GET /files/{objectId}/view-url`

**Authorization:** Authorized record reader  
**Success:** HTTP 200

**Request:**

None

**Response (data):**

```json
{
  "url": "<short-lived-signed-get-url>",
  "expiresIn": 60
}
```

**Errors / constraints:** 403 FILE_SCOPE_DENIED; 409 FILE_NOT_CLEAN. Use authenticated proxy for referral if revocation must be immediate.

##### M15.05 — `POST /admissions/{admissionId}/reports`

**Authorization:** Assigned nurse/lab tech  
**Success:** HTTP 202

**Request:**

```json
{
  "objectId": "obj_01",
  "reportType": "BLOOD_PANEL",
  "sourceType": "PAPER_SCAN"
}
```

**Response (data):**

```json
{
  "reportId": "rep_01",
  "jobId": "job_ocr_01",
  "status": "QUEUED"
}
```

**Errors / constraints:** 409 FILE_NOT_CLEAN or DUPLICATE_REPORT; 422 REPORT_TYPE_UNSUPPORTED.

##### M15.06 — `GET /admissions/{admissionId}/reports`

**Authorization:** Assigned clinical staff  
**Success:** HTTP 200

**Request:**

Query: status?, reportType?, cursor?, limit?

**Response (data):**

```json
{
  "items": [
    {
      "id": "rep_01",
      "status": "REVIEW_REQUIRED",
      "reportType": "BLOOD_PANEL"
    }
  ],
  "nextCursor": null
}
```

**Errors / constraints:** 404 ADMISSION_NOT_FOUND.

##### M15.07 — `GET /reports/{reportId}`

**Authorization:** Assigned clinical staff  
**Success:** HTTP 200

**Request:**

None

**Response (data):**

```json
{
  "id": "rep_01",
  "status": "REVIEW_REQUIRED",
  "version": 1,
  "fields": [
    {
      "id": "field_01",
      "code": "DEMO_ANALYTE",
      "candidates": [
        {
          "engine": "PADDLE",
          "value": "10",
          "unit": "demo-unit"
        },
        {
          "engine": "VISION",
          "value": "11",
          "unit": "demo-unit"
        }
      ],
      "discrepancy": true,
      "evidence": {
        "page": 1,
        "bbox": [
          0.1,
          0.2,
          0.4,
          0.3
        ]
      }
    }
  ]
}
```

**Errors / constraints:** 404 REPORT_NOT_FOUND.

##### M15.08 — `POST /reports/{reportId}/review`

**Authorization:** LAB_TECH/authorized clinician + Idempotency-Key  
**Success:** HTTP 200

**Request:**

```json
{
  "expectedVersion": 1,
  "decision": "VERIFY",
  "fields": [
    {
      "fieldId": "field_01",
      "value": "10",
      "unit": "demo-unit",
      "reviewed": true
    }
  ],
  "reason": "Compared synthetic original"
}
```

**Response (data):**

```json
{
  "id": "rep_01",
  "status": "VERIFIED",
  "version": 2,
  "verifiedAt": "2026-12-01T13:00:00Z"
}
```

**Errors / constraints:** 409 VERSION_CONFLICT; 422 UNREVIEWED_FIELDS or PATIENT_MISMATCH. REJECT decision requires reason.

##### M15.09 — `POST /reports/{reportId}/amendments`

**Authorization:** Authorized clinical reviewer  
**Success:** HTTP 201

**Request:**

```json
{
  "expectedVersion": 2,
  "reason": "Synthetic corrected source",
  "fields": [
    {
      "fieldId": "field_01",
      "value": "12",
      "unit": "demo-unit",
      "reviewed": true
    }
  ]
}
```

**Response (data):**

```json
{
  "id": "rep_01",
  "status": "VERIFIED",
  "version": 3,
  "supersedesVersion": 2
}
```

**Errors / constraints:** 409 VERSION_CONFLICT; 422 REASON_REQUIRED.

##### M15.10 — `POST /reports/{reportId}/retry`

**Authorization:** Authorized reviewer  
**Success:** HTTP 202

**Request:**

```json
{
  "expectedVersion": 1
}
```

**Response (data):**

```json
{
  "jobId": "job_ocr_02",
  "status": "QUEUED"
}
```

**Errors / constraints:** 409 REPORT_FINALIZED or JOB_ALREADY_RUNNING.

### M16 — Multilingual voice logging and offline synchronization

**Dependencies:** M04,M10,M08  
**Owner:** Akanksha + Abhishek  
**Status:** Planned

**In simple words — Voice notes and offline syncing:** Let nurses speak in Hindi, Hinglish or English and save verified notes, even after a temporary loss of internet.

#### Implementation steps

1. Select the patient first, then record a short audio clip.
2. Transcribe using Whisper or IndicWhisper and convert the text into a draft note.
3. Keep the transcript and mark unclear times or words. Never infer a medication administration from speech.
4. Let the nurse correct and confirm the draft before saving the note or diet observation.
5. Keep only permitted minimum offline data in encrypted SQLite, and clear it when required.
6. On reconnection, send each pending operation with a unique retry key; show conflicts and keep unsynced items until the server acknowledges them.

**How to know this module is working:** Retrying a note creates it once; revoked access stops sync; offline medication approval is rejected.

<details>
<summary>Exact engineering steps and acceptance tests (developer reference)</summary>

1. Record short voice clip with explicit patient context selected before recording; use expo-audio or web recorder.
2. Upload with purpose VOICE_NOTE, transcribe Whisper/IndicWhisper; detect language (Hindi/Hinglish/English), extract draft JSON via validated schema.
3. Preserve original transcript, explicit time uncertainty and ambiguous patient/food references; do not infer medication administration from speech.
4. Nurse edits, confirms and commits note or diet observation through normal domain validation.
5. Local encrypted SQLite stores only authorized minimum data and pending non-safety operations; secure key, cache TTL, logout purge, device binding.
6. Sync batch with per-operation idempotency key, payload hash, current server authorization and per-item results; conflicts surfaced, not last-write-wins; retain pending until server acknowledgement.

**Acceptance criteria:** Hindi/Hinglish fixtures preserve numbers and uncertainty; wrong patient cannot be inferred; offline replay inserts once; medication operation rejected; revoked assignment blocks sync; AI outage allows manual note.

</details>

#### API contracts

##### M16.01 — `POST /admissions/{admissionId}/voice-jobs`

**Authorization:** Assigned nurse + Idempotency-Key  
**Success:** HTTP 202

**Request:**

```json
{
  "objectId": "obj_audio_01",
  "languageHint": "hi-en",
  "noteKind": "OBSERVATION"
}
```

**Response (data):**

```json
{
  "jobId": "voice_01",
  "status": "QUEUED"
}
```

**Errors / constraints:** 409 FILE_NOT_CLEAN; 415 AUDIO_TYPE_UNSUPPORTED.

##### M16.02 — `GET /voice-jobs/{jobId}`

**Authorization:** Original nurse/authorized reviewer  
**Success:** HTTP 200

**Request:**

None

**Response (data):**

```json
{
  "id": "voice_01",
  "status": "REVIEW_REQUIRED",
  "version": 1,
  "transcript": "Synthetic ward note",
  "draft": {
    "kind": "OBSERVATION",
    "text": "Synthetic ward note",
    "observedAt": null
  },
  "uncertainties": [
    "TIME_NOT_EXPLICIT"
  ]
}
```

**Errors / constraints:** 404 JOB_NOT_FOUND.

##### M16.03 — `POST /voice-jobs/{jobId}/confirm`

**Authorization:** Assigned nurse + Idempotency-Key  
**Success:** HTTP 201

**Request:**

```json
{
  "expectedVersion": 1,
  "text": "Reviewed synthetic ward note",
  "observedAt": "2026-12-01T12:00:00Z",
  "reviewed": true
}
```

**Response (data):**

```json
{
  "noteId": "note_01",
  "status": "VERIFIED",
  "voiceJobId": "voice_01"
}
```

**Errors / constraints:** 422 UNRESOLVED_REQUIRED_FIELD; 409 VERSION_CONFLICT. Diet draft invokes M08 validation.

##### M16.04 — `POST /admissions/{admissionId}/notes`

**Authorization:** Assigned nurse/doctor + Idempotency-Key  
**Success:** HTTP 201

**Request:**

```json
{
  "kind": "OBSERVATION",
  "text": "Synthetic manual note",
  "observedAt": "2026-12-01T12:00:00Z"
}
```

**Response (data):**

```json
{
  "id": "note_02",
  "status": "VERIFIED",
  "version": 1
}
```

**Errors / constraints:** 422 INVALID_NOTE_TYPE; 409 ADMISSION_CLOSED.

##### M16.05 — `GET /admissions/{admissionId}/notes`

**Authorization:** Assigned care staff  
**Success:** HTTP 200

**Request:**

Query: from?, to?, cursor?, limit?

**Response (data):**

```json
{
  "items": [
    {
      "id": "note_01",
      "kind": "OBSERVATION",
      "status": "VERIFIED"
    }
  ],
  "nextCursor": null
}
```

**Errors / constraints:** 404 ADMISSION_NOT_FOUND.

##### M16.06 — `POST /sync/operations`

**Authorization:** Authenticated assigned staff  
**Success:** HTTP 200

**Request:**

```json
{
  "clientDeviceId": "client_01",
  "operations": [
    {
      "operationId": "op_01",
      "type": "CREATE_NOTE",
      "admissionId": "enc_01",
      "payload": {
        "kind": "OBSERVATION",
        "text": "Synthetic offline note",
        "observedAt": "2026-12-01T12:00:00Z"
      }
    }
  ]
}
```

**Response (data):**

```json
{
  "results": [
    {
      "operationId": "op_01",
      "status": "APPLIED",
      "resourceId": "note_03"
    }
  ]
}
```

**Errors / constraints:** Per-operation REJECTED (FORBIDDEN_OPERATION/SCOPE_DENIED), CONFLICT, DUPLICATE or RETRYABLE; max batch 50. No medication reserve/start/confirm, no consent or order offline writes.

### M17 — Clinical RAG, scoped retrieval and grounded answers

**Dependencies:** M14–M16 + M18 grant integration  
**Owner:** Akanksha  
**Status:** Planned

**In simple words — Patient history chatbot (RAG):** Let authorized staff ask questions about verified patient records and see exactly where the answer comes from.

#### Implementation steps

1. Index verified, permitted records with patient, hospital, visit, version and source identifiers.
2. Use pgvector and keyword search to find relevant text; use structured database queries for exact medication and allergy history.
3. Check permissions before retrieval and again before returning information.
4. Send only allowed evidence to the AI, ask for citations and reject unsupported statements. Treat report text as data, not instructions.
5. Show clickable citations and say NOT_RECORDED if information is absent. Do not let the chatbot write clinical records.
6. Measure answer quality, retrieval and unsupported claims with synthetic test questions; avoid sensitive data in logs.

**How to know this module is working:** The chatbot cannot read another patient’s records, invent a valid citation or answer from a revoked grant.

<details>
<summary>Exact engineering steps and acceptance tests (developer reference)</summary>

1. Index only verified clinical sources and their immutable version, tenant/patient/encounter scope, consent tags and evidence locator; structured data for medication/allergy queries via fixed server tools.
2. Implement chunking with provenance, embeddings, pgvector and hybrid keyword search; authorize before retrieval, filter both SQL and returned sources; use separate namespace where needed.
3. Build query pipeline: identity and grant → classify intent → deterministic structured query or hybrid retrieval → source packing → draft generation → citation validation → answer or abstain.
4. Treat report/note text as untrusted data (prompt injection tests), no arbitrary SQL or tool actions, no write access, no web answers mixed with patient records.
5. Return clickable source IDs with timestamp, version and authorized source viewer; validate every factual claim against evidence; if data missing use NOT_RECORDED.
6. Track model/prompt/retrieval version, latency, recall and unsupported claims with redacted logs; disable external AI for real records absent approved data processing.

**Acceptance criteria:** No cross-patient chunks; revoked consent blocks queries/source opening; fabricated citation rejected; prompt injection cannot change scope; absent evidence abstains; model failure does not invent answer.

</details>

#### API contracts

##### M17.01 — `POST /admissions/{admissionId}/rag/queries`

**Authorization:** Assigned DOCTOR with RAG scope + Idempotency-Key  
**Success:** HTTP 202

**Request:**

```json
{
  "question": "Which synthetic medication records exist?",
  "language": "en"
}
```

**Response (data):**

```json
{
  "queryId": "rag_01",
  "status": "QUEUED"
}
```

**Errors / constraints:** 403 RAG_SCOPE_DENIED; 422 QUESTION_TOO_LONG; 503 AI_UNAVAILABLE.

##### M17.02 — `GET /rag/queries/{queryId}`

**Authorization:** Original authorized requester  
**Success:** HTTP 200

**Request:**

None

**Response (data):**

```json
{
  "id": "rag_01",
  "status": "ANSWERED",
  "answer": "A synthetic administration is recorded. [1]",
  "citations": [
    {
      "id": "cit_01",
      "sourceType": "MEDICATION_ADMINISTRATION",
      "sourceId": "admin_01",
      "version": 1,
      "recordedAt": "2026-12-01T10:00:42Z"
    }
  ],
  "limitations": [
    "Research prototype"
  ],
  "modelVersion": "demo-rag-v1"
}
```

**Errors / constraints:** 404 QUERY_NOT_FOUND; 403 ACCESS_REVOKED. Other terminal statuses NOT_RECORDED, ABSTAINED, FAILED; no answer without supported citation.

##### M17.03 — `GET /rag/queries/{queryId}/citations/{citationId}`

**Authorization:** Original authorized requester  
**Success:** HTTP 200

**Request:**

None

**Response (data):**

```json
{
  "sourceId": "admin_01",
  "sourceType": "MEDICATION_ADMINISTRATION",
  "version": 1,
  "excerpt": "Synthetic record",
  "recordedAt": "2026-12-01T10:00:42Z"
}
```

**Errors / constraints:** 403 ACCESS_REVOKED; 404 CITATION_NOT_FOUND.

##### M17.04 — `POST /research/rag/reindex`

**Authorization:** Authorized service / researcher on demo dataset  
**Success:** HTTP 202

**Request:**

```json
{
  "sourceType": "REPORT",
  "sourceId": "rep_01",
  "sourceVersion": 3
}
```

**Response (data):**

```json
{
  "jobId": "job_embed_01",
  "status": "QUEUED"
}
```

**Errors / constraints:** 422 SOURCE_NOT_VERIFIED; 403 REAL_DATA_NOT_ALLOWED.

### M18 — Referral QR, PDF and receiving hospital portal

**Dependencies:** M04,M14,M17  
**Owner:** Abhishek + Akanksha  
**Status:** Planned

**In simple words — Secure referral QR and receiving hospital portal:** Share selected verified records with an authorized receiving clinician without putting medical history inside the QR code.

#### Implementation steps

1. Create a referral summary with the receiving organization, allowed sections, purpose, expiry and consent.
2. Generate a random opaque referral token and store its protected digest; the QR contains only the token or link.
3. After scanning, require the recipient to log in and redeem the token. Check their organization and role.
4. Show only the permitted timeline and chatbot sections. Check the grant every time a record or source is opened.
5. Stop access on expiry or revocation, including live subscriptions. Do not cache referral data or log the token.
6. Generate a private referral PDF containing the QR; allow replacement or revocation and record access.

**How to know this module is working:** Scanning a QR alone does not reveal records; wrong recipients, expired grants and revoked consent are blocked.

<details>
<summary>Exact engineering steps and acceptance tests (developer reference)</summary>

1. Create signed discharge/referral summary with scope, recipient organization, purpose, expiry and active consent link.
2. Generate opaque random referral token (or signed token with server-side grant lookup), store digest, place only opaque token/URL in QR, no PHI. Signing is not encryption; don't encode record content.
3. Recipient scans QR, authenticates under verified organization and clinician role, redeems token by POST; grant bound to allowed patient/encounter/sections, limited session lifetime; optional single-use redemption with controlled renewal.
4. Render scoped timeline and referral RAG; every API and citation checks active grant/consent and recipient.
5. Expiry/revocation invalidates sessions and subscriptions; no cache of referral data, no analytics on token URLs, strip fragment/URL after redemption.
6. Generate private PDF with QR and expiry; access logs with purpose and recipient; allow sender revoke and replacement.

**Acceptance criteria:** QR alone cannot access records; recipient mismatch rejected; expired/revoked grant denied; token never in request logs; PDF generation failure leaves recoverable job; RAG cannot see excluded fields.

</details>

#### API contracts

##### M18.01 — `POST /admissions/{admissionId}/referrals`

**Authorization:** DOCTOR + Idempotency-Key  
**Success:** HTTP 201

**Request:**

```json
{
  "summaryId": "dis_01",
  "recipientOrgId": "hosp_02",
  "consentId": "consent_01",
  "scope": [
    "MEDICATIONS",
    "VERIFIED_REPORTS"
  ],
  "expiresAt": "2026-12-03T00:00:00Z",
  "reason": "Synthetic referral"
}
```

**Response (data):**

```json
{
  "id": "ref_01",
  "status": "ACTIVE",
  "grantId": "grant_01",
  "qrPayload": "https://demo.example.test/referral#token=<opaque-token>",
  "expiresAt": "2026-12-03T00:00:00Z"
}
```

**Errors / constraints:** 422 INVALID_CONSENT or SUMMARY_NOT_SIGNED; 403 RECIPIENT_NOT_AUTHORIZED.

##### M18.02 — `POST /referrals/{referralId}/pdf-jobs`

**Authorization:** Source DOCTOR  
**Success:** HTTP 202

**Request:**

```json
{
  "includeQr": true
}
```

**Response (data):**

```json
{
  "jobId": "job_pdf_01",
  "status": "QUEUED"
}
```

**Errors / constraints:** 409 REFERRAL_INACTIVE; QR generated via protected token material, not raw digest.

##### M18.03 — `GET /referrals/{referralId}`

**Authorization:** Source assigned DOCTOR  
**Success:** HTTP 200

**Request:**

None

**Response (data):**

```json
{
  "id": "ref_01",
  "status": "ACTIVE",
  "scope": [
    "MEDICATIONS",
    "VERIFIED_REPORTS"
  ],
  "expiresAt": "2026-12-03T00:00:00Z"
}
```

**Errors / constraints:** 404 REFERRAL_NOT_FOUND.

##### M18.04 — `POST /referral-access/redeem`

**Authorization:** Authenticated receiving clinician + Idempotency-Key  
**Success:** HTTP 200

**Request:**

```json
{
  "token": "<opaque-token>",
  "purpose": "CONTINUITY_OF_CARE"
}
```

**Response (data):**

```json
{
  "sessionId": "refsess_01",
  "scope": [
    "MEDICATIONS",
    "VERIFIED_REPORTS"
  ],
  "expiresAt": "2026-12-01T16:15:00Z"
}
```

**Errors / constraints:** 403 RECIPIENT_MISMATCH or CONSENT_REVOKED; 410 TOKEN_EXPIRED; 409 TOKEN_ALREADY_REDEEMED.

##### M18.05 — `GET /referral-access/{sessionId}/timeline`

**Authorization:** Authorized receiving clinician  
**Success:** HTTP 200

**Request:**

Query: category?, cursor?, limit?

**Response (data):**

```json
{
  "items": [
    {
      "type": "MEDICATION_ADMINISTRATION",
      "sourceRef": "admin_01",
      "eventAt": "2026-12-01T10:00:40Z"
    }
  ],
  "nextCursor": null
}
```

**Errors / constraints:** 403 GRANT_SCOPE_DENIED or GRANT_REVOKED; 410 SESSION_EXPIRED.

##### M18.06 — `POST /referral-access/{sessionId}/rag/queries`

**Authorization:** Authorized receiving clinician + Idempotency-Key  
**Success:** HTTP 202

**Request:**

```json
{
  "question": "Which synthetic medication records exist?",
  "language": "en"
}
```

**Response (data):**

```json
{
  "queryId": "rag_ref_01",
  "status": "QUEUED"
}
```

**Errors / constraints:** 403 GRANT_SCOPE_DENIED; 410 SESSION_EXPIRED. Poll M17 endpoint; it rechecks session/grant.

##### M18.07 — `POST /referrals/{referralId}/revoke`

**Authorization:** Source DOCTOR/consent authority  
**Success:** HTTP 200

**Request:**

```json
{
  "reason": "Synthetic revocation"
}
```

**Response (data):**

```json
{
  "id": "ref_01",
  "status": "REVOKED"
}
```

**Errors / constraints:** 404 REFERRAL_NOT_FOUND.

##### M18.08 — `GET /referrals/{referralId}/access-logs`

**Authorization:** Authorized source auditor  
**Success:** HTTP 200

**Request:**

Query: cursor?, limit?

**Response (data):**

```json
{
  "items": [
    {
      "event": "REDEEMED",
      "recipientOrgId": "hosp_02",
      "at": "2026-12-01T16:00:00Z"
    }
  ],
  "nextCursor": null
}
```

**Errors / constraints:** 403 AUDIT_SCOPE_DENIED.

### M19 — Specialized diagnostic research and future-risk advisory

**Dependencies:** M10,M14,M15; independent research starts week 2  
**Owner:** Akanksha  
**Status:** Planned

**In simple words — Advanced AI models and research risk review:** Research specialized models for CT, ECG, breast imaging and liver data, and explore evidence-based pre-surgery and long-term review flags.

#### Implementation steps

1. Register each model with its version, intended task, input type, dataset and evaluation results.
2. Create separate input adapters for each research task; reject unsupported scans, ECG leads or missing data.
3. Run models as background jobs; store quality checks, raw result, model version and explanation where appropriate.
4. Build pre-surgery and long-term research review flags from verified evidence only. Do not issue treatment instructions or surgical clearance.
5. Show uncertainty, limitations and evidence; a clinician may review the output without turning it automatically into a diagnosis.
6. Evaluate one or two tasks well before expanding. Split data by patient, prevent leakage and measure calibration and subgroup performance.

**How to know this module is working:** Unsupported inputs are rejected; missing evidence causes abstention; model output never automatically changes diagnosis or treatment.

<details>
<summary>Exact engineering steps and acceptance tests (developer reference)</summary>

1. Register task, intended use, model version, artifact checksum, input schema, output labels, dataset license and evaluation report; disable unvalidated models outside synthetic/research mode.
2. Build separate adapters for CT hemorrhage, ECG classification, mammogram lesion detection and liver research; enforce task/modality/lead configuration; reject unsupported/OOD inputs.
3. Implement asynchronous inference, quality checks, pre/postprocessing provenance, Grad-CAM/SHAP where valid; explanations are not proof.
4. Pre-surgical advisory uses verified medication/allergy/lab evidence and approved rule set; no drug stop/start directives; trajectory advisory requires adequate longitudinal history, time-aware validation and abstention.
5. Review interface shows research output, limits, uncertainty, model version and citations; clinician sign-off records assessment only. Never auto-write diagnosis or treatment plan.
6. Evaluate patient-level train/validation/test splits, leakage, external validation where possible, calibration and subgroup error; prioritize one or two tasks.

**Acceptance criteria:** Wrong modality/lead rejected; missing data abstains; model error does not change patient state; no automatic diagnosis; metrics reproduced from locked dataset split; reviewer cannot silently edit raw inference.

</details>

#### API contracts

##### M19.01 — `GET /research/models`

**Authorization:** Researcher/authorized doctor  
**Success:** HTTP 200

**Request:**

Query: task?, cursor?, limit?

**Response (data):**

```json
{
  "items": [
    {
      "id": "model_ct_demo",
      "version": "0.1.0",
      "task": "CT_HEMORRHAGE_RESEARCH",
      "status": "RESEARCH_ONLY",
      "inputModality": "CT"
    }
  ],
  "nextCursor": null
}
```

**Errors / constraints:** 403 RESEARCH_SCOPE_DENIED.

##### M19.02 — `POST /research/models`

**Authorization:** Authorized model maintainer  
**Success:** HTTP 201

**Request:**

```json
{
  "task": "CT_HEMORRHAGE_RESEARCH",
  "version": "0.1.0",
  "artifactSha256": "<hex-sha256>",
  "evaluationRef": "eval_fixture_01",
  "intendedUse": "SYNTHETIC_RESEARCH_ONLY"
}
```

**Response (data):**

```json
{
  "id": "model_ct_demo",
  "status": "DRAFT"
}
```

**Errors / constraints:** 409 MODEL_VERSION_EXISTS; 422 EVALUATION_REQUIRED.

##### M19.03 — `POST /research/models/{modelId}/approve`

**Authorization:** Independent authorized research reviewer  
**Success:** HTTP 200

**Request:**

```json
{
  "decision": "ENABLE_RESEARCH_ONLY",
  "reason": "Synthetic evaluation reviewed"
}
```

**Response (data):**

```json
{
  "id": "model_ct_demo",
  "status": "RESEARCH_ONLY"
}
```

**Errors / constraints:** 403 INDEPENDENT_REVIEW_REQUIRED; 422 EVALUATION_INCOMPLETE.

##### M19.04 — `POST /admissions/{admissionId}/diagnostic-jobs`

**Authorization:** Research-authorized DOCTOR + Idempotency-Key  
**Success:** HTTP 202

**Request:**

```json
{
  "modelId": "model_ct_demo",
  "inputRefs": [
    "rep_ct_demo"
  ],
  "purpose": "SYNTHETIC_RESEARCH"
}
```

**Response (data):**

```json
{
  "jobId": "inf_ct_01",
  "status": "QUEUED"
}
```

**Errors / constraints:** 422 MODALITY_MISMATCH or MODEL_DISABLED; 403 REAL_DATA_NOT_ALLOWED.

##### M19.05 — `GET /inference-jobs/{jobId}`

**Authorization:** Authorized research clinician  
**Success:** HTTP 200

**Request:**

None

**Response (data):**

```json
{
  "id": "inf_ct_01",
  "status": "REVIEW_REQUIRED",
  "modelVersion": "0.1.0",
  "result": {
    "researchLabel": "DEMO_CLASS_A",
    "confidence": 0.61,
    "explanationArtifactId": "obj_heatmap_01"
  },
  "limitations": [
    "Synthetic fixture; not diagnostic"
  ]
}
```

**Errors / constraints:** 404 JOB_NOT_FOUND. ABSTAINED status has reason and no prediction.

##### M19.06 — `POST /inference-jobs/{jobId}/review`

**Authorization:** Authorized research clinician  
**Success:** HTTP 200

**Request:**

```json
{
  "decision": "REVIEWED_RESEARCH_ONLY",
  "comment": "Synthetic result reviewed"
}
```

**Response (data):**

```json
{
  "id": "inf_ct_01",
  "status": "REVIEWED"
}
```

**Errors / constraints:** 409 RESULT_NOT_READY; 422 INVALID_DECISION.

##### M19.07 — `POST /admissions/{admissionId}/advisory-jobs`

**Authorization:** Research-authorized DOCTOR + Idempotency-Key  
**Success:** HTTP 202

**Request:**

```json
{
  "kind": "PRE_SURGICAL_RESEARCH",
  "inputRefs": [
    "rep_01",
    "ord_01"
  ],
  "context": {
    "procedureCode": "DEMO-PROCEDURE"
  }
}
```

**Response (data):**

```json
{
  "jobId": "adv_01",
  "status": "QUEUED"
}
```

**Errors / constraints:** 422 INPUT_SCOPE_INVALID or INSUFFICIENT_HISTORY. TRAJECTORY_RESEARCH kind requires timeWindow and outcome specification.

##### M19.08 — `GET /advisory-jobs/{jobId}`

**Authorization:** Authorized research clinician  
**Success:** HTTP 200

**Request:**

None

**Response (data):**

```json
{
  "id": "adv_01",
  "status": "REVIEW_REQUIRED",
  "findings": [
    {
      "code": "DEMO_REVIEW_FLAG",
      "evidenceRefs": [
        "rep_01"
      ],
      "text": "Synthetic evidence requires review"
    }
  ],
  "limitations": [
    "Not a surgical clearance or treatment recommendation"
  ],
  "ruleVersion": "demo-v1"
}
```

**Errors / constraints:** 404 JOB_NOT_FOUND. ABSTAINED for missing evidence.

##### M19.09 — `POST /advisory-jobs/{jobId}/review`

**Authorization:** Authorized research clinician  
**Success:** HTTP 200

**Request:**

```json
{
  "decision": "REVIEWED_RESEARCH_ONLY",
  "comment": "Synthetic advisory reviewed"
}
```

**Response (data):**

```json
{
  "id": "adv_01",
  "status": "REVIEWED"
}
```

**Errors / constraints:** 409 RESULT_NOT_READY.

### M20 — Command portal, audit, jobs, integration and release

**Dependencies:** M01–M19  
**Owner:** All team members  
**Status:** Planned

**In simple words — Dashboard, testing and final release:** Connect all modules, check security, prepare the demo and collect real research results.

#### Implementation steps

1. Build dashboards showing only the records and totals allowed for the signed-in user.
2. Show background job progress, failures, permitted retries and audit history.
3. Protect audit logs from editing; set retention, backup and key rotation procedures.
4. Run complete workflow, concurrency, security, outage and performance tests. Save real benchmark results and screenshots.
5. Release only a synthetic-data prototype after safety tests pass. Document unfinished features and limitations.

**How to know this module is working:** Tests pass; no real patient data is in the demo; backup restoration works; all research claims have supporting evidence.

<details>
<summary>Exact engineering steps and acceptance tests (developer reference)</summary>

1. Build role-specific dashboard aggregate from authorized ward/encounter read models; no cross-tenant aggregate leakage.
2. Implement job polling, failure codes, cancellation before start, retry by explicit permission; create durable audit and monitoring endpoints with restricted scopes.
3. Implement audit tamper-evidence, append-only permissions, access log review, redaction and retention policy; establish backup/restore and key rotation.
4. Run end-to-end demo and chaos tests; export reproducible benchmark results, screenshots, architecture/ER/DFD diagrams and research references.
5. Release only after safety, privacy and synthetic-only gates; document unsupported features and evidence gaps.

**Acceptance criteria:** All module tests pass; no real PHI in demo; failed dependency visible; backup restore tested; audit records and source citation trace verified; final claims supported by measurements.

</details>

#### API contracts

##### M20.01 — `GET /wards/{wardId}/dashboard`

**Authorization:** Assigned clinical staff  
**Success:** HTTP 200

**Request:**

Query: asOf?

**Response (data):**

```json
{
  "wardId": "ward_01",
  "activeAdmissions": 2,
  "openAlerts": 1,
  "overdueDoses": 1,
  "reviewRequiredDoses": 1,
  "staleDevices": 0,
  "asOf": "2026-12-01T10:00:00Z"
}
```

**Errors / constraints:** 403 SCOPE_DENIED; counts only authorized records.

##### M20.02 — `GET /jobs/{jobId}`

**Authorization:** Original requester or authorized service  
**Success:** HTTP 200

**Request:**

None

**Response (data):**

```json
{
  "id": "job_ocr_01",
  "type": "REPORT_EXTRACTION",
  "status": "SUCCEEDED",
  "resultRef": "rep_01",
  "attempts": 1
}
```

**Errors / constraints:** 404 JOB_NOT_FOUND; failed status includes safe error code.

##### M20.03 — `POST /jobs/{jobId}/cancel`

**Authorization:** Original requester with permission  
**Success:** HTTP 200

**Request:**

```json
{
  "reason": "Synthetic job cancelled"
}
```

**Response (data):**

```json
{
  "id": "job_ocr_01",
  "status": "CANCELLED"
}
```

**Errors / constraints:** 409 JOB_ALREADY_RUNNING or NON_CANCELLABLE.

##### M20.04 — `GET /audit-events`

**Authorization:** Authorized auditor  
**Success:** HTTP 200

**Request:**

Query: action?, resourceType?, resourceId?, from?, to?, cursor?, limit?

**Response (data):**

```json
{
  "items": [
    {
      "id": "audit_01",
      "action": "DOSE_RESERVED",
      "actorId": "usr_01",
      "resourceId": "dose_01",
      "at": "2026-12-01T10:00:00Z",
      "requestId": "req_01"
    }
  ],
  "nextCursor": null
}
```

**Errors / constraints:** 403 AUDIT_SCOPE_DENIED; redact sensitive payloads.

##### M20.05 — `POST /audit-exports`

**Authorization:** Authorized auditor  
**Success:** HTTP 202

**Request:**

```json
{
  "from": "2026-12-01T00:00:00Z",
  "to": "2026-12-02T00:00:00Z",
  "purpose": "SYNTHETIC_RESEARCH_AUDIT"
}
```

**Response (data):**

```json
{
  "jobId": "job_audit_01",
  "status": "QUEUED"
}
```

**Errors / constraints:** 422 EXPORT_WINDOW_TOO_LARGE; 403 EXPORT_SCOPE_DENIED.

##### M20.06 — `GET /system/status`

**Authorization:** Authorized admin / operational staff  
**Success:** HTTP 200

**Request:**

None

**Response (data):**

```json
{
  "coreApi": "HEALTHY",
  "database": "HEALTHY",
  "mqtt": "DEGRADED",
  "ai": "HEALTHY",
  "demoMode": true
}
```

**Errors / constraints:** 403 FORBIDDEN; no infrastructure credentials or PHI.

### 6.21 Medication transaction implementation reference

**Simple explanation:** A dose starts as SCHEDULED. A valid scan changes it to RESERVED. A fresh online start changes it to IN_PROGRESS. Confirmation records the outcome. If the system is unsure what happened, it moves to REVIEW_REQUIRED rather than letting another nurse start automatically. The database lock makes concurrent reservations wait their turn.

```mermaid
stateDiagram-v2
    [*] --> SCHEDULED
    SCHEDULED --> RESERVED: atomic reserve
    RESERVED --> SCHEDULED: verified unused release
    RESERVED --> IN_PROGRESS: online start
    RESERVED --> REVIEW_REQUIRED: uncertain expiry
    IN_PROGRESS --> ADMINISTERED: verified outcome
    IN_PROGRESS --> REVIEW_REQUIRED: uncertain or interrupted
    SCHEDULED --> CANCELLED: authorized cancellation
    REVIEW_REQUIRED --> ADMINISTERED: reviewed evidence
    REVIEW_REQUIRED --> SCHEDULED: verified not given and reissue approved
    REVIEW_REQUIRED --> NOT_GIVEN: reviewed close
    ADMINISTERED --> [*]
    NOT_GIVEN --> [*]
    CANCELLED --> [*]
```

**Lock transaction pseudocode** (illustrative, not executable production code):

```text
reserve(actor, command, key):
  authenticate and validate schema
  BEGIN
  insert-or-lock idempotency row (tenant, actor, route, key)
  if prior result exists: compare payload hash; return recorded response
  lock admission by tenant + id FOR UPDATE
  lock medication order by tenant + id FOR UPDATE
  lock exact medication dose event FOR UPDATE
  re-check current membership, assignment, encounter, order revision, scans
  re-check schedule eligibility, active safety review and dose state
  if not SCHEDULED: persist safe conflict result; COMMIT; return 409
  create unpredictable reservation token; persist digest and owner
  UPDATE dose state = RESERVED, expires_at = db_now + configured_interval
  INSERT audit event and outbox event
  save encrypted replayable response with minimal expiry
  COMMIT
  return 200
```

All other writers use the same lock order and transactional invariants. Re-check authorization before returning any replayed result. A token returned by a replay may have expired; clients must read authoritative current state before start. A crashed transaction rolls back; a committed transaction with lost HTTP response is recovered via identical-key retry. Retry serialization/deadlock only with bounded backoff and same command identity. A timeout after start means **unknown outcome**, not permission to repeat physical action. Reconciliation can never be performed by an LLM or a timer. Use a DB clock for reservation validity, store separately the actual observed time, and preserve original actor and revision. Overdue status is computed independently of execution state, never auto-marks administered. The exact policy for dose timing windows and second-person verification must be approved rather than hard-coded from an example.

```mermaid
sequenceDiagram
  participant A as Nurse A
  participant B as Nurse B
  participant API as Authoritative API
  participant DB as PostgreSQL
  A->>API: POST reserve (key A)
  B->>API: POST reserve (key B)
  API->>DB: Transaction A locks exact dose
  DB-->>API: RESERVED committed
  API-->>A: 200 token + expiry
  API->>DB: Transaction B locks same dose after A
  DB-->>API: Existing RESERVED
  API-->>B: 409 DOSE_ALREADY_RESERVED
  A->>API: POST start (new key)
  API-->>A: IN_PROGRESS committed
  Note over A: Simulated administration only
  A->>API: POST confirm (new key)
  API-->>A: ADMINISTERED committed
```

### 6.22 Report verification workflow

**Simple explanation:** A report waits in a queue, gets extracted, and then waits for a human to check it. It becomes VERIFIED only after sign-off. If extraction fails, it can be retried. If the reviewer cannot trust the report, they reject it.

```mermaid
stateDiagram-v2
  [*] --> QUEUED
  QUEUED --> EXTRACTING
  EXTRACTING --> REVIEW_REQUIRED
  EXTRACTING --> FAILED
  FAILED --> QUEUED: explicit retry
  REVIEW_REQUIRED --> VERIFIED: human sign-off
  REVIEW_REQUIRED --> REJECTED
  VERIFIED --> VERIFIED: immutable amended version
```

Create immutable extraction attempts and field evidence. Use normalized bounding boxes `[xMin,yMin,xMax,yMax]` in `[0,1]`, page number, original source hash and extraction version. A field with missing unit, unknown code, incompatible dimension, multiple contradictory candidates or uncertain patient identity cannot silently pass. Use decimal arithmetic for normalization; never compare only text. Stage 1 bypasses OCR, not verification. Stage 2 independently executes two engines; two agreeing engines can still both be wrong. Stage 3 shows source evidence and requires explicit review for all safety-relevant fields. On successful verification, atomically persist signed revision + timeline entry + index outbox; RAG worker fetches only current, authorized revision. Report amendment invalidates old chunks and queued outputs before reindexing.

### 6.23 Clinical research model implementation matrix

**Simple explanation:** Each AI model needs the right kind of input and a dataset with labels for that exact task. A model that classifies ECG rhythms does not automatically predict heart failure. A dataset for general liver disease does not automatically support fatty liver grading.

| Task | Candidate data and model from supplied documents | Required limitation / experiment |
| --- | --- | --- |
| Deterioration | MIMIC-III/IV, PhysioNet; logistic regression, RF, XGBoost, LSTM | Define outcome and prediction horizon before splitting; avoid leakage from interventions; compare NEWS2 on matching eligible cohort |
| CT hemorrhage | RSNA intracranial hemorrhage; ResNet or 3D CNN, YOLO only if valid localization labels | Separate classification from localization; assess subtype and patient-level split; only claim validated task |
| ECG | PTB-XL and MIT-BIH; 1D-CNN or transformer | Lead count, sampling and labels differ; arrhythmia classification is not equivalent to heart failure prediction; bedside single-lead prototype is not 12-lead diagnostic input |
| Breast imaging | CBIS-DDSM; CNN, optional detection, Grad-CAM | Match mammography task, lesion annotations and preprocessing; patient-level grouping; no general cancer diagnosis claim |
| Liver research | ILPD; XGBoost, future ultrasound CNN | ILPD concerns liver disease, not confirmed fatty-liver severity or paired ultrasound; obtain appropriate labeled dataset before claiming fatty-liver grading |
| Interaction NLP | DrugBank/OpenFDA and clinical corpora; BioBERT/ClinicalBERT | Verify license and coverage, expert review of extraction, no automatic prescribing or proof of safety |
| Future trajectory / pre-surgical | Longitudinal verified synthetic data; deterministic review flags, optional time-series model | Specify outcome, horizon, population, uncertainty and review scope; no surgical clearance or treatment recommendation |

Dataset access, license, use restrictions, ethics review and actual model quality are unverified. Use controlled access where required; do not scrape restricted datasets or bypass access controls. For demo, use synthetic inputs with explicit fixtures; keep any licensed research data in separate controlled environment.

## 7. Real-time events and asynchronous jobs

**In simple words:** MQTT brings device measurements to the server. WebSockets send live updates from the server to screens. Background jobs do slower work (OCR, AI, reminders and notifications) without blocking a normal API request.

### 7.1 MQTT contract (device → broker → worker)

Topic: `medishield/v1/devices/{deviceId}/telemetry` (publish by that authenticated device only); `/status` for heartbeat and last will; `/ack` for optional application receipt. MQTT QoS 1 with duplicate delivery expected. Broker ACL prevents wildcard subscriptions by devices. Certificate identity maps to path device ID. The following sample is a bench/simulator payload, not a clinical reading.

```json
{
  "schemaVersion": 1,
  "deviceId": "dev_01",
  "bootId": "boot_01",
  "seq": 42,
  "measuredAt": "2026-12-01T10:00:00Z",
  "clockStatus": "SYNCED",
  "source": "SIMULATOR",
  "metrics": [
    {"code": "HR", "value": 82, "unit": "beats/min", "quality": "VALID"},
    {"code": "SPO2", "value": 97, "unit": "%", "quality": "VALID"}
  ],
  "firmwareVersion": "0.1.0"
}
```

Do not accept tenant/patient assignment from payload. On ingest: authenticate → schema check → resolve time-bound assignment → verify sequence/time/quality → dedupe → persist → outbox → scoring and live event. Store receipt time separately. If clock unsynced, quarantine for clinical rules and label time uncertain. Firmware samples at modality-appropriate rates; one-second summary is not ECG waveform sampling. Use a bench signal generator or simulator, never patient-connected hobbyist hardware. Buffer bounded data on disconnect; reconnect with backoff and retain original sequence/time. Telemetry receipt confirms durable ingestion, not clinical validity or alert delivery.

### 7.2 WebSocket / Socket.IO contract

Authenticate handshake with short-lived session; authorize room membership on subscribe and periodically/revocation events. Only server derives ward/admission room IDs. No broad raw MQTT subscription by mobile. Client uses sequence/version to discard out-of-order updates; on reconnect fetch fresh REST snapshots and then replay bounded event cursor. Events are hints, not authoritative medication permission.

```json
{
  "eventId": "evt_01",
  "type": "dose.state.changed",
  "schemaVersion": 1,
  "occurredAt": "2026-12-01T10:00:42Z",
  "resourceId": "dose_01",
  "resourceVersion": 4,
  "cursor": "opaque-event-cursor",
  "data": {"admissionId": "enc_01", "status": "ADMINISTERED"}
}
```

| Direction / type | Payload minimum and handling |
| --- | --- |
| Client `subscribe` | `{scopeType: "ADMISSION", scopeId: "enc_01", afterCursor: null}`; ack `{status:"SUBSCRIBED"}` or safe forbidden error |
| Client `unsubscribe` | scope type + ID; remove authorized subscription |
| `dose.state.changed` | dose ID, encounter, state, version; invalidate REST cache |
| `vitals.updated` | encounter, metric code, value/unit, quality, observedAt, freshness; bounded display update |
| `device.status.changed` | device ID, status, last seen; stale banner |
| `news2.assessed` | assessment ID, status, score nullable, rule version; fetch details |
| `alert.created`, `alert.updated` | alert ID, severity/status, version; authoritative alert queue refresh |
| `handoff.updated` | handoff ID, state, version, cutoff delta flag |
| `report.review.required`, `report.verified` | report ID, status, version; authorized reviewers only |
| `job.updated` | job ID, status, result ref; requester scope |
| `grant.revoked`, `session.revoked` | invalidate local state, close subscriptions, force reauth where required |

Replay is bounded; if cursor expired return `RESYNC_REQUIRED` and fetch snapshot. Realtime event should contain minimum necessary data; no raw tokens, full report text or national identifiers.

### 7.3 Durable background jobs

| Queue / job | Input references | Result / failure handling |
| --- | --- | --- |
| `outbox.relay` | outbox ID | Publish event, mark attempt/receipt; at-least-once delivery; consumers dedupe |
| `dose.schedule`, `dose.expiry` | order/dose ID + revision | Generate occurrences or REVIEW_REQUIRED; DB lock authority; no auto-redose |
| `telemetry.ingest`, `ews.evaluate` | sample/encounter + rule version | assessment + alert event; stale/missing status visible |
| `alert.escalate`, `alert.deliver` | alert ID, level, version, recipient/channel | Recheck state under lock; receipt/failure; durable next escalation |
| `file.scan`, `report.extract` | object/report ID + source hash | CLEAN/REJECTED or review candidates; quarantine and bounded retry |
| `voice.transcribe`, `handoff.summarize` | voice/handoff ID + input version | Structured draft; fallback manual/structured snapshot |
| `rag.index`, `rag.answer` | verified source/version or scoped query ID | current chunks or cited answer/abstention; recheck access before publish |
| `referral.pdf`, `fhir.export`, `audit.export` | authorized source revision + scope | Private object ID, expiring access; recheck access before download |
| `model.infer`, `advisory.evaluate` | registry ID/version, source refs | Research draft/OOD abstention or safe failure |

Use job IDs stable across retries, unique logical operation IDs, bounded exponential backoff, timeout, dead-letter queue, version guards and explicit cancellation. Store status `QUEUED → RUNNING → SUCCEEDED/FAILED/CANCELLED`; domain status is separate (e.g. job SUCCEEDED, report REVIEW_REQUIRED). Jobs carry object references rather than raw patient text. Track processing lag, stale workers, retries and DLQ. Durable jobs must recheck user/grant scope and source version before processing and exposing results; do not process stale or revoked grants.

### 7.4 Internal AI service contract (private, not client-facing)

**Simple explanation:** The main backend asks the Python AI service to perform a specific job. Python returns a draft or says it cannot answer. The main backend checks the result; the AI service does not directly write authoritative patient records.

Use mTLS or short-lived service tokens, network ACL, allowlisted tasks, Pydantic schemas, model/provider version, deadline and correlation ID. The worker creates the job in the authoritative DB, calls FastAPI, validates result and persists draft. FastAPI has no general write access to clinical tables. For RAG, read-only retrieval is scoped by the authoritative API or worker; no arbitrary patient search in AI service.

Each operation below uses POST with request/response JSON; HTTP 200 for valid completed computation, 422 invalid input, 429 capacity, 503 dependency unavailable. Worker handles timeouts asynchronously; no direct public AI call.

| Internal path | Task | Additional contract |
| --- | --- | --- |
| `/internal/v1/reports/extract` | Digital parse / dual OCR | Input file object reference, content type, expected report type, engine config; output field candidates and source locators |
| `/internal/v1/speech/transcribe` | Voice draft | Input audio ref, language hint; output transcript, segments, uncertainties and validated draft |
| `/internal/v1/handoff/summarize` | SBAR | Input frozen source snapshot; output SBAR + source IDs, no novel advice |
| `/internal/v1/embeddings` | Index/query embeddings | Input permitted texts with IDs, model version; output vectors/dimension; never log texts |
| `/internal/v1/rag/answer` | Grounded response | Input scoped evidence snapshot and question; output cited answer or abstention |
| `/internal/v1/models/infer` | Deterioration / specialized research | Input task, registry ID/version, permitted artifact refs; output quality, task labels, confidence, explanation refs |
| `/internal/v1/advisory/evaluate` | Research review flags | Input approved rule/model version and verified facts; output flags with evidence and limitations |

Common request fields `jobId`, `requestId`, `deadlineAt`, `taskVersion`, `input`; common response `jobId`, `status` (`DRAFT`, `ABSTAINED`), `modelVersion`, `output`, `limitations`. Examples (synthetic):

```json
{
  "jobId":"job_ocr_01","requestId":"req_01","deadlineAt":"2026-12-01T13:00:30Z","taskVersion":"extract-v1",
  "input":{"objectRef":"obj_01","reportType":"BLOOD_PANEL","engineMode":"DUAL"}
}
```
```json
{
  "jobId":"job_ocr_01","status":"DRAFT","modelVersion":"pipeline-demo-v1",
  "output":{"fields":[{"code":"DEMO_ANALYTE","candidates":[{"engine":"PADDLE","value":"10","unit":"demo-unit","page":1,"bbox":[0.1,0.2,0.4,0.3]},{"engine":"VISION","value":"11","unit":"demo-unit","page":1,"bbox":[0.1,0.2,0.4,0.3]}],"needsReview":true}]},"limitations":["Human verification required"]
}
```

| Task | Example `input` JSON | Example `output` JSON (within common response) |
| --- | --- | --- |
| Speech | `{"audioRef":"obj_audio_01","languageHint":"hi-en"}` | `{"transcript":"Synthetic note","draft":{"text":"Synthetic note","observedAt":null},"uncertainties":["TIME_NOT_EXPLICIT"]}` |
| SBAR | `{"snapshotId":"snap_01","facts":[{"ref":"dose_03","status":"REVIEW_REQUIRED"}]}` | `{"sbar":{"situation":"Review pending","background":"See evidence","assessment":"Unresolved item","recommendation":"Review assigned task"},"sourceRefs":["dose_03"]}` |
| Embeddings | `{"modelVersion":"embed-demo-v1","texts":[{"id":"chunk_01","text":"Synthetic record"}]}` | `{"dimension":3,"vectors":[{"id":"chunk_01","values":[0.1,0.2,0.3]}]}` (toy dimension; actual dimension pinned to model/schema) |
| RAG | `{"question":"What is recorded?","evidence":[{"id":"src_01","text":"Synthetic record exists"}]}` | `{"answer":"A synthetic record exists. [1]","citationIds":["src_01"],"claims":[{"text":"A synthetic record exists","sourceIds":["src_01"]}]}` |
| Inference | `{"modelId":"model_ct_demo","modelVersion":"0.1.0","inputRefs":["obj_ct_01"]}` | `{"quality":"RESEARCH_ONLY","label":"DEMO_CLASS_A","confidence":0.61,"explanationRef":"obj_heatmap_01"}` |
| Advisory | `{"kind":"PRE_SURGICAL_RESEARCH","ruleVersion":"demo-v1","facts":[{"ref":"rep_01","status":"VERIFIED"}]}` | `{"findings":[{"code":"DEMO_REVIEW_FLAG","sourceIds":["rep_01"]}],"disclaimer":"Research only"}` |

Timeouts and unavailable providers must be returned as explicit failure states; never replace with unlabeled fabricated inference. Validate numeric results, artifact hashes, source refs and version consistency. A valid JSON schema is not proof of clinical truth.

## 8. Client application implementation

**In simple words:** Create a screen for each role and connect its buttons and forms to the correct APIs. The phone can keep limited notes offline, but it cannot approve a medication action without a live server check.

### 8.1 React Native navigation and feature ownership

| Screen / feature | APIs and UI states |
| --- | --- |
| Login / hospital selection | M02; loading, MFA, invalid, session expired |
| Ward Home / task list | M03, M07, M20; assigned ward, overdue, blocked, stale, empty |
| Patient detail | M04, M10, M14, M15; identity status, history, allergies, data freshness |
| Scanner | M04 wristband resolve, M06 scan-check/reserve/start/confirm/release; mismatch, unavailable, reserved, in progress, review required |
| Medication schedule | M05–M07; due time, state, route and source, refresh and conflict |
| Vitals monitor | M09–M12; unit/quality, trend, NEWS2 complete/incomplete, alert acknowledgement |
| Voice logger | M15 upload + M16; recording, queued, edit draft, review, failed/manual fallback |
| Handoff | M13; draft, signed, incoming review, delta stale, accepted |
| Offline sync | M16; pending count, retryable, conflict, rejected, last confirmed sync |

Implement vertical slices in `mobile/src/features/<name>/{api,components,hooks,screens,schemas}`. API client attaches token, request ID and idempotency key; preserve same key for same command after network failure. Keep access token in memory/secure storage, not ordinary AsyncStorage. Zustand stores UI state only; TanStack Query caches authorized server responses. Do not persist all query cache to disk. App backgrounding or connectivity loss invalidates scan-check and requires authoritative revalidation before start. Never optimistic-update medication state to ADMINISTERED. Provide manual fallback for voice and low-bandwidth layouts. Camera scans are debounced; one request at a time per screen; server still handles races.

### 8.2 Web portal route map

| Route (proposed) | Roles | Implementation |
| --- | --- | --- |
| `/login` | All account types | Auth, MFA, explicit context selection |
| `/platform/dashboard`, `/platform/hospitals`, `/platform/hospital-applications` | Super Admin | Application review, approval, provision, activation, restrict/archive |
| `/platform/users`, `/platform/audit`, `/platform/settings` | Super Admin | Account metadata, ban/restore, sessions, audit and policy |
| `/admin/setup`, `/admin/departments`, `/admin/wards`, `/admin/beds` | Hospital Admin | Setup and operational configuration |
| `/admin/staff`, `/admin/invitations` | Hospital Admin | Staff invitations, credential reviews, access and assignments |
| `/reception/queue`, `/reception/register`, `/reception/admissions` | Receptionist | Walk-in, provisional patient, clinician approval, bed and wristband |
| `/ward/tasks` | Ward staff | Assigned non-clinical tasks and readiness |
| `/patient/signup`, `/patient/link` | Patient | Optional account verification and reviewed record link |
| `/patient/dashboard`, `/patient/records`, `/patient/sharing`, `/patient/corrections` | Patient / scoped caregiver where allowed | Released records, secure downloads, sharing and review requests |
| `/patient/access` | Patient / caregiver | Verified grant and account recovery |
| `/dashboard` | Doctor/nurse/admin | Scoped summary and separate operational versus clinical dashboards |
| `/wards/[wardId]` | Assigned staff | Occupancy, live alerts, vitals, overdue tasks |
| `/patients/[patientId]` | Assigned care | Identity, encounters, verified timeline, consent |
| `/admissions/[id]/orders` | Doctor, read nurse | Catalog, interaction review, order revision |
| `/admissions/[id]/reports` | Lab/doctor/nurse | Upload, job status, side-by-side verification |
| `/admissions/[id]/research` | Research-authorized clinicians | Model results, quality, explanation, review |
| `/admissions/[id]/discharge` | Doctor | Review unresolved items, sign, create referral |
| `/referral` | Receiving clinician | Secure redeem, limited view, RAG and citations |
| `/admin/staff`, `/admin/devices`, `/admin/audit` | Authorized admin/auditor | Provisioning, access scopes, revocation and audit |

Use server-rendered authentication boundary with no public clinical cache, CSRF protection, strict content-security policy, secure cookies, and sanitized output. For each clinical card show provenance, observation timestamp, quality and verification status. Distinguish simulated data, stale data, missing data, and actual error. Ensure keyboard navigation, adequate touch target, screen reader labels and text/icon alongside color warnings.

### 8.2A Page-level build checklist

| Screen | Main API sequence | Empty/error state |
| --- | --- | --- |
| Platform hospital onboarding | Create draft → upload → submit → review → provision → invite → activate | Missing evidence, duplicate code, incomplete setup |
| Platform users | List → detail → edit metadata / moderation → history | Protected last admin, version conflict, rejected scope |
| Hospital setup | Current hospital → departments → wards → beds → invite → credential review | Setup-only banner; no clinical screens |
| Reception | Local lookup → register → queue → clinician decision → bed availability → admission → wristband | Duplicate candidate review, no bed available, offline intake guidance |
| Ward staff | Assigned tasks → update progress → bed readiness | Not assigned, occupied bed, stale queue |
| Doctor | Assigned encounters → prescription → report/alert review → discharge | No assignment, invalid or uncertain source |
| Nurse | Assigned doses → scan → reserve/start/confirm → observation → handoff | Duplicate lock, offline safety mode, review required |
| Patient | Sign up/verify → invitation link review → released records → sharing/correction | Unlinked account, withdrawn release, expired grant |
| Caregiver | Accept verified invitation → view scoped releases | Revoked or expired grant |

Every page needs loading, empty, unauthorized, validation, conflict and retry states. Do not render clinical content before authorization resolves. Clear sensitive query cache on logout, context switch or revocation. Use accessible labels and visible demo markers.

### 8.3 Offline sync local schema and state

```sql
CREATE TABLE pending_operations (
  operation_id TEXT PRIMARY KEY,
  actor_id TEXT NOT NULL,
  hospital_id TEXT NOT NULL,
  admission_id TEXT NOT NULL,
  type TEXT NOT NULL CHECK(type IN ('CREATE_NOTE','CREATE_OBSERVATION','CREATE_DIET_LOG')),
  payload_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  status TEXT NOT NULL CHECK(status IN ('PENDING','SENDING','CONFLICT','REJECTED','APPLIED')),
  attempts INTEGER NOT NULL DEFAULT 0
);
```

Encryption and access scope are prerequisites to any sensitive local cache. If encryption unavailable, use synthetic data only and disable clinical offline persistence. Sync after reconnect, foreground and user retry; max 50 items per batch; per-operation scope and validation; diet requires M08 safety review and may sync as a factual draft. Delete payload on confirmed application per policy. Logout wipes cached records and handles unsynced items through explicit user/reviewer workflow; never silently transfer queue to another account. Paper downtime reconciliation is online M07 and distinct from this queue.

## 9. Testing and research evaluation

**In simple words:** Test small functions, then test them together with real services, then test the whole user journey. Use fake patients, test simultaneous scans, disconnect services on purpose, and measure actual speed and AI quality. Targets are not measured results.

### 9.1 Test pyramid and acceptance matrix

| Layer | Tools / method | Mandatory scenarios |
| --- | --- | --- |
| Unit | Vitest/Jest, Pytest | State transitions, rule fixtures, schema, idempotency hash, time/unit normalization |
| DB integration | PostgreSQL container, Supertest | Real row-lock race, order/cancel/reserve race, bed collision, rollback/outbox, tenant isolation |
| Device | Simulator + broker integration | Duplicates, packet delay, wrong device, reconnect, clock skew, reassignment, stale signal |
| API contract | OpenAPI validation + generated clients | Every endpoint request/response/status, malformed bodies, 401/403/404, retries, pagination, version conflict |
| AI | Pytest + locked fixtures | OCR discrepancy, voice ambiguity, RAG missing/injection/cross-patient, OOD, provider timeout, stale source |
| E2E | Playwright web, Maestro/Detox mobile | Register → encounter → scan → conflict → alert → report → handoff → referral → revoke |
| Security | Threat model, dependency and secret scan, access matrix tests | IDOR/BOLA, JWT replay, role escalation, CSRF, MQTT ACL, file traversal/XXE, malicious PDFs, token exposure |
| Failure injection | Kill worker/broker/AI/API, delay network, restore DB | No unsafe fallback, unknown dose reviewed, outbox recovery, alert stale state, bounded retry |
| Load | k6 or equivalent; PostgreSQL metrics | Concurrent doses, telemetry at defined rate, alert lag, job queue capacity |
| Accessibility/usability | Task-based synthetic evaluation | One-handed scanning, visible red conflict, accessible labels, handoff completeness, correction rates |

### 9.2 Example deterministic acceptance cases

| ID | Setup/action | Expected outcome |
| --- | --- | --- |
| T01 | 100 distinct authenticated commands against same eligible dose | Exactly one successful reservation; other authorized commands conflict; one reservation audit event |
| T02 | Reserve response lost after commit, retry same key/payload | Same original result; no additional reservation |
| T03 | Reuse key with changed dose ID | 409 IDEMPOTENCY_KEY_REUSED |
| T04 | Dose reserved, connection lost before start | Electronic administration unavailable; expiry → review, no auto-redose |
| T05 | Start committed, confirm response lost | Query/replay original command; no repeat physical action; unresolved outcome review |
| T06 | Cancel order races start | Serialized outcome; no cancelled order started and no active dose erased |
| T07 | Admission transfer races reserve | Lock policy serializes; review-required dose cannot silently move |
| T08 | Replay offline note and invalid medication command | One note; forbidden medication operation rejected |
| T09 | Device packet replay and reassignment | No duplicates; late data bound to correct valid assignment or quarantined |
| T10 | NEWS2 missing required observation | INCOMPLETE, null score, missing fields visible |
| T11 | Notification provider down; escalation due | Durable escalation continues or visible failure; never auto-resolve |
| T12 | OCR candidate values differ / patient identity mismatch | Review required or blocked; no automatic index |
| T13 | RAG user asks for absent fact / prompt injection / another patient | Abstain or deny; no unsupported answer or cross-scope sources |
| T14 | Referral QR scanned by unauthenticated or wrong-org actor | No clinical content; no grant redemption |
| T15 | Consent revoked while RAG job runs | Output suppressed; citations inaccessible; session invalidated |
| T16 | Handoff snapshot stale at acceptance | Delta review required before transfer |
| T17 | Model receives mismatched lead count/modality | Abstain or reject; no diagnosis record |
| T18 | Backup restored to isolated environment | Verify clinical consistency, outbox recovery and audit integrity with synthetic fixtures |

### 9.2A Platform and portal regression tests

| Test | Expected result |
| --- | --- |
| Two requests provision same approved application | One tenant; retry returns original result |
| Unapproved application / unverified administrator tries activate | 409; no clinical access |
| Global ban while access token and socket are active | Next call denied; socket disconnected; refresh denied; audit remains |
| Local suspension of staff working at A and B | A denied; B remains subject to own permissions |
| Ban final platform admin or remove final hospital admin | Conflict; replacement/recovery required |
| Hospital restriction during reserved or started dose | No unsafe auto-release; supervisor reconciliation and continuity workflow |
| Reception tries prescribe / ward staff tries confirm dose | 403 or hidden 404; no data changed |
| Two reception requests use same decision or same bed | Exactly one succeeds; conflict otherwise |
| Patient account without verified link attempts read | Denied, no patient existence leak |
| Caregiver changes linkId or releaseId | Denied unless exact scope matches |
| Release withdrawn after download ticket created | New fetch denied; audit retained |
| Cross-tenant platform search includes patient identifier | Reject unsupported filter; never return medical data |
| Staff role changed while background job runs | Recheck actor/service grant and input scope; stop unauthorized delivery |
| Patient asks correction to signed report | Review request only, original preserved |

### 9.3 Performance targets (not measured)

The PRD sets aggressive latency and accuracy targets. Test them under explicitly declared workload and environment; report misses, do not invent numbers. Suggested baseline: 20 concurrent staff clients, 10 simulated devices at one summary/second, and separate 100-request burst on one dose; expand independently after baseline. Measure p50/p95/p99, errors, resource usage and network conditions; do not conflate UI, HTTP and provider latency.

| Measurement | Proposed target from PRD / engineering interpretation | Method |
| --- | --- | --- |
| Medication verification | API p95 <300 ms under baseline; no unsafe concurrency outcome | From server request to commit/response; separate camera/UI latency |
| Device-to-visible alert | p95 <2 s for eligible synthetic rule event | Device event clock to rendered alert with clock alignment; exclude invalid data, report loss separately |
| Voice processing | PRD <3 s aspirational for short clips | Upload end to draft ready; separately measure recording, review and full task time |
| Local identity lookup | p95 <1 s | Authorized tenant lookup using synthetic keyed index |
| OCR | PRD >99.5% aspirational verified-field accuracy | Raw per-engine, merged, reviewed fields separately; gold truth, confidence interval and clinically consequential errors |
| Handoff | PRD 30-second briefing aspiration | Measure snapshot generation and review time separately; required item retention and omission severity |
| RAG | No unsupported clinical claims as design goal, not guarantee | Citation precision, retrieval recall, groundedness, abstention, leakage and response latency |

### 9.4 Research benchmark protocol

Define population, dataset version, task label, intended use, split strategy, primary endpoint and acceptance thresholds before experiments. Keep independent patient-level test set; prevent duplicates and future leakage; preprocess fit on train only. Report confidence intervals, calibration, subgroup performance, missing-data handling, false negatives/positives, limitations, compute and inference time. Use external validation only when access and task match; no clinical effectiveness claim from synthetic tests.

| Model | Precision | Recall | F1 | AUROC / AUPRC | Calibration | Inference p95 |
| --- | --- | --- | --- | --- | --- | --- |
| Logistic regression | TBD | TBD | TBD | TBD | TBD | TBD |
| Random forest | TBD | TBD | TBD | TBD | TBD | TBD |
| XGBoost | TBD | TBD | TBD | TBD | TBD | TBD |
| LSTM / 1D-CNN (task-specific) | TBD | TBD | TBD | TBD | TBD | TBD |

Compare on the same task and split, not across unrelated disease datasets. For imaging include task-appropriate sensitivity/specificity and localization metrics if labels support it. For OCR compare raw vs merged vs reviewed; for voice report word error rate plus critical entity/number accuracy across languages; for RAG report retrieval and evidence-supported answer metrics. Simulated workflow study: counterbalanced baseline vs prototype, predefined cases, capture double-dose opportunities, missed tasks, handoff omissions and completion time. Record sample sizes, uncertainty and reviewer agreement. No invented AUROC, latency or patient mortality improvement.

## 10. Deployment and operational runbooks

**In simple words:** First run the project on a developer computer, then a shared test server, then a synthetic-data demo deployment. Keep credentials private, watch for failures, and practice restoring backups. Do not deploy for real care without the necessary approvals.

### 10.1 Environment progression

| Environment | Data and infrastructure | Gate |
| --- | --- | --- |
| Local | Docker Compose, fake fixtures, MQTT simulator, mock AI provider | Tests and repeatable migration |
| CI | Ephemeral DB/broker, mock external services, synthetic fixtures | Contract/security/integration suite |
| Demo/staging | Web Vercel or same container host; API/worker/AI private network; private DB/storage/broker | TLS, backup, smoke, demo flag and synthetic banner |
| Future clinical deployment | Separate risk assessment, validated hardware, approved governance, regulated hosting and identity | Not authorized by this plan |

Deploy order: provision network and service identities → private DB/Redis/broker/storage → migration dry-run and backup → apply reviewed migrations → core API readiness → worker/outbox → AI service → web/mobile configured endpoints → smoke and access tests. Use backward-compatible expand/contract migrations, staged rollout and documented rollback; avoid destructive DB downgrade. Pin image digests, lockfiles and model artifact hashes. Never expose PostgreSQL, Redis or internal AI endpoints to public network. TLS for API/MQTT, secret manager, restrictive CORS and rate limits. Synthetic seed only in demo; separate tenants, keys and databases from any research environment.

### 10.2 Monitoring and incident handling

| Signal | Required response |
| --- | --- |
| DB unavailable or API not authoritative | Mark safety lock unavailable; disable reserve/start; show downtime workflow; recover and reconcile uncertain doses |
| Broker disconnect or stale devices | Mark stream stale/unknown; no fabricated normal values; recover and review gaps |
| Worker queue lag / failed escalation | Visible operational degraded status; durable retry/DLQ and authorized manual review |
| AI outage / timeout | Manual note/report review, structured SBAR, RAG unavailable/abstain; no effect on core locks |
| Access anomaly / token leakage | Revoke sessions/grants/credentials; preserve audit; investigate and rotate keys |
| Data corruption / migration issue | Stop unsafe writes; restore in isolated environment; validate clinical/audit state before resume |

Metrics: request latency/error by endpoint, database pool/lock wait/deadlock, reserve conflict rate, unresolved dose count, outbox age, telemetry freshness/drop/dedupe, escalation overdue, delivery failure, AI job latency/failures, RAG abstention. Avoid PHI in metric labels, logs and traces. Set alert thresholds from actual baseline and governance. Proposed engineering recovery objectives for demo only: RPO/RTO must be chosen and measured, not promised. Run scheduled backup and restore drill with checksum verification. Encrypted backup, least privilege and audited restore; key rotation and retention policy reviewed by institutional owners.

### 10.3 Privacy, compliance and safety checklist

- Synthetic-only demo; no real Aadhaar, ABHA, lab, ECG, patient name or actual clinical data in repo, logs or public deployment.
- Future national ID matching needs authorized identity workflows, legal basis, minimization and specific UIDAI/ABDM integration review; keyed HMAC is a proposed protection, not authorization or anonymization. Provide provisional local ID path.
- DPDP Act, applicable rules and commencement dates; Medical Devices Rules/CDSCO; ABDM policies and FHIR profiles: verify current applicability with qualified institutional/legal/regulatory reviewers before real deployment. Do not claim certification or compliance.
- Consent, purpose limitation, access review, expiry/revocation, record retention, deletion/legal hold, incident handling and user rights need institutional policy. Human verification does not itself make the product compliant.
- No patient-connected unvalidated sensor or autonomous treatment; no clinical deployment without risk management, ethics approval as applicable, intended-use definition, independent clinical validation and trained operators.

## 11. 24-week roadmap and ownership

**In simple words:** This is a proposed six-month schedule. The three team members can work in parallel, but shared contracts and safety checks must be ready before dependent modules are released.

Calendar is indicative. Start the MVP vertical slice early in parallel; finish module completeness later. Core safety and authorization are gates, not features to postpone until end. Each sprint concludes with runnable integration, reviewed PR, tests and demo evidence.

| Week | Abhishek — systems/full stack | Akanksha — AI/research | Aman — IoT/integration | Exit deliverable |
| --- | --- | --- | --- | --- |
| 01 | M01 repo, CI, ADR, Docker | Task scope and dataset inventory | Device/simulator architecture | Approved contracts and synthetic-only policy |
| 02 | M02 auth/RBAC + bootstrap Super Admin | Synthetic gold fixtures, research split protocol | MQTT simulator, topic schema | Auth + fake telemetry fixture |
| 03 | M02A onboarding/ban MVP + M03 setup/staff | Interaction fixture rules, RAG corpus | Broker ACL and device identity | Tenant/ward isolation |
| 04 | M03A reception/ward MVP + M04 patient/encounter/wristband | Verified seed records | Device assignment prototype | QR intake end-to-end |
| 05 | M05 orders/task list + M08 minimal check API | Voice adapter proof | Simulator data pipeline | One valid synthetic order |
| 06 | M06 reserve/start/confirm | RAG scoped seed query MVP | Live vitals and stale indicator | Real DB concurrency demo |
| 07 | M07 downtime/review, referral thin slice | Voice draft, citations MVP | Synthetic alert scenario | Integrated MVP workflows |
| 08 | M08 fixture interaction guard, harden MVP | Evaluate MVP groundedness/voice | Physical bench demo optional | Hackathon release gate |
| 09 | M09 device administration | Dataset access review, model baseline | Provisioning, assignment, replay | Device lifecycle |
| 10 | M10 observations/history | Quality/unit fixtures | Timescale/partition ingestion | Latest/history and dedupe |
| 11 | M11 scoring contracts | Approved NEWS2 fixtures, research baseline | Telemetry quality/freshness | Complete/incomplete score paths |
| 12 | M12 alerts/escalation | Deterioration evaluation | Outage/reconnect tests | Durable alert lifecycle |
| 13 | M13 shifts/SBAR UI | SBAR grounding | Ward integration | Signed handoff + delta |
| 14 | M14 timeline/discharge/FHIR + M04A portal link/release MVP | Source provenance fixtures | Integration tests | Longitudinal vault |
| 15 | M15 upload/review UI | Digital parse, dual OCR | File pipeline tests | Verified report pipeline |
| 16 | M16 voice/offline sync | Multilingual evaluation | Network loss simulation | Verified voice/manual note sync |
| 17 | M17 RAG API/UI | Hybrid retrieval and citation checks | Load/telemetry integration | Scoped RAG |
| 18 | M17 adversarial tests | Grounding/abstention metrics | End-to-end instrumentation | RAG safety gate |
| 19 | M18 referral/grant/PDF | Recipient-scoped queries | Cross-org testing | Referral lifecycle |
| 20 | M18 revoke + M04A sharing/correction/caregiver | Referral leakage tests | Failure scenarios | Full workflow release candidate |
| 21 | M19 model registry/UI | One or two specialized models | Research input adapters | Evaluated research task |
| 22 | M19 advisory contracts | Pre-surgical/trajectory research flags | Full pipeline profiling | Advisory review and abstention |
| 23 | M20 security/backup/load + admin lifecycle full regression | Benchmark tables and thesis methods | Hardware/chaos tests | Evidence and restore drill |
| 24 | M20 release, docs, viva | Results, limits and references | Demo rehearsals | Final project + research package |

**New scope scheduling:** The 24-week roadmap is a target, not a validated capacity estimate. Weeks 1–4 must complete the thin slice of onboarding, account moderation, staff hierarchy and intake before clinical work. Full administrative metadata, invitation recovery and ward operations can be finished in parallel with weeks 9–16; patient portal advanced sharing and correction in weeks 17–20; full security regression week 23. If time runs short, defer optional caregiver and advanced research models rather than weaken authentication, hospital isolation or clinical safety. Extend the calendar if full scope cannot pass gates.

Team responsibilities: Abhishek approves authoritative API/SQL/state contracts; Akanksha approves research methodology and AI output contracts; Aman approves IoT/device/integration contracts. Clinical rules need independent qualified clinical review, not engineering team sign-off alone. Cross-review each safety-sensitive PR. Sprint ticket template: module/requirement, dependencies, acceptance tests, API/DB changes, risk, owner, evidence and rollback. No ticket marked done until merged, integrated and verified. The early M17/M18 referral and RAG thin slice uses verified seeded records, minimal signed summary and the actual recipient/grant authorization checks; do not defer those checks until week 19. Similarly, the early voice draft uses the minimum authenticated upload/verification workflow, and simulator alerts use durable scoped event records. Full implementations replace these narrow slices without weakening safety invariants.

## 12. MVP demonstration and release gates

**In simple words:** Demonstrate one fictional patient journey from registration to secure referral. Show both successful actions and intentional failures. Check every item before calling the prototype ready.

### 12.1 Demo sequence (all data fictional)

1. Log in as Super Admin, approve and provision fictional hospital, invite/verify Hospital Admin, configure organization/staff and activate. Demonstrate rejected unauthorized cross-tenant request and a synthetic user suspension/restore. Log in as reception, register provisional patient, obtain clinician admission approval, assign bed and print/scan wristband. Show patient portal signup remains unlinked until identity review.
2. Doctor creates one synthetic medication order after fixture interaction review; nurse A scans product and reserves exact dose.
3. Nurse B attempts same dose concurrently and receives 409 + red safety lock; nurse A starts and records simulated outcome. Show audit and DB state.
4. Run synthetic telemetry scenario; show quality label, live graph and warning/escalation; demonstrate missing NEWS2 inputs correctly rather than generating an incomplete total.
5. Record a short voice note, edit draft and confirm; show deterministic handoff snapshot if available, with AI draft clearly marked.
6. Upload prebuilt structured digital lab fixture; if review complete, show verified timeline. Single Vision-LLM extraction in MVP is labeled draft-only.
7. Generate secure referral QR; wrong recipient denied, authorized receiving clinician sees only granted sections; ask one known and one missing question; click source citation.
8. Release a signed synthetic summary to the linked patient portal, demonstrate an unverified user denied and patient correction request. Revoke referral/caregiver grant and show immediate denial of subsequent access. Disconnect simulated device/API and show stale/lock-unavailable indicators.

Use synthetic scenario controls (no real medication/injection or patient-connected hardware). Prepare fallback data, local demo and screen recording; never represent prerecorded/mocked behavior as live measured performance.

### 12.2 Definition of done

- [ ] Clean checkout + documented setup + synthetic seed successfully executed.
- [ ] Every implemented endpoint in OpenAPI; generated clients and contract tests pass; versioned error codes stable.
- [ ] Database migration, race tests, outbox and idempotency tested on real PostgreSQL.
- [ ] No cross-tenant/encounter leaks; role and consent boundaries tested.
- [ ] Super Admin bootstrap, application review, provisioning, setup/activation, restrictions, archive and restore tested with no clinical access.
- [ ] Global ban and local membership suspension both invalidate relevant sessions, workers and sockets; open clinical tasks preserved and reconciled.
- [ ] Reception admission authorization, staff credential reviews, ward task boundaries, bed occupancy/readiness and last admin protection tested.
- [ ] Patient portal account vs record identity, verified link, released versions, correction and caregiver expiry tested; no login requirement for clinical intake.
- [ ] No offline medication authorization; uncertain outcome cannot auto-reissue.
- [ ] Device identity, assignment, stale/quality status and missing NEWS2 parameters handled.
- [ ] Alerts durable; ack distinct from resolution; escalation failures visible.
- [ ] OCR/voice/SBAR drafts reviewed; verified sources traceable.
- [ ] Referral QR expiry, recipient authentication, revocation and citation scope enforced.
- [ ] Research modules visibly labeled, inputs validated, unsupported predictions abstain.
- [ ] Secrets/redacted logs checked; fake data only; backup restore demonstrated.
- [ ] Benchmark results include method, sample count, p50/p95/p99, limitations, not invented results.
- [ ] Architecture, DFD, ER diagram, screenshots and reference list supplied for report; unsupported features disclosed.

## 13. Traceability and open decisions

**In simple words:** This section shows which original requirements are covered by each module and what still needs a team decision. It prevents the team from assuming an unbuilt feature is complete.

| Source requirement | Modules | Evidence |
| --- | --- | --- |
| New platform requirements (user-requested extension) | M02A, M03A, M04A | Onboarding approval, platform moderation, role separation, patient portal and release tests |
| FR1 dual-ID and vault | M04, M14, M18 | Local provisional registration, scoped consent, synthetic lookup, FHIR validation |
| FR2 IoT / scan / voice | M05–M10, M16 | Concurrency, replay, stale data, voice review tests |
| FR3 digital + dual OCR + verification | M15 | Gold fields, review audit, discrepancy screenshots |
| FR4 QR + grounded chatbot | M17–M18 | Authorization, citation and revocation tests |
| FR5 deterioration / interaction | M08, M11–M12 | Approved rules, missingness, escalation and research evaluation |
| FR6 specialized modules | M19 | Per-task model card, dataset/license, evaluation, OOD tests |
| FR7 pre-surgical/trajectory | M19 | Evidence-backed flags, abstention, review |
| Handoff, NFRs, research revision guide | M07, M13, M20 and all cross-cutting tests | Signed snapshot, latency tables, security, failure injection, reproducible report |

**Unresolved / owner approval required before implementation:** exact current repository state; chosen single API runtime; package/SDK versions and deployment provider; actual schema and API naming; clinical rule sources/approval and timing windows; credentialed reviewer availability; national identifier authorization; model datasets, access and licenses; target clinical populations and intended uses; data retention, privacy and institutional governance; budget and hardware availability; actual latency/accuracy measurements. The supplied documents do not establish these facts, so none are assumed implemented or approved.

**Reference links for implementation verification (not a claim of current regulatory review):** [PostgreSQL explicit locking](https://www.postgresql.org/docs/current/explicit-locking.html), [NEWS2 — Royal College of Physicians](https://www.rcp.ac.uk/resources/national-early-warning-score-news-2/), [HL7 FHIR](https://hl7.org/fhir/), [ABDM](https://abdm.gov.in/), [CDSCO](https://cdsco.gov.in/), [Expo documentation](https://docs.expo.dev/), [PhysioNet](https://physionet.org/). The research revision guide also requests an IEEE reference list and the team's previously published article; exact article title/DOI is not provided and must be confirmed before citation.

---

### 13.1 Suggested source-code folders for the new modules

```text
apps/api/src/modules/
  platform/{applications,hospitals,users,moderation,settings,audit}/
  auth/{bootstrap,sessions,mfa,recovery,authorization}/
  organization/{departments,wards,beds,staff,invitations,credentials}/
  reception/{queue,admission-decisions}/
  ward/{tasks,readiness}/
  patient-portal/{accounts,links,releases,corrections,caregiver-grants}/
apps/web/src/features/
  platform-admin/ hospital-admin/ reception/ ward/ patient-portal/ caregiver/
packages/contracts/src/
  platform.ts organization.ts identity.ts reception.ts patient-portal.ts
```

Implementation sequence within every folder: DB migration and constraints → Zod schemas → authorization policy → repository with tenant filters → transactional service → controller/route → OpenAPI → API tests → frontend pages → end-to-end test. Each new endpoint is a proposed contract; generate formal schema and validate against the actual repository before implementation.

**End of proposed implementation plan (zero-to-hero v2 edition).** Use as the backlog and API design baseline; validate against actual repository and generate machine-readable contracts during M01. No module is marked complete without implementation and test evidence.
