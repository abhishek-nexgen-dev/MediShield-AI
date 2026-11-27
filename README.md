<div align="center">

# MediShield AI

### Clinical Safety · Intelligent Monitoring · Patient Continuity

**A human-supervised clinical safety and decision-support research platform**

![TypeScript](https://img.shields.io/badge/TypeScript-3178C6?logo=typescript&logoColor=white)
![React Native](https://img.shields.io/badge/React_Native-20232A?logo=react&logoColor=61DAFB)
![Node.js](https://img.shields.io/badge/Node.js-339933?logo=nodedotjs&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-009688?logo=fastapi&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?logo=postgresql&logoColor=white)
![ESP32](https://img.shields.io/badge/ESP32-E7352C?logo=espressif&logoColor=white)
![Status](https://img.shields.io/badge/Status-Research_Prototype-orange)

*Safer workflows. Connected care. Accountable intelligence.*

[Overview](#1-overview) · [Architecture](#4-system-architecture) · [Workflows](#5-core-clinical-workflows) · [Setup](#10-getting-started) · [Roadmap](#14-development-roadmap) · [Team](#16-core-team)

</div>

> [!IMPORTANT]
> MediShield AI is a final-year engineering project, hackathon prototype and research platform. It is not a certified medical device, autonomous diagnostic system or substitute for licensed clinical professionals. Use synthetic data and simulated clinical workflows only. The architecture below describes intended capabilities; implementation, performance and clinical effectiveness have not been independently verified.

## Table of Contents

1. [Overview](#1-overview)
2. [Problem Statement](#2-problem-statement)
3. [Core Features](#3-core-features)
4. [System Architecture](#4-system-architecture)
5. [Core Clinical Workflows](#5-core-clinical-workflows)
6. [Mobile Application](#6-mobile-application)
7. [Technology Stack](#7-technology-stack)
8. [Repository Structure](#8-repository-structure)
9. [Data Model and API](#9-data-model-and-api)
10. [Getting Started](#10-getting-started)
11. [Security and Privacy](#11-security-and-privacy)
12. [Testing and Research Evaluation](#12-testing-and-research-evaluation)
13. [Deployment and Reliability](#13-deployment-and-reliability)
14. [Development Roadmap](#14-development-roadmap)
15. [Limitations and Compliance](#15-limitations-and-compliance)
16. [Core Team](#16-core-team)
17. [Documentation and References](#17-documentation-and-references)
18. [Contributing and License](#18-contributing-and-license)

## 1. Overview

MediShield AI connects nursing workflows, hospital operations, bedside IoT monitoring and longitudinal patient records through a unified clinical safety architecture. Its primary objective is to reduce opportunities for preventable errors, improve information continuity and make clinical decisions more traceable.

Unlike autonomous diagnostic agents, MediShield AI separates deterministic safety controls from probabilistic AI assistance. Transactional database rules govern medication state; AI provides draft summaries, document extraction and evidence-grounded retrieval. Authorized clinicians retain responsibility for clinical decisions.

**Intended users:** nurses, doctors, hospital administrators, authorized referral recipients and research engineers. Patients are represented through consent-governed longitudinal records.

## 2. Problem Statement

| Clinical failure vector | Proposed intervention |
| --- | --- |
| Duplicate or missed doses | Patient and medication scanning, transactional dose reservation, overdue task tracking |
| Delayed recognition of deterioration | Quality-aware telemetry, validated NEWS2 rules and escalation tracking |
| Incomplete shift handoffs | Structured SBAR snapshots and clinician-reviewed summaries |
| Fragmented records | Longitudinal patient vault with encounter-level provenance |
| Manual lab transcription errors | OCR, structured extraction and human discrepancy review |
| Information loss during referral | Expiring referral authorization and citation-backed record retrieval |

## 3. Core Features

| Module | Intended functionality |
| --- | --- |
| Medication safety | Barcode verification, dose-event state machine, eMAR-style history and conflict detection |
| Bedside monitoring | Live vitals, signal quality, device status, trend visualization and stale-data indicators |
| Early warning | Deterministic NEWS2 calculation from complete eligible observations and configurable escalation |
| Nursing handoff | SBAR: Situation, Background, Assessment, Recommendation; explicit sign-off |
| Patient continuity | Encounter timeline, allergies, medication history, documents and consent controls |
| Clinical RAG | Access-scoped document retrieval, citations and explicit abstention |
| Intelligent lab intake | OCR, schema validation, discrepancy highlighting and approval |
| Voice logging | Hindi, English and Hinglish transcription with editable draft notes |
| Referral exchange | Scoped QR tokens, recipient authentication, expiry and revocation |
| Hospital command portal | Ward overview, patient and device management, alert acknowledgment and audit review |

## 4. System Architecture

```mermaid
flowchart TD
    N[Nurse mobile app] --> API[Node.js / Express API]
    W[Doctor and admin portal] --> API
    API --> PG[(PostgreSQL)]
    API --> Q[Redis / BullMQ]
    API --> OBJ[(Private document storage)]
    Q --> WK[Background worker]
    WK --> AI[Python / FastAPI AI service]
    AI --> V[(pgvector)]
    AI --> OBJ
    ESP[ESP32 prototype sensors] --> MQTT[MQTT broker]
    MQTT --> WK
    WK --> TS[(TimescaleDB)]
    WK --> RULES[Deterministic risk rules]
    RULES --> PG
    API --> RT[Authenticated realtime gateway]
    RT --> N
    RT --> W
```

The API is the authority for identity, authorization and clinical state. Workers handle asynchronous ingestion and retryable jobs. Redis supports queues and caching, never authoritative dose ownership. PostgreSQL, TimescaleDB and pgvector may initially coexist in one compatible database deployment. AI services cannot directly commit medication administrations or independently create clinical orders.

## 5. Core Clinical Workflows

### 5.1 Scan-to-Administer Dual Lock

The dual lock combines patient/medication identity verification with exclusive server-side reservation of a specific scheduled dose event.

```mermaid
sequenceDiagram
    participant A as Nurse A
    participant S as Safety API
    participant D as PostgreSQL
    participant B as Nurse B
    A->>S: Scan patient and medication, reserve dose
    S->>D: BEGIN; SELECT dose FOR UPDATE
    D-->>S: SCHEDULED
    S->>D: Save reservation; COMMIT
    S-->>A: Reservation token and expiry
    B->>S: Reserve same dose
    S->>D: Lock and inspect dose
    S-->>B: 409 Conflict
    A->>S: Confirm start of administration
    S->>D: Transition to IN_PROGRESS
    A->>S: Record administration outcome
    S->>D: Transition to ADMINISTERED or review state
```

Server checks include authenticated staff permissions, active admission, patient and drug identity, order status, scheduled dose, route, allergy flags, reservation owner and idempotency key. Clinical checks and independent bedside verification remain necessary; scanning cannot prove a drug was physically administered correctly.

```mermaid
stateDiagram-v2
    [*] --> SCHEDULED
    SCHEDULED --> RESERVED
    RESERVED --> SCHEDULED: verified unused release
    RESERVED --> IN_PROGRESS: server authorizes start
    RESERVED --> REVIEW_REQUIRED: uncertain expiry or outcome
    IN_PROGRESS --> ADMINISTERED: confirmed outcome
    IN_PROGRESS --> REVIEW_REQUIRED: lost connection or uncertain outcome
    SCHEDULED --> CANCELLED: authorized cancellation
    REVIEW_REQUIRED --> ADMINISTERED: authorized reconciliation
    REVIEW_REQUIRED --> SCHEDULED: verified not administered
```

**Concurrency and failure handling:** keep row locks within short database transactions; persist reservation ownership separately after commit. A proposed 120-second reservation timeout is configurable and requires workflow validation. Never automatically reissue a dose if physical administration may have occurred. Repeated requests with the same idempotency key return the recorded outcome; reuse with a different payload is rejected. A unique dose-event constraint provides an additional safeguard. Record all state changes and reconciliation decisions in the audit trail.

If the authoritative API is unavailable, display `ELECTRONIC SAFETY LOCK UNAVAILABLE` and defer to the hospital-approved downtime protocol. Reconcile downtime records before resuming electronic administration.

### 5.2 IoT Telemetry and Early Warning

```mermaid
flowchart LR
    A[Prototype sensors] --> B[ESP32 sampling]
    B --> C[MQTT over TLS]
    C --> D[Device identity and schema validation]
    D --> E[Quality and freshness checks]
    E --> F[(Time-series storage)]
    F --> G[NEWS2 rule engine]
    G --> H[Alert and acknowledgment]
    H --> I[Clinician review]
```

| Hardware | Research purpose | Limitation |
| --- | --- | --- |
| ESP32 | Edge sampling and MQTT publishing | Requires authenticated provisioning and reliable connectivity |
| MAX30102 | Optical pulse and experimental SpO2 estimation | Not a validated clinical oximeter |
| AD8232 | Experimental single-lead ECG signal acquisition | Not diagnostic ECG; use bench/simulated signals |
| DS18B20 | Temperature sensing | Not validated for clinical body temperature |
| HX711 + load cell | Weight or fluid-container monitoring experiments | Does not directly measure a NEWS2 parameter |

Use simulated signals or appropriate test equipment; do not attach unvalidated electrical prototypes to patients. Each observation carries device ID, patient/admission binding, timestamp, unit, sequence number, quality and provenance. Reject invalid measurements, deduplicate replayed messages and show stale or missing data explicitly.

NEWS2 requires respiratory rate, oxygen saturation, systolic blood pressure, pulse rate, consciousness/new confusion, temperature and supplemental oxygen status. The proposed sensors alone do not supply all inputs. Missing parameters require verified manual or validated-device observations. Never treat missing values as normal or issue a complete score from incomplete inputs. Apply the correct oxygen scale only under authorized clinical guidance and restrict the scoring engine to its validated population.

Alert lifecycle: `OPEN → ACKNOWLEDGED → ESCALATED / RESOLVED`. Escalation follows approved policy; missing acknowledgments are tracked independently of push delivery.

### 5.3 Shift Handoff

Collect encounter history, open tasks, recent observations and unresolved alerts → create a deterministic SBAR snapshot → generate an optional AI draft → outgoing nurse verifies and signs → incoming nurse acknowledges. Preserve snapshot version, author, timestamp and subsequent amendments. AI recommendations must be clearly marked as drafts.

### 5.4 Clinical RAG and Patient Continuity

```mermaid
flowchart TD
    A[Authorized clinical question] --> B[Identity, consent and encounter scope]
    B --> C[Hybrid keyword and vector retrieval]
    C --> D[Relevant permitted evidence]
    D --> E[LLM draft with citations]
    E --> F[Evidence and output validation]
    F --> G[Clinician review or abstention]
```

Index approved record chunks with encounter IDs, document versions and access metadata. Enforce authorization during retrieval, not merely in the prompt. Return source document/page references and timestamps, distinguish documented facts from inference, and abstain when evidence is inadequate. Treat uploaded document instructions as untrusted data. No autonomous prescriptions, diagnoses or clinical writes.

### 5.5 Lab Document and Voice Intake

Lab pipeline: private upload → OCR (PaddleOCR) → vision-model structured extraction → compare fields and flag discrepancies → human review → publish verified record. Preserve source image, units, reference ranges and reviewer provenance; never silently infer missing values.

Voice pipeline: authorized recording → speech transcription (Whisper) → editable Hindi/English/Hinglish clinical note → staff review → signed record. Apply retention controls to recordings and prevent unapproved external processing of patient information.

### 5.6 Secure Referral

Generate a signed, short-lived opaque referral token with scope, audience, expiry and unique ID. Encode no clinical information in the QR itself. Require recipient authentication and current consent validation before retrieval. Enforce revocation and replay controls on the server; record access events. Provide only the minimum necessary referral context.

## 6. Mobile Application

The React Native/Expo application is designed around bedside ergonomics, clear status indicators and offline observation capture.

```mermaid
flowchart TD
    P[Presentation: screens and clinical components] --> A[Application: hooks and use cases]
    A --> D[Domain: types and safety state models]
    A --> I[Data: API client and SQLite repository]
    I --> S[Authoritative server]
```

| Dependency | Purpose |
| --- | --- |
| `expo`, `react-native`, `typescript` | Mobile runtime and typed development |
| `expo-camera` | QR and medication barcode scanning |
| `expo-sqlite` | Offline observation queue; optional SQLCipher configuration |
| `expo-secure-store` | Protected credential storage |
| `expo-audio` | Clinical voice recording |
| `expo-crypto` | Cryptographically secure request identifiers |
| `@react-navigation/native`, `@react-navigation/bottom-tabs` | Navigation |
| `@tanstack/react-query`, `zustand` | Server cache and local UI state |
| `react-native-reanimated`, `lucide-react-native` | Accessible visual feedback and iconography |

Use a supported Expo SDK compatible with the repository lockfile. Barcode scanning is consolidated into `expo-camera`; `expo-audio` replaces the legacy audio API for new development. SQLite is not encrypted by default: SQLCipher requires explicit native configuration and a development build. Expo Go is useful for compatible UI-only demonstrations.

Offline capture is limited to permitted notes and observations. Store client-generated event IDs, timestamps and sync status; validate all queued data on the server. Never grant medication reservations offline. Show whether vitals are live, stale, simulated or manually entered.

## 7. Technology Stack

| Layer | Proposed technologies |
| --- | --- |
| Web portal | Next.js or React/Vite (choose one for the implementation), TypeScript, Tailwind CSS |
| Mobile | React Native, Expo, TypeScript |
| Core API | Node.js, Express, Zod, Prisma |
| AI/ML | Python, FastAPI, PaddleOCR, Whisper, configurable vision/LLM provider |
| Retrieval | PostgreSQL full-text search, pgvector, optional LangChain/LangGraph orchestration |
| Persistence | PostgreSQL, TimescaleDB, private object storage |
| Async processing | Redis, BullMQ |
| IoT | ESP32, C++/Arduino, MQTT, Eclipse Mosquitto |
| Realtime | Authenticated WebSocket gateway |
| Infrastructure | Docker Compose, reverse proxy, TLS, CI checks |
| Testing | Jest, Supertest, pytest, mobile and browser end-to-end tests |

## 8. Repository Structure

Proposed monorepo layout (paths must be reconciled with the actual repository):

```text
medishield-ai/
├── README.md
├── implementation_plan.md
├── design.md
├── agent.md
├── .env.example
├── compose.yaml
├── package.json
├── mobile/
│   ├── app.json
│   ├── package.json
│   ├── tsconfig.json
│   └── src/
│       ├── api/                 # API client and endpoints
│       ├── components/          # DoseCard, SBAR, vitals, scanner
│       ├── hooks/               # Reservations, sync, telemetry, voice
│       ├── navigation/          # Typed routes
│       ├── screens/             # Medications, patients, vitals, handoff
│       ├── services/            # Offline DB, scan parsing, sync
│       └── types/               # Clinical domain models
├── apps/
│   ├── web/                     # Doctor and admin portal
│   ├── api/                     # Authoritative REST API
│   └── worker/                  # Queues and MQTT ingestion
├── packages/
│   └── contracts/               # Zod schemas and TS contracts
├── services/
│   └── ai-service/
│       ├── rag/
│       ├── ocr/
│       ├── speech/
│       └── tests/
├── firmware/
│   └── esp32/
├── database/
│   ├── prisma/
│   └── migrations/
└── tests/                       # Integration and concurrency scenarios
```

Generate JSON Schema/OpenAPI contracts for Python consumers; TypeScript types alone do not enforce cross-language compatibility.

## 9. Data Model and API

### Principal entities

| Entity | Responsibility |
| --- | --- |
| Hospital, Ward, Bed | Tenant and care-location hierarchy |
| User, Role, Assignment | Staff permissions and clinical scope |
| Patient, Encounter, Consent | Identity, longitudinal history and authorization |
| MedicationOrder, DoseEvent | Prescribed order and individual scheduled dose |
| Administration, AuditEvent | Verified outcome and traceable state transitions |
| Device, Observation, Alert | Telemetry provenance, quality and escalation |
| Handoff, ClinicalDocument | Signed snapshots and verified source records |
| Referral, AccessGrant | Time-limited cross-organization authorization |

### Proposed REST endpoints (`/api/v1`)

| Method | Endpoint | Function |
| --- | --- | --- |
| GET | `/patients/:id/encounters` | Authorized encounter timeline |
| GET | `/admissions/:id/dose-events` | Scheduled medication events |
| POST | `/medication-administrations/reserve` | Atomic dose reservation |
| POST | `/medication-administrations/start` | Authorize administration start |
| POST | `/medication-administrations/confirm` | Record confirmed outcome |
| POST | `/dose-events/:id/reconcile` | Authorized uncertain-outcome review |
| POST | `/observations` | Submit verified/manual observations |
| GET | `/admissions/:id/vitals` | Authorized telemetry history |
| POST | `/alerts/:id/acknowledge` | Record alert acknowledgment |
| POST | `/handoffs` | Create SBAR snapshot |
| POST | `/documents` | Submit document for processing |
| POST | `/clinical-rag/query` | Retrieve grounded clinical context |
| POST | `/referrals` | Create scoped referral |
| POST | `/referrals/redeem` | Authenticate and redeem referral token |

Example reservation request (illustrative synthetic IDs):

```json
{
  "admissionId": "adm_demo_001",
  "medicationOrderId": "ord_demo_001",
  "doseEventId": "dose_demo_001",
  "patientScan": "patient_demo_001",
  "medicationScan": "drug_demo_001",
  "idempotencyKey": "550e8400-e29b-41d4-a716-446655440000"
}
```

Use authenticated identity from server-validated credentials, not client-supplied nurse IDs. Return `409 Conflict` for incompatible dose state, `403 Forbidden` for unauthorized access and `422 Unprocessable Content` for invalid clinical input. Do not expose sensitive details in error messages.

## 10. Getting Started

> Setup commands are an intended local-development contract based on the supplied architecture. Repository URL, service names, scripts, migrations and dependencies have not been inspected or executed.

### Prerequisites

- A supported Node.js LTS release compatible with the project lockfile, npm or pnpm (use one consistently).
- Python version supported by the AI dependencies, Docker and Docker Compose.
- Android Studio or Xcode for native builds; physical device optional.
- ESP32 hardware or a synthetic MQTT telemetry simulator.

### 1. Clone and install

```bash
git clone https://github.com/nexgen-dev/medishield-ai.git
cd medishield-ai
npm ci
cp .env.example .env
```

Use `npm install` if the project has no npm lockfile yet. Keep backend secrets separate from public mobile configuration.

### 2. Configure local environment

Root/backend `.env` (development only):

```dotenv
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/medishield
REDIS_URL=redis://localhost:6379
MQTT_URL=mqtt://localhost:1883
GEMINI_API_KEY=your_development_key
AI_SERVICE_URL=http://localhost:8000
```

Mobile `.env` (public values only):

```dotenv
EXPO_PUBLIC_API_URL=http://192.168.1.100:4000/api/v1
```

Replace the example LAN IP with your development machine's address. Never put API keys or credentials in `EXPO_PUBLIC_*`. Use TLS, broker authentication and managed secrets outside isolated local testing. Mobile clients should receive authorized telemetry via the API gateway rather than broad direct MQTT access.

### 3. Start infrastructure

```bash
docker compose up -d postgres redis mqtt
```

Ensure the PostgreSQL image supports TimescaleDB and pgvector; enable extensions through migrations. Run the repository's database migration and synthetic seed scripts before starting application services.

### 4. Start applications

```bash
# From root: if the workspace dev script is configured
npm run dev

# Mobile: in a separate terminal
cd mobile
npx expo start
```

Expected development endpoints: web `localhost:3000`, API `localhost:4000/api/v1`, AI service `localhost:8000`. Start the AI service and worker using their repository-specific scripts if not managed by the root command. Use an Expo development build for native modules such as SQLCipher; use `npx expo-doctor` to check SDK compatibility.

## 11. Security and Privacy

- Tenant isolation, role-based and encounter-scoped authorization, least privilege and staff session expiry.
- TLS in transit, encryption at rest, protected local storage and managed secret rotation.
- Authenticated devices, restricted MQTT topics, replay protection and explicit device-to-patient assignment.
- Append-only or tamper-evident audit events for clinical changes, record access and reconciliation.
- Consent purpose, expiry, revocation, retention and deletion workflows; avoid PHI in logs, analytics and model prompts.
- Private document access with short-lived signed URLs, upload validation and malware scanning.
- Rate limits, input validation, dependency scanning, backup recovery tests and incident response.
- Human approval for AI-generated clinical material; model output cannot bypass authorization or safety invariants.

## 12. Testing and Research Evaluation

| Test | Acceptance criterion or proposed metric |
| --- | --- |
| Concurrent reservation | Exactly one successful reservation per eligible dose event in controlled tests |
| Network failure | No automatic repeat administration when outcome is uncertain |
| Idempotency | Identical retry returns existing result; mismatched payload rejected |
| Offline sync | No duplicate observation records after replay |
| NEWS2 rules | Match approved reference test cases; incomplete data never presented as complete |
| Telemetry | Measure ingestion latency, packet loss, invalid data and stale detection |
| OCR | Field-level accuracy, unit errors and reviewer correction rate |
| RAG | Retrieval recall, citation correctness, unsupported claim and abstention rates |
| Authorization | No cross-tenant or out-of-scope access in adversarial tests |
| Usability | Simulated task completion time, scan failures and handoff completeness |

Research hypothesis: deterministic verification and structured continuity workflows may reduce simulated duplicate-dose opportunities and information omissions compared with an unassisted baseline. Use predefined scenarios, report sample sizes and failure cases, and distinguish simulation outcomes from clinical outcomes. The original sub-300 ms medication verification latency is an engineering target, not a measured result; evaluate p50/p95/p99 under specified load and network conditions.

## 13. Deployment and Reliability

For the prototype, use Docker Compose and synthetic data. A future production-like environment would separate API, workers, AI services, database, broker and storage with service identities, restricted networking and monitored backups. Use readiness checks, queue retry limits, dead-letter handling, structured redacted logs, metrics and tracing. Evaluate recovery time and recovery point objectives through restore drills. A broker, worker or AI outage must not silently suppress critical status indicators or weaken transactional controls.

## 14. Development Roadmap

Indicative 24-week plan; all modules are proposed, not asserted complete.

| Weeks | Modules | Deliverables |
| --- | --- | --- |
| 1–4 | M01–M04 | Requirements, threat model, monorepo, identity and patient/admission foundations |
| 5–8 | M05–M08 | Medication orders, dose state machine, scanning, concurrency and downtime reconciliation |
| 9–12 | M09–M12 | ESP32 simulator, MQTT ingestion, telemetry storage, NEWS2 and alerts |
| 13–16 | M13–M16 | SBAR, patient vault, OCR review and multilingual voice notes |
| 17–20 | M17–M18 | Clinical RAG and secure referral exchange |
| 21–24 | M19–M20 | Integrated portal, security/testing, research evaluation and demonstration |

Prioritize deterministic medication safety and synthetic telemetry before adding AI features. Phase completion requires tests and reviewed evidence rather than calendar dates alone.

## 15. Limitations and Compliance

MediShield AI is not approved for live clinical use. Low-cost sensors are research components, AI may hallucinate, barcode identity checks do not replace bedside checks, and infrastructure failures may delay notifications. No claim of eliminating medical errors or improving patient outcomes is made without validation.

For future Indian deployments, assess applicability of the **Medical Devices Rules, 2017**, CDSCO requirements, the **Digital Personal Data Protection Act, 2023**, and the **Digital Personal Data Protection Rules, 2025**, including phased commencement. Consider ABDM/HL7 FHIR interoperability and relevant clinical risk-management and software lifecycle standards where applicable. Obtain appropriate institutional, ethics, clinical, legal and regulatory review before using real patient data or conducting clinical studies. Human review alone does not establish regulatory compliance.

## 16. Core Team

| Team member | Role | Responsibilities |
| --- | --- | --- |
| **Abhishek Gupta** | Full-Stack & Systems Architecture Lead | Web/mobile architecture, backend APIs, database safety, integration and infrastructure |
| **Akanksha Keshri** | AI/ML & Research Lead | Clinical RAG, OCR, speech, model evaluation and research methodology |
| **Aman Dangi** | IoT & Integration Lead | ESP32 firmware, sensors, MQTT, telemetry and device integration |

## 17. Documentation and References

| Project document | Intended content |
| --- | --- |
| [Implementation Plan](implementation_plan.md) | Module-level milestones and acceptance criteria |
| [System Design](design.md) | Data model, API contracts, architecture and failure handling |
| [AI Agent Architecture](agent.md) | Retrieval, OCR, speech, guardrails and model evaluation |

External technical references:

- [Royal College of Physicians — NEWS2](https://www.rcp.ac.uk/resources/national-early-warning-score-news-2/)
- [Expo Camera](https://docs.expo.dev/versions/latest/sdk/camera/), [Expo SQLite](https://docs.expo.dev/versions/latest/sdk/sqlite/), [Expo Audio](https://docs.expo.dev/versions/latest/sdk/audio/)
- [PostgreSQL explicit locking](https://www.postgresql.org/docs/current/explicit-locking.html)
- [pgvector](https://github.com/pgvector/pgvector), [TimescaleDB](https://docs.timescale.com/), [MQTT](https://mqtt.org/)
- [HL7 FHIR](https://hl7.org/fhir/), [ABDM](https://abdm.gov.in/)
- [MeitY — Acts and Policies](https://www.meity.gov.in/documents/act-and-policies), [CDSCO](https://cdsco.gov.in/)

## 18. Contributing and License

Contributions should use synthetic fixtures, narrowly scoped pull requests, documented safety implications and relevant tests. Never include real patient records, credentials or unredacted clinical screenshots in issues or commits. Report security vulnerabilities privately to the maintainers through an agreed disclosure channel.

**License:** Not specified. A software license must be selected by the project owners and added as a `LICENSE` file before claiming open-source licensing or granting redistribution rights.

---

<div align="center">

**MediShield AI**

*Engineering safer clinical workflows through deterministic safeguards, connected monitoring and human-supervised intelligence.*

Final-Year Engineering Project · Hackathon Prototype · Research Platform

</div>
