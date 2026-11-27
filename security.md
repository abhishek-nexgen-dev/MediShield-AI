# Security and clinical data handling

[README](README.md) · [Setup](setup.md) · [Architecture](folder-structure.md) · [Backlog](todo.md)

The Expo starter is intended for fictional patients and simulated data. Use synthetic reports, device events, and identity aliases in demos, screenshots, issues, and tests. The controls below apply as the corresponding services are built.

## Reporting a vulnerability

Contact a maintainer privately through an established project channel. Include the affected feature and commit, conditions needed to observe the issue, expected and observed behavior, and the potential impact. Remove patient information, session identifiers, tokens, and credentials from attachments and logs. Coordinate remediation and disclosure with the maintainers.

## Access and identity

| Boundary | Required controls |
| --- | --- |
| Staff | Derive staff identity and organization from authenticated context. Authorize each request by role and patient or encounter assignment. Use least privilege for staff, service identities, and database access. |
| Patient identity | Use a generated internal patient ID. The demo uses mock Aadhaar and ABHA aliases. Require review before merging conflicting identities. Assess permitted verification, storage, and lookup before introducing real identifiers. |
| Referral | Treat the wristband QR as a record reference and the referral QR as a scoped invitation. Referral redemption requires authentication. Use a short-lived, revocable opaque token, store its digest, and bind the grant to the patient, recipient, and permitted resources. Keep tokens out of logs and analytics. |
| Realtime and storage | Enforce the same organization and encounter scope on subscriptions, files, jobs, and retrieval as on API reads. For Supabase, use row-level policies and keep elevated credentials server-side. |
| Devices | Authenticate individual devices, isolate MQTT topics, and verify the device-to-encounter assignment. Rotate or revoke credentials when a device is replaced. |

The PRD proposes hashing Aadhaar values and showing masked last-four digits. For any approved future lookup, the design proposes a secret-keyed digest to limit offline enumeration, with a rotation strategy and restricted key access. Retain displayed digits only where approved and necessary.

## Workflow integrity

- **Dose state.** Use a transactional reservation and a unique administration record per scheduled dose. Validate idempotency keys against the request they belong to. If the outcome is unknown after a network failure, show the unresolved status and recover it from the API. Staff follow an approved downtime process when server validation is unavailable.
- **Telemetry.** Record source and receipt timestamps, device identity, and freshness. Deduplicate repeated events and keep alert delivery, acknowledgment, and escalation visible.
- **Documents and voice.** Limit allowed formats and sizes, isolate parsers, and scope access to raw content. Keep extracted values and transcripts in draft status until an authorized reviewer confirms them. Preserve source evidence and reviewer provenance.
- **AI retrieval.** Apply patient scope before retrieval and validate citations against the authorized source set. Treat documents and transcripts as untrusted input. Keep model access read-scoped and prevent model output from changing orders, dose state, or grants.

## Operations and privacy

Encrypt API and realtime traffic, MQTT connections, stored documents, and backups. Keep credentials out of application bundles and source control. Use isolated credentials per environment and make rotation and revocation part of operational runbooks.

Audit sensitive access, edits, exports, overrides, and dose decisions with actor, action, resource ID, timestamp, result, and correlation ID. Restrict audit access and protect records from tampering. Define retention for documents, audio, embeddings, backups, and logs. Minimize exported data and require approval for any real-data transfer to a model provider.

Before any real-data pilot, obtain the appropriate institutional, clinical, privacy, and regulatory reviews. Confirm which Indian DPDP obligations, ABDM exchange requirements, and HL7 FHIR profiles apply to the proposed deployment.

## Verification

Run these checks with synthetic records before accepting the corresponding feature.

| Scenario | Expected result |
| --- | --- |
| A staff account requests another organization's record, file, or realtime subscription | Access is denied across every path and the event is recorded with redacted metadata. |
| A referral is expired, revoked, or redeemed by the wrong recipient | The portal and its direct API requests deny access to the timeline and related artifacts. |
| Two staff members reserve the same dose or retry confirmation | One reservation owns the dose and at most one administration is recorded. |
| A device publishes outside its assignment or repeats a known message | Unauthorized readings are rejected and repeats do not create new clinical events. |
| An uploaded file contains instructions to expose records or change a dose | Retrieval stays within scope and no clinical state changes. |
| A deployment loses its database or job worker | Readiness and the UI show degraded status. A staging restore recovers records and audit history within the documented recovery targets. |
