# MediShield AI

**A research prototype for clinical safety, bedside monitoring, and continuity of care**

MediShield AI explores how clinics can carry verified patient information across medication rounds, shift changes, and inter-facility referrals. It brings together a proposed ward app, clinician dashboard, bedside telemetry, and referral portal. The project supports final-year engineering, hackathon demonstrations, and academic research.

[Project status](#project-status) · [Quick start](#quick-start) · [Clinical workflows](#clinical-workflows) · [Architecture](#architecture) · [Team](#team) · [Documentation](#documentation)

## Project status

| Status | Scope |
| --- | --- |
| **Runnable** | An Expo Router starter in [`apps/mobile`](apps/mobile), built with React Native and TypeScript. The root pnpm workspace provides scripts for web, Android, and iOS. |
| **Scaffolded** | Feature directories for mobile, web, and the API, plus directories for workers, inference, device integration, contracts, data, tests, and infrastructure. A `.gitkeep` preserves a directory reserved for implementation. |
| **Planned** | Patient intake, medication verification, bedside alerts, handoffs, report and voice intake, and a clinician referral portal. |
| **Research targets** | Clinical performance, model quality, workflow reliability, and response times will be measured against documented protocols. The [benchmark targets](todo.md#prd-benchmark-targets) are goals for evaluation. |

The Expo web export and both starter routes have been verified. See the [verification baseline](setup.md#verification-baseline) for the exact checks and the current TypeScript result.

> [!IMPORTANT]
> Use the starter and demonstrations with fictional patients and synthetic data. The project is for research and development. Clinical deployment requires separate validation and review.

## Quick start

Use **Node.js 24.3 or newer in the 24.x line** and **pnpm 11.13.0**. Clone the project or start in your existing checkout.

```sh
git clone https://github.com/abhishek-nexgen-dev/MediShield-AI.git
cd MediShield-AI
pnpm install --frozen-lockfile
pnpm web
```

Open the local URL printed by Expo. Check that the home screen displays **Welcome to Expo**, then select **Explore**. The starter runs without an environment file, database, cloud account, or device credentials.

Use `pnpm android` for a configured Android target or `pnpm ios` for an iOS simulator on macOS. See [Local development setup](setup.md) for prerequisites, the web export command, and the known TypeScript issue.

## Clinical workflows

### Intended users

| User | Proposed workflow |
| --- | --- |
| **Ward staff** | Find or register patients, open encounters, print wristbands, and prepare reports for verification. |
| **Nurses** | Verify scheduled medications at the bedside, acknowledge alerts, capture notes, and review handoffs. |
| **Treating clinicians** | Review the patient timeline, monitor ward alerts, and assess verified results and research advisories. |
| **Receiving clinicians** | Redeem a scoped referral, review the authorized timeline, and find evidence in the shared record. |

### Planned end-to-end demo

1. **Open an encounter.** Ward staff find a fictional patient using a mock Aadhaar or ABHA alias and generate a wristband QR linked to the internal patient ID.
2. **Verify and confirm a dose.** A nurse scans the wristband and medication. The API checks the patient, product, active order, and scheduled dose. A second scan of an administered dose shows the prior confirmation and blocks a duplicate entry.
3. **Monitor the ward.** A simulator or prototype sensor sends a scripted change in vitals. The ward view distinguishes fresh readings from stale data and shows the alert, acknowledgment, and escalation status.
4. **Review records and hand off.** Staff verify source reports and review Hindi, Hinglish, or English voice drafts. An incoming nurse acknowledges a briefing with the last recorded dose, pending tasks, and unresolved alerts.
5. **Refer with evidence.** A receiving clinician signs in and redeems an expiring QR grant. Retrieval-augmented generation (RAG) answers questions from verified, authorized records with timestamped citations. For evidence gaps, it returns “Not recorded in patient file.”

## Architecture

| Layer | Prototype direction | Production design target |
| --- | --- | --- |
| Clients | Expo ward app and a separate browser dashboard and referral portal. The browser framework is open. | Feature modules with versioned API and event contracts. |
| Clinical state | FastAPI and Supabase PostgreSQL with scoped Realtime updates. | PostgreSQL for clinical state, private storage for documents, background workers for asynchronous jobs, and Redis for job queues. |
| Telemetry | A repeatable Python simulator and optional ESP32 bedside node. | Authenticated MQTT over TLS and TimescaleDB, with checks for device assignment, message duplication, and reading freshness. |
| Inference | Candidate tools include Gemini Vision/Text and Whisper or IndicWhisper for reviewable drafts. | Task-specific OCR, speech, and inference services. RAG uses pgvector and checks each citation against the authorized source set. |
| Record exchange | Internal patient identifiers and mock lookup aliases for the demo. | Versioned HL7 FHIR mappings, with real identity and exchange workflows subject to review. |

### Decision-support safeguards

- Enforce organization, role, and patient or encounter scope in the API, document storage, realtime subscriptions, referral grants, and retrieval.
- Store medication state in PostgreSQL. Use transactional reservations and idempotent confirmation to protect against concurrent scans and response retries.
- Require staff review of extracted fields, transcript drafts, and handoffs. Keep orders, dose confirmations, and access grants in authenticated application workflows.
- Track alert delivery, acknowledgment, and escalation separately. Calculate NEWS2 only when the required observations are present.

The [architecture guide](folder-structure.md#planned-data-flow) shows service boundaries and data paths. The [security guide](security.md) defines the planned safeguards and their verification scenarios.

### Core records and terms

| Record or term | Meaning in MediShield AI |
| --- | --- |
| **Patient and encounter** | A patient has an internal ID. An encounter is a specific visit or admission and scopes orders, observations, documents, and handoff notes. |
| **Medication order, dose, and administration** | An order describes the prescribed treatment. A dose is one scheduled occurrence. An administration records confirmation of that occurrence, with staff identity and time. |
| **Observation and alert** | An observation carries a value, source, and timestamp. An alert tracks who received and acknowledged a warning. NEWS2 refers to the National Early Warning Score 2. |
| **Source, draft, and verification** | A source is the original document or recording. Parsed or transcribed fields remain drafts until staff verify them against the source. Verified records can then be mapped to HL7 Fast Healthcare Interoperability Resources (FHIR) profiles. |
| **Referral grant** | A time-limited permission for a named recipient to access a defined part of the patient record. A wristband QR identifies a record within an authorized workflow. |

## Delivery and research

| Milestone | Deliverable |
| --- | --- |
| **Prototype demo** | Connect synthetic intake, dose confirmation, telemetry alerts, reviewed notes, handoff, and scoped referral in a repeatable demonstration. |
| **Academic submission** | Evaluate document extraction, multilingual voice capture, handoff completeness, and citation accuracy. Compare baseline models for deterioration and selected imaging and cardiac tasks. |
| **Production readiness review** | Add integration and recovery tests. Validate data handling and authorization, run restore drills, and obtain the appropriate institutional, clinical, privacy, and regulatory reviews before a real-data pilot. |

Additional research topics include drug and food interactions, pre-surgical risk, and longitudinal trends. Record the dataset, split, baseline, and measured results with each evaluation. See the [delivery backlog](todo.md) for acceptance checks and the benchmark plan.

## Team

| Team member | Role | Focus |
| --- | --- | --- |
| **Abhishek Gupta** | Full-Stack & Systems Architecture Lead | Web and mobile architecture, backend APIs, database safety, integration, and infrastructure. |
| **Akanksha Keshri** | AI/ML & Research Lead | Clinical retrieval, report extraction, speech, model evaluation, and research methodology. |
| **Aman Dangi** | IoT & Integration Lead | ESP32 firmware, sensors, MQTT, telemetry, and device integration. |

## Repository map

| Path | Purpose |
| --- | --- |
| [`apps/mobile/src/app`](apps/mobile/src/app) | Runnable Expo route entry points and navigation. |
| [`apps/mobile/src/features`](apps/mobile/src/features) | Mobile feature scaffold for intake, medication, monitoring, handoff, voice, and reports. |
| [`apps/web/src/features`](apps/web/src/features) | Browser feature scaffold for the patient timeline, ward view, report review, referrals, and risk review. |
| [`services/api/src/medishield_api/features`](services/api/src/medishield_api/features) | API feature scaffold for identity, patients, medication, monitoring, records, referrals, and audit. |
| [`packages/contracts`](packages/contracts), [`data/migrations`](data/migrations), [`devices/simulator`](devices/simulator) | Reserved directories for interface schemas, database changes, and repeatable telemetry scenarios. |
| [`tests`](tests), [`research`](research), [`infra`](infra) | Reserved directories for cross-service verification, evaluation protocols, and deployment configuration. |

The [full directory tree](folder-structure.md#production-target) includes the worker, inference, firmware, and operations directories.

## Documentation

Use these references when contributing code, preparing a demo, or giving an AI assistant repository context.

| Question | Source |
| --- | --- |
| What currently runs, and where do I run it? | [Setup](setup.md), [workspace manifest](package.json), and [mobile manifest](apps/mobile/package.json). |
| Where should a feature or service live? | [Architecture and folder structure](folder-structure.md). |
| What should we build next, and how will we check it? | [Delivery backlog](todo.md). |
| How should we handle access, sensitive data, and vulnerability reports? | [Security and clinical data handling](security.md). |

The *Autonomous Clinical Safety, IoT Monitoring & Patient Continuity Platform* PRD defines product requirements and evaluation goals. *MediShield AI Prototyping Tech Stack & Use Cases* informs the demo design. The *MediShield AI Research Report Revision Guide* identifies the evidence needed for academic submission.

## Contributing

Choose a workflow from the [backlog](todo.md) and keep changes scoped to its feature and shared contracts. Include reproducible verification and use synthetic examples in fixtures, screenshots, logs, and pull requests. Report vulnerabilities privately through the [disclosure guidance](security.md#reporting-a-vulnerability).

See the repository's [MIT license notice](LICENSE).
