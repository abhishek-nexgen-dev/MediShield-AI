# Delivery backlog

[README](README.md) · [Setup](setup.md) · [Architecture](folder-structure.md) · [Security](security.md)

Checked items reflect the current repository. Close each remaining item with a reproducible command, test result, or review artifact.

## Foundation

- [x] Bootstrap Expo Router and TypeScript with Home and Explore routes.
- [x] Move the Expo starter into `apps/mobile`, share the pnpm lockfile at the root, and scaffold feature directories for mobile, web, and the API.
- [x] Verify workspace installation, Home and Explore HTTP responses, web export, and native configuration loading. See the [verification baseline](setup.md#verification-baseline).
- [x] Build the public homepage and resolve the starter web tab ref mismatch.
- [ ] Add CI for frozen installation, type checking, lint, and web export.
- [ ] Choose the browser stack and define initial API contracts, organization and encounter scopes, audit events, database migrations, and seed data.

## Prototype synthetic workflows

Work through these in order so each demo step has the data it needs.

- [ ] **Register a patient and start an encounter.** Seed two organizations with fictional patients and mock identity aliases. Staff can find or create a record and print a wristband QR. Use an explicit review step when identity matches are ambiguous.
- [ ] **Reserve and confirm a scheduled dose.** Require patient and medication matches and an active order. Concurrent scans may reserve the dose once. A retry after a lost response returns the existing result and a replay cannot create a second administration. Cover wrong patient, wrong product, expired reservation, and offline status.
- [ ] **Stream readings and acknowledge an alert.** Run a repeatable Python simulation, then optionally use an ESP32/MAX30102 node. Log a synthetic deterioration event. Verify duplicate messages, stale readings, escalation after timeout, acknowledgment, and visibility of delivery failures.
- [ ] **Capture notes and review reports.** Prepare two or three digital reports and one paper example. Show the source beside uncertain fields. Ask staff to confirm the patient, time, and content of Hindi, Hinglish, and English voice drafts.
- [ ] **Review a handoff.** Generate a briefing that includes the last recorded dose, next scheduled dose, pending tasks, and outstanding alerts. Capture the incoming nurse's acknowledgment.
- [ ] **Redeem a referral and check citations.** Sign in as the intended recipient, open the scoped timeline, and retrieve a cited detail. Verify missing evidence, expired or revoked grants, and denial of cross-patient and cross-organization requests.

## Research and final-year submission

- [ ] Version the selected FHIR mappings and trace each mapped field to verified source evidence.
- [ ] Extend report ingestion to supported digital PDFs, DICOM, and HL7/XML. Compare PaddleOCR and a vision model for paper reports and route discrepancies to human review.
- [ ] Evaluate handoff completeness, extraction accuracy, voice correction effort, retrieval citation accuracy, and abstention using a documented rubric.
- [ ] Evaluate NEWS2 and task-appropriate deterioration or diagnostic baselines using permitted datasets and patient-level splits. Candidate sources include MIMIC-IV/PhysioNet, RSNA intracranial hemorrhage CT, PTB-XL/MIT-BIH, and CBIS-DDSM. Confirm imaging and reference labels for fatty-liver severity, and evaluate ILPD separately for tabular liver prediction.
- [ ] Evaluate interaction rules, pre-surgical advisories, and longitudinal risk as separate tasks. Review the rule sources, output limits, and review workflows with clinical advisors.
- [ ] Record dataset version, cohort, split, baseline, model version, precision, recall, F1, and AUROC where appropriate. Compare models within the same task and data split.
- [ ] Add system and data-flow diagrams, an entity relationship diagram, synthetic screenshots, results tables, and IEEE-style references. Verify publication details for the team's cited article.

### PRD benchmark targets

| Benchmark | Target | Record during evaluation |
| --- | --- | --- |
| Dose validation | < 300 ms | Time from server receipt of scan validation to its response. Report median and p95 under concurrent scans. |
| Telemetry alert | < 2 s | Time from simulated sensor event to visible alert. Include load, network conditions, and delivery failures. |
| Voice draft | < 3 s | Time from finished capture to visible draft. Include audio length and language. |
| Patient lookup | < 1 s | API lookup time with the record count and query scope. |
| Report extraction | > 99.5% | Define correct fields, numerator, denominator, and coverage. Report before and after human review. |

Measure RAG response latency and handoff review time with the same level of detail. Publish measured results and deviations alongside the targets.

## Production review

- [ ] Add isolated service identities and verify access boundaries for API, realtime, storage, jobs, and retrieval using the [security verification table](security.md#verification).
- [ ] Run migration and restore drills. Verify recovery from duplicate or delayed events, broker disconnects, worker outages, and failed alert delivery.
- [ ] Document operational owners, escalation contacts, recovery and retention policies, and deployment gates. Obtain the relevant privacy, clinical, institutional, and regulatory review before a real-data pilot.
