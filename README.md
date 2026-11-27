<div align="center">

# MediShield AI

### Clinical Safety · Intelligent Monitoring · Connected Care

**A multi-hospital clinical safety, IoT monitoring and patient continuity research platform.**

[![TypeScript](https://img.shields.io/badge/TypeScript-3178C6?logo=typescript&logoColor=white)](https://www.typescriptlang.org/)
[![Next.js](https://img.shields.io/badge/Next.js-000000?logo=nextdotjs&logoColor=white)](https://nextjs.org/)
[![React Native](https://img.shields.io/badge/React_Native-20232A?logo=react&logoColor=61DAFB)](https://reactnative.dev/)
[![Node.js](https://img.shields.io/badge/Node.js-339933?logo=nodedotjs&logoColor=white)](https://nodejs.org/)
[![FastAPI](https://img.shields.io/badge/FastAPI-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![ESP32](https://img.shields.io/badge/ESP32-E7352C?logo=espressif&logoColor=white)](https://www.espressif.com/)
![Status](https://img.shields.io/badge/Status-Planned_Research_Prototype-orange)

*Safer workflows. Connected records. Human-supervised intelligence.*

[Overview](#overview) · [Features](#core-features) · [Architecture](#system-architecture) · [Setup](#getting-started) · [Roadmap](#development-roadmap) · [Team](#core-team)

</div>

> [!IMPORTANT]
> **Academic and research prototype only.** MediShield AI is not a certified medical device or a substitute for a qualified clinician. Use fictional patient data, simulated clinical actions and bench-only hardware. Do not connect experimental sensors to people. All features, performance targets and architecture described here are planned unless verified by implementation and test evidence.

## Table of Contents

- [Overview](#overview)
- [Problem Statement](#problem-statement)
- [Core Features](#core-features)
- [User Roles and Permissions](#user-roles-and-permissions)
- [Complete Platform Workflow](#complete-platform-workflow)
- [System Architecture](#system-architecture)
- [Clinical Safety Workflows](#clinical-safety-workflows)
- [AI and Research](#ai-and-research)
- [Technology Stack](#technology-stack)
- [Repository Structure](#repository-structure)
- [Database and API Overview](#database-and-api-overview)
- [Getting Started](#getting-started)
- [Security and Privacy](#security-and-privacy)
- [Testing and Research Evaluation](#testing-and-research-evaluation)
- [Development Roadmap](#development-roadmap)
- [Demo and Deployment](#demo-and-deployment)
- [Documentation](#documentation)
- [Core Team](#core-team)
- [Contributing and License](#contributing-and-license)

## Overview

MediShield AI brings hospital operations, bedside nursing, patient records and AI-assisted clinical workflows into one connected platform. It is designed as a final-year engineering project, hackathon prototype and research platform for studying preventable care errors and continuity of care.

The system begins with hospital onboarding by a Super Admin. Each hospital has a separate workspace, its own staff, wards, beds and authorized patient records. Reception registers patients, doctors create treatment orders, nurses use medication safety workflows, and patients can optionally access released records through a secure portal.

The central design principle is simple: **the backend enforces safety rules; AI assists humans but does not make clinical decisions.**

## Problem Statement

| Problem | Proposed solution |
| --- | --- |
| Disconnected hospital operations | Separate hospital workspaces with staff, department, ward and bed management |
| Duplicate or missed medication doses | Patient and medicine scanning, database-backed dose locks and overdue-task review |
| Delayed recognition of deterioration | Live quality-aware IoT telemetry, early-warning scoring and alert escalation |
| Incomplete nursing handoffs | Structured SBAR summaries and explicit transfer of outstanding tasks |
| Slow report entry | Digital parsing, OCR, AI extraction and human verification |
| Fragmented medical history | Longitudinal patient records with encounter-level sources |
| Information loss during referral | Expiring QR referral authorization and a citation-backed patient-history chatbot |
| Limited patient access to records | Optional verified patient accounts, released documents and controlled sharing |

## Core Features

| Workspace / module | Planned capabilities |
| --- | --- |
| Super Admin | Hospital application review, approval, activation, restrictions, restoration, user bans, session revocation and platform audit |
| Hospital Admin | Hospital profile, departments, wards, beds, staff invitations, credential review, local access suspension and device management |
| Reception | Patient lookup, walk-in registration, queue, admission coordination and QR wristbands |
| Ward Staff | Assigned operational tasks, bed readiness, equipment and transport coordination |
| Doctor | Assigned-patient dashboard, prescriptions, report review, alert review, discharge and referrals |
| Nurse | Medication schedule, patient and medicine scanner, dose reservation, observations, vitals, voice notes and handoff |
| Laboratory | Private report upload, digital extraction, OCR comparison, human verification and amendments |
| Patient Portal | Verified account linking, released reports, admission history, correction requests, sharing and caregiver access |
| IoT Monitoring | Device provisioning, assignment, telemetry, freshness checks and simulated warning scenarios |
| AI and Continuity | Grounded RAG, multilingual voice drafts, SBAR drafts, secure referrals and experimental research models |

## User Roles and Permissions

| Role | Main responsibility | Important restriction |
| --- | --- | --- |
| `PLATFORM_ADMIN` (Super Admin) | Manage hospitals and platform accounts | No default access to clinical records |
| `HOSPITAL_ADMIN` | Manage one hospital's operations and memberships | Cannot prescribe or edit clinical records by default |
| `RECEPTIONIST` | Patient identity and intake coordination | No clinical admission approval or prescribing |
| `WARD_STAFF` | Assigned ward tasks and bed readiness | No medication administration by default |
| `DOCTOR` | Assigned patient care, orders and clinical review | Cannot access unrelated patients or hospitals |
| `NURSE` | Assigned medication and observation workflows | Cannot create or modify prescriptions |
| `LAB_TECH` | Authorized report processing and verification | Cannot prescribe or issue referrals |
| `PATIENT` | Own verified, released medical records | Cannot edit signed clinical records |
| `CAREGIVER` | Specifically granted patient records | Access ends when grant expires or is revoked |
| `REFERRAL_DOCTOR` | Authorized referral records and RAG queries | No unrestricted hospital search or source-record writes |
| `RESEARCHER` | Approved research datasets and experiments | No default access to live clinical data |
| Device / service | Restricted telemetry or background tasks | No general human login or broad record access |

A role is only one part of authorization. The server also checks account status, hospital status, membership, assignment, consent and record-specific access. Hospital Admins may suspend local memberships; platform-wide bans belong to Super Admins. Neither action deletes medical history or silently abandons active clinical tasks.

## Complete Platform Workflow

```mermaid
flowchart TD
    A[Super Admin bootstrap] --> B[Hospital application and review]
    B --> C[Approve and provision hospital]
    C --> D[Invite and verify Hospital Admin]
    D --> E[Departments, wards, beds and staff setup]
    E --> F[Activate hospital]
    F --> G[Reception registers patient]
    G --> H[Clinician approves admission]
    H --> I[Assign bed and issue QR wristband]
    G --> P[Optional verified patient portal link]
    I --> J[Doctor creates medication orders]
    J --> K[Nurse scans and records simulated care]
    I --> L[IoT monitoring and alerts]
    I --> M[Reports, notes and handoffs]
    K --> N[Reviewed discharge summary]
    L --> N
    M --> N
    N --> O[Secure referral and scoped RAG]
    N --> Q[Release approved records to patient]
    P --> Q
```

### Hospital onboarding

1. Super Admin creates or reviews a hospital application and private verification documents.
2. The application is approved, rejected or returned for changes.
3. Approval provisions a separate hospital workspace and allows the first Hospital Admin invitation.
4. The administrator accepts the invitation and passes required verification.
5. The administrator configures departments, wards, beds and staff memberships.
6. Super Admin activates the hospital after reviewing setup readiness.
7. Restrictions, suspension, restoration and archiving follow audited workflows with continuity and retention checks.

### Patient journey

Reception creates a local patient identity and medical record number (MRN). The clinician approves admission, the bed is assigned, and a QR wristband connects the patient to the current admission. Doctors, nurses and lab staff work only within their authorized scope. At discharge, the doctor reviews and signs a summary, which may be released to the patient or shared through an authorized referral.

A patient record, an admission and a portal account are different objects. A patient does not need an account, smartphone, Aadhaar or ABHA number to receive care. The prototype uses fictional identifiers; real national identity integration requires separate authorization.

## System Architecture

```mermaid
flowchart TD
    WEB[Next.js hospital and patient portals] --> API[Express REST API and authorization]
    MOB[React Native nurse application] --> API
    API --> PG[(PostgreSQL clinical and platform records)]
    API --> OBJ[(Private object storage)]
    PG --> OUT[Transactional outbox]
    OUT --> REDIS[Redis and BullMQ]
    REDIS --> WORK[Background worker]
    ESP[ESP32 or Python simulator] --> MQTT[MQTT broker]
    MQTT --> WORK
    WORK --> TS[(TimescaleDB or partitioned telemetry)]
    WORK --> RULE[Deterministic rules and alerts]
    RULE --> PG
    WORK --> AI[Private FastAPI AI service]
    AI --> OBJ
    AI --> VEC[(Scoped pgvector retrieval)]
    WORK --> RT[Authorized Socket.IO gateway]
    RT --> WEB
    RT --> MOB
```

The Express API is the authoritative writer for clinical state. PostgreSQL transactions enforce medication and bed-allocation constraints. Redis supports queues and caching, not authoritative dose approval. The Python service provides AI results and drafts; it does not directly approve treatment or overwrite verified records.

### Application interfaces

| Application | Planned screens |
| --- | --- |
| Platform web | Dashboard, hospital applications, hospitals, users, settings and audit |
| Hospital web | Setup, departments, wards, beds, staff, invitations, devices and audit |
| Reception and ward web | Walk-in queue, registration, admission coordination and assigned ward tasks |
| Clinical web | Assigned patients, orders, reports, vitals, alerts and discharge |
| Nurse mobile | Ward home, scanner, medication schedule, patient details, vitals, voice logger, handoff and offline sync |
| Patient web | Sign-up, identity link, dashboard, released records, sharing and corrections |
| Referral web | Recipient verification, permitted timeline and source-cited questions |

## Clinical Safety Workflows

### 1. Scan-to-Administer dual lock

The first lock checks that the patient and medicine scans match the prescribed dose. The second lock ensures that competing requests cannot reserve the same dose at the same time.

```mermaid
sequenceDiagram
    participant A as Nurse A
    participant B as Nurse B
    participant API as Clinical API
    participant DB as PostgreSQL
    A->>API: Scan and reserve dose
    API->>DB: Transaction and row lock
    DB-->>API: Reservation committed
    API-->>A: 200 RESERVED
    B->>API: Reserve same dose
    API->>DB: Check locked dose state
    DB-->>API: Already reserved
    API-->>B: 409 Conflict
    A->>API: Start with valid reservation
    A->>API: Confirm simulated outcome
    API->>DB: Record outcome and audit
```

Reservation, start and confirmation are separate steps. An expired or uncertain administration must not automatically become available for another physical attempt. It requires reconciliation when the outcome is unclear. No medication approval is allowed offline; the app shows **Electronic safety lock unavailable** and points staff to an approved downtime procedure.

### 2. IoT telemetry and alerts

```mermaid
flowchart LR
    A[ESP32 or simulator] --> B[Authenticated MQTT]
    B --> C[Validate identity, units and quality]
    C --> D[Store time-series readings]
    D --> E[Check freshness and scoring inputs]
    E --> F[Durable alert and escalation]
    F --> G[Authorized clinical dashboard]
```

| Prototype hardware | Intended demonstration |
| --- | --- |
| ESP32 | Device controller and MQTT communication |
| MAX30102 | Experimental heart rate and oxygen saturation signals |
| AD8232 | Experimental single-lead ECG signal capture |
| DS18B20 | Temperature sensor demonstration |
| HX711 and load cell | IV-container weight/status demonstration |
| Python simulator | Repeatable normal, warning, stale and missing-data scenarios |

All sensor hardware is for bench testing only. Measurements carry source, timestamp, unit and quality indicators. NEWS2 requires the correct clinical inputs, including manual observations that these sensors cannot supply. Missing or stale inputs must not be presented as a complete score. Alert acknowledgement is not the same as clinical resolution.

### 3. Report ingestion and verification

Digital reports are parsed first where supported. Scanned paper is processed by OCR and a vision-language model. Fields, units and discrepancies are shown beside the original document. An authorized reviewer verifies the result before it becomes a released record. Extraction agreement does not prove correctness; unsupported formats and ambiguous values require review.

### 4. Voice logging and shift handoff

Hindi, Hinglish and English audio is transcribed into an editable draft. Staff verify the patient, time and content before saving. The shift handoff uses SBAR (Situation, Background, Assessment, Recommendation), combining verified tasks, medication states, observations and unresolved alerts. AI-generated wording is reviewed before signing. Incoming staff acknowledge the handoff and review changes made since the snapshot.

### 5. Longitudinal records and secure referrals

Each admission contributes to a patient's authorized timeline. Signed summaries and verified reports retain source and version information. Referral QR codes contain opaque, expiring tokens rather than medical details. The receiving clinician must authenticate and have a current grant. Access may be revoked, and source citations must remain within that same grant.

## AI and Research

| AI module | Proposed approach | Output |
| --- | --- | --- |
| Clinical RAG | Hybrid retrieval with PostgreSQL/pgvector and an LLM | Evidence-backed answers with source citations or abstention |
| Medical OCR | Digital parsing, PaddleOCR and vision model | Reviewable structured report draft |
| Voice | Whisper / IndicWhisper and structured extraction | Editable multilingual note |
| Handoff | Deterministic SBAR snapshot and optional LLM | Human-reviewed summary |
| Interaction guard | Reviewed rules with optional clinical NLP assistance | Evidence-backed medicine, food and allergy review flags |
| Deterioration research | NEWS2 baseline and experimental XGBoost or time-series models | Research warning score, not autonomous treatment |
| Specialized research | PyTorch/Hugging Face models and appropriate explainability tools | Experimental findings subject to validation |

### Specialized research tracks

Brain hemorrhage CT, cardiac/ECG analysis, breast imaging, fatty-liver-related research, pre-surgical advisory and longitudinal risk trends are advanced research tracks, not production diagnostic features. Start with one or two clearly defined tasks and evaluate them properly. Potential datasets include MIMIC-IV, PhysioNet, RSNA intracranial hemorrhage data, PTB-XL, MIT-BIH and CBIS-DDSM. ILPD is a liver-disease dataset and is not by itself a validated fatty-liver grading dataset. Dataset access, labels, intended use and licenses must be checked before training.

### RAG workflow

```mermaid
flowchart LR
    A[Authorized question] --> B[Check patient and grant scope]
    B --> C[Retrieve verified records]
    C --> D[Generate grounded draft]
    D --> E[Validate citations and scope]
    E --> F[Answer or abstain]
```

AI cannot write clinical orders, prescribe medication or approve medication administration. If evidence is missing, the chatbot should say that the information is not recorded rather than invent an answer.

## Technology Stack

| Layer | Reference technology |
| --- | --- |
| Web | Next.js, TypeScript, Tailwind CSS, Lucide |
| Mobile | React Native, Expo, React Navigation, expo-camera, expo-audio |
| Client state | TanStack Query, Zustand, protected credential storage, limited SQLite queue |
| Main backend | Node.js LTS, Express, Zod, Prisma and parameterized SQL |
| AI service | Python, FastAPI, Pydantic, PyTorch, Hugging Face, configurable Gemini adapter |
| AI tools | PaddleOCR, Whisper/IndicWhisper, XGBoost, SHAP, optional LangChain |
| Database | PostgreSQL, pgvector, TimescaleDB or partitioned telemetry tables |
| Background processing | Redis, BullMQ, transactional outbox |
| Real-time | Socket.IO, MQTT, Mosquitto |
| Device firmware | ESP32, C++ / PlatformIO |
| File storage | Private S3-compatible storage, MinIO for local development |
| Infrastructure | Docker Compose, CI, TLS, monitoring |
| Tests | Backend unit/integration tests, pytest, browser/mobile E2E and load tests |

For the MVP, one modular API and worker are enough. FastAPI-only, managed PostgreSQL/Supabase and a PWA are documented alternatives, not additional competing clinical backends.

## Repository Structure

```text
medishield-ai/
├── README.md
├── implementation_plan_v2.md
├── design.md                     # Planned deeper system design
├── agent.md                      # Planned AI architecture notes
├── package.json
├── pnpm-workspace.yaml
├── docker-compose.yml
├── .env.example
├── apps/
│   ├── web/                     # All role-based web portals
│   ├── api/                     # Authoritative Express API
│   └── worker/                  # MQTT, queues and outbox
├── mobile/                      # Expo nurse application
│   └── src/
│       ├── features/
│       ├── api/
│       ├── navigation/
│       ├── services/
│       └── components/
├── packages/
│   ├── contracts/               # Zod schemas, events and errors
│   ├── clinical-rules/          # Reviewed deterministic rule modules
│   └── test-fixtures/           # Synthetic shared test data
├── services/
│   └── ai-service/              # Private FastAPI AI service
│       ├── src/                 # RAG, OCR, speech, models, evaluation
│       └── tests/
├── firmware/
│   └── esp32/                   # Sensor firmware
├── database/
│   ├── prisma/
│   ├── migrations/
│   └── seeds/
├── infra/                       # Docker, MQTT and monitoring
├── scripts/                     # Simulator, benchmarks and restore
└── docs/                        # OpenAPI, decisions, runbooks, research
```

This is the intended structure, not an inventory of existing source files.

## Database and API Overview

| Entity group | Purpose |
| --- | --- |
| Users, sessions, memberships, roles | Identity and scoped access |
| Hospital applications, hospitals, invitations | Onboarding and lifecycle |
| Departments, wards, beds, ward tasks | Hospital operations |
| Patients, admissions, wristbands, consents | Patient identity and clinical encounters |
| Portal links, releases, caregiver grants | Patient-facing record access |
| Medication orders, dose events, administrations | Prescriptions and recorded dose outcomes |
| Devices, observations, alerts | Telemetry and warning lifecycle |
| Handoffs, reports, notes, discharge summaries | Verified clinical history |
| Referrals, access grants, audit events | Scoped sharing and accountability |

All proposed public REST endpoints use `/api/v1`. The full [V2 implementation plan](implementation_plan_v2.md) contains the detailed request/response contracts, authorization and error cases.

| Method | Example endpoint (relative to `/api/v1`) | Purpose |
| --- | --- | --- |
| POST | `/auth/login` | Authenticate user |
| POST | `/platform/hospital-applications` | Create hospital application |
| POST | `/platform/hospital-applications/{applicationId}/review` | Review application |
| POST | `/platform/hospitals/{hospitalId}/activate` | Activate hospital |
| POST | `/platform/users/{userId}/moderation` | Platform account restriction or ban |
| GET | `/hospital-admin/dashboard` | Hospital operations dashboard |
| POST | `/departments` | Create department |
| POST | `/reception/queue` | Add walk-in visit |
| GET | `/ward/tasks` | Read assigned ward tasks |
| POST | `/patients` | Register patient record |
| POST | `/admissions` | Create authorized admission |
| POST | `/patient-portal/accounts` | Create optional portal account |
| GET | `/patient-portal/links/{linkId}/records` | View released records |
| POST | `/admissions/{admissionId}/medication-orders` | Create prescription order |
| POST | `/medication-administrations/reserve` | Reserve exact dose |
| POST | `/medication-administrations/start` | Start authorized workflow |
| POST | `/medication-administrations/confirm` | Record confirmed outcome |
| GET | `/admissions/{admissionId}/vitals/latest` | Read latest authorized vitals |
| POST | `/alerts/{alertId}/acknowledge` | Acknowledge alert |
| POST | `/admissions/{admissionId}/reports` | Submit report processing request |
| POST | `/admissions/{admissionId}/voice-jobs` | Create voice draft job |
| POST | `/admissions/{admissionId}/rag/queries` | Query verified history |
| POST | `/referral-access/redeem` | Redeem authorized referral |

### Example medication reservation

```http
POST /api/v1/medication-administrations/reserve
Authorization: Bearer <access_token>
Idempotency-Key: <uuid>
Content-Type: application/json
```

```json
{
  "admissionId": "enc_01",
  "medicationOrderId": "ord_01",
  "doseEventId": "dose_01",
  "patientScan": "ms:wristband:<opaque-token>",
  "medicationScan": "DEMO-VIAL-A"
}
```

Example success (`200 OK`):

```json
{
  "data": {
    "doseEventId": "dose_01",
    "status": "RESERVED",
    "reservationToken": "<opaque-token>",
    "expiresAt": "2026-12-01T10:02:00Z",
    "version": 2
  },
  "meta": { "requestId": "req_01" }
}
```

Competing reservations receive a `409 Conflict`. Invalid scans are rejected; unavailable authoritative safety checks return `503`. Repeating a network request with the same idempotency key must not repeat its effect.

## Getting Started

### Run the public homepage

From the repository root, use Node.js 24.3 or newer in the 24.x line and pnpm 11.13.0.

```sh
pnpm install --frozen-lockfile
pnpm web
```

Open the URL printed by Expo, or launch the Android or iOS app and select **Home**. The MediShield AI homepage introduces the project and shows a synthetic ward dashboard. The Log In, Forgot Password, and Register Hospital pages show the planned workflows and validate sample input locally. The existing Explore screen is available in the native tabs and at `/explore` on web. See [local setup](setup.md) for verification commands.

### Planned full-platform setup

> [!NOTE]
> The commands in this section describe the planned V2 setup and depend on future workspace scripts, Docker services, migrations and configuration files.

### Prerequisites

- Node.js LTS, pnpm, Python and uv
- Git, Docker and Docker Compose
- Android Studio or a compatible Expo development environment; Xcode on macOS for iOS builds
- Optional ESP32 bench setup or the Python simulator

### 1. Install dependencies and configure development

Clone your actual GitHub repository, enter its directory and run:

```bash
corepack enable
pnpm install
cp .env.example .env
```

Example local-only environment values (fake data only):

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
CORS_ALLOWED_ORIGINS=http://localhost:3000
EXPO_PUBLIC_API_URL=http://192.168.1.100:4000/api/v1
```

Replace the LAN address with your development computer's address when testing on a physical device. Provision private signing and identifier keys; configure the AI provider key only on the server if needed. Never put private API keys in Expo public variables.

### 2. Start infrastructure and prepare synthetic data

```bash
docker compose up -d postgres redis mqtt minio
pnpm db:migrate
pnpm db:seed:demo
```

### 3. Start the main application

Run each process in a separate terminal from the root:

```bash
pnpm dev:api
pnpm dev:worker
pnpm dev:web
```

### 4. Start the AI service

```bash
cd services/ai-service
uv sync
uv run uvicorn src.api.main:app --host 127.0.0.1 --port 8000
```

### 5. Start the nurse application

```bash
cd mobile
pnpm exec expo start
```

| Local service | Planned address |
| --- | --- |
| Web | `http://localhost:3000` |
| REST API | `http://localhost:4000/api/v1` |
| Private AI | `http://127.0.0.1:8000` |
| MQTT | Local port `1883`; deployed TLS port `8883` |

Use a compatible development build for native features such as explicitly configured encrypted SQLite. Expo Go is suitable only for compatible features. Local cleartext ports are for isolated development, not real health data.

## Security and Privacy

- Enforce hospital, account, membership, assignment and consent checks on every sensitive request and subscription.
- Protect privileged accounts with MFA, reviewed invitations, session revocation and audit trails.
- Keep clinical writes and moderation actions separate. A ban does not erase patient records.
- Use PostgreSQL transactions, idempotency keys and append-only audit history for safety-sensitive changes.
- Store private reports securely; never expose unrestricted file URLs or raw identifiers in logs or QR codes.
- Scope all patient and caregiver access to verified links, released record versions and active grants.
- Allow only approved observation/note capture offline. Never grant medication reservations offline.
- Use TLS, least-privilege service accounts, private network access, secret management and tested backups.
- Treat AI-generated text and uploaded files as untrusted. Validate, review and retain provenance.

HL7 FHIR, ABDM, India's DPDP framework and applicable medical device requirements are design references. This is not a claim of legal compliance, ABDM integration, clinical validation or regulatory clearance. Real deployments require independent clinical, privacy, institutional and regulatory review.

## Testing and Research Evaluation

| Test area | Required evidence |
| --- | --- |
| Authorization | Cross-hospital access denied; global and local revocation tested |
| Hospital onboarding | Approval, invitations, activation, restriction and restoration |
| Patient portal | Unverified links denied; withdrawn releases and expired grants inaccessible |
| Medication safety | Real PostgreSQL concurrency tests, retry replay, uncertain-outcome handling |
| Telemetry | Duplicate, stale, missing and invalid readings tested |
| Clinical alerts | Acknowledgement, escalation, failure and resolution tracked |
| AI extraction | Field-level accuracy, unit errors and human-review burden |
| RAG | Citation support, abstention and patient-scope leakage tests |
| Research models | Patient-level splits where applicable, precision, recall, F1, AUROC and limitations |
| Reliability | Load tests, backup restoration and network outage simulations |

Report measured latency with sample sizes and percentiles. Treat sub-300 ms reservation checks, sub-2-second alert delivery and sub-3-second voice processing as proposed targets, not achieved results. No performance or clinical accuracy claims should be published without evidence.

## Development Roadmap

The V2 plan defines 23 modules and a proposed 24-week schedule. Each phase requires passing integration and security checks before release. Thin MVP slices of telemetry, RAG, referrals and voice are developed early and completed in later phases.

| Phase | Weeks | Modules / deliverables |
| --- | --- | --- |
| Foundation | 1–4 | M01, M02, M02A, M03, M03A, M04: setup, authentication, hospital onboarding, staff and patient intake |
| Hackathon MVP | 5–8 | M05–M08: prescription, scan lock, reconciliation, interaction fixtures; early simulator, referral, RAG and voice |
| Monitoring | 9–12 | M09–M12: device management, vitals, NEWS2 and alerts |
| Clinical operations | 13–16 | M13–M16 and M04A portal foundation: handoff, patient vault, reports, voice, released records |
| Continuity | 17–20 | M17–M18 and M04A advanced features: RAG, secure referrals, sharing and corrections |
| Research and release | 21–24 | M19–M20: evaluated research models, security, benchmarks, deployment and documentation |

Testing, security and integration are continuous activities, not last-week tasks. The schedule may change based on team capacity and test results.

## Demo and Deployment

For the hackathon, demonstrate a fictional hospital from onboarding to discharge. Include a competing dose reservation rejected by the server, a simulated deterioration alert, a verified report or voice note, a scoped referral and a released patient document. Show what happens when the connection is lost or the grant is revoked. Clearly label mock data and simulated hardware behavior.

The planned deployment uses Docker Compose locally, a web hosting platform for the Next.js frontend, container hosting for the API/worker/AI services, and a private database, broker and file store. Keep AI and infrastructure ports private. Complete authorization tests, monitoring and a backup restore drill before publishing a synthetic-data demo.

## Documentation

| Document | Purpose |
| --- | --- |
| [README.md](README.md) | Project overview and onboarding guide |
| [implementation_plan_v2.md](implementation_plan_v2.md) | Master development specification: modules, APIs, data design, screens, roadmap and tests |
| `design.md` (planned) | Detailed architecture, schemas and sequence diagrams |
| `agent.md` (planned) | AI, RAG, speech and research architecture |
| `docs/openapi/` (planned) | Machine-readable API contracts |
| `docs/runbooks/` (planned) | Operational and incident-response guides |

Place the V2 implementation plan alongside this README in the repository root. The project is based on the original clinical PRD, prototyping technology stack and research revision guide, with the new platform and patient-portal requirements added in V2.

## Core Team

| Team member | Responsibility |
| --- | --- |
| **Abhishek Gupta** | Full-Stack Development & Systems Architecture Lead |
| **Akanksha Keshri** | AI/ML & Research Lead |
| **Aman Dangi** | IoT & Integration Lead |

## Contributing and License

Contributions should follow the module boundaries and V2 contracts. Use feature branches, write tests, request review and document changes to APIs, permissions or clinical state transitions. Never commit secrets, real patient information, restricted datasets or model weights without appropriate rights.

A software license has not been selected. Do not assume this repository is open-source licensed until the maintainers approve and add a license. Clinical rules and research datasets may have separate terms.

---

<div align="center">

**MediShield AI** · Final-Year Engineering Project · Hackathon Prototype · Research Platform

*Building safer clinical workflows, one verified step at a time.*

</div>
