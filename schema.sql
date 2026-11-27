-- MediShield AI | database/schema.sql
-- Proposed baseline for PostgreSQL 15+ (UUID, JSONB, range constraints).
-- Sources: implementation_plan_v2.md §4–7 and M01–M20; latest patient portal UI scope.
-- Run ONCE on an empty development database as a migration owner:
--   psql -X -v ON_ERROR_STOP=1 -d medishield -f schema.sql
-- No DROP, destructive reset, passwords, credentials, real patient data or default admin.
-- This is not an upgrade migration for an existing database or Prisma schema.
-- Use only synthetic data until clinical, privacy and regulatory validation is complete.
-- All timestamps UTC internally (timestamptz), display in hospital timezone.
-- SQL uses snake_case, API uses camelCase. Example IDs in the plan are illustrative; use UUIDs.
-- All writes must go through trusted backend. Do not expose these tables directly to browsers.
-- pgvector optional at installation; RAG embeddings must be enabled before vector retrieval.
-- Telemetry uses native PostgreSQL range partitioning; Timescale is a separate deployment variant.
-- btree_gist extension is required for non-overlapping assignments.
BEGIN;
CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE SCHEMA medishield;
REVOKE ALL ON SCHEMA medishield FROM PUBLIC;
SET LOCAL search_path = medishield, pg_catalog, public;

-- ============================================================================
-- 01 | Accounts, identity, permissions and platform onboarding
-- ============================================================================

CREATE TABLE users (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email text,
    phone_e164 text,
    password_hash text,
    display_name text NOT NULL,
    given_name text,
    family_name text,
    avatar_storage_key text,
    status text NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'ACTIVE', 'SUSPENDED', 'BANNED', 'CLOSED')),
    email_verified_at timestamptz,
    phone_verified_at timestamptz,
    last_login_at timestamptz,
    access_version bigint NOT NULL DEFAULT 1 CHECK (access_version > 0),
    locale text NOT NULL DEFAULT 'en',
    CHECK (email IS NOT NULL OR phone_e164 IS NOT NULL),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0)
);

CREATE UNIQUE INDEX uq_users_email ON users (lower(email)) WHERE email IS NOT NULL;

CREATE UNIQUE INDEX uq_users_phone ON users (phone_e164) WHERE phone_e164 IS NOT NULL;

CREATE TABLE roles (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code text NOT NULL UNIQUE,
    name text NOT NULL,
    scope text NOT NULL CHECK (scope IN ('PLATFORM', 'HOSPITAL', 'PORTAL', 'SERVICE')),
    description text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0)
);

CREATE TABLE permissions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code text NOT NULL UNIQUE,
    description text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0)
);

CREATE TABLE role_permissions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    role_id uuid NOT NULL REFERENCES roles(id),
    permission_id uuid NOT NULL REFERENCES permissions(id),
    UNIQUE (role_id, permission_id),
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE platform_role_assignments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES users(id),
    role_id uuid NOT NULL REFERENCES roles(id),
    granted_by uuid REFERENCES users(id),
    granted_at timestamptz NOT NULL DEFAULT now(),
    revoked_at timestamptz,
    revoked_by uuid REFERENCES users(id),
    reason text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0)
);

CREATE UNIQUE INDEX uq_active_platform_role ON platform_role_assignments (user_id, role_id) WHERE revoked_at IS NULL;

CREATE TABLE platform_settings (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    key text NOT NULL UNIQUE,
    value jsonb NOT NULL DEFAULT '{}'::jsonb,
    description text,
    updated_by uuid REFERENCES users(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0)
);

CREATE TABLE hospital_applications (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    legal_name text NOT NULL,
    display_name text,
    business_reference text,
    normalized_business_reference text,
    registration_authority text,
    contact_name text,
    contact_email text NOT NULL,
    contact_phone text,
    address_line1 text,
    address_line2 text,
    city text NOT NULL,
    state text,
    postal_code text,
    country_code char(2) NOT NULL DEFAULT 'IN',
    timezone text NOT NULL DEFAULT 'Asia/Kolkata',
    status text NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT', 'SUBMITTED', 'UNDER_REVIEW', 'NEEDS_CHANGES', 'APPROVED', 'REJECTED', 'WITHDRAWN', 'PROVISIONED')),
    submitted_at timestamptz,
    decided_at timestamptz,
    created_by uuid NOT NULL REFERENCES users(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0)
);

CREATE UNIQUE INDEX uq_open_hospital_application ON hospital_applications (normalized_business_reference) WHERE normalized_business_reference IS NOT NULL AND status IN ('DRAFT','SUBMITTED','UNDER_REVIEW','NEEDS_CHANGES','APPROVED');

CREATE TABLE hospitals (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id uuid UNIQUE REFERENCES hospital_applications(id),
    code text NOT NULL UNIQUE,
    legal_name text NOT NULL,
    display_name text NOT NULL,
    business_reference text,
    registration_authority text,
    contact_email text,
    contact_phone text,
    website_url text,
    address_line1 text,
    address_line2 text,
    city text,
    state text,
    postal_code text,
    country_code char(2) NOT NULL DEFAULT 'IN',
    timezone text NOT NULL DEFAULT 'Asia/Kolkata',
    status text NOT NULL DEFAULT 'SETUP_PENDING' CHECK (status IN ('SETUP_PENDING', 'ACTIVE', 'RESTRICTED', 'SUSPENDED', 'ARCHIVED')),
    access_version bigint NOT NULL DEFAULT 1 CHECK (access_version > 0),
    activated_at timestamptz,
    archived_at timestamptz,
    created_by uuid REFERENCES users(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0)
);

CREATE TABLE onboarding_documents (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id uuid NOT NULL REFERENCES hospital_applications(id),
    document_type text NOT NULL,
    storage_key text NOT NULL UNIQUE,
    sha256 text NOT NULL CHECK (sha256 ~ '^[a-fA-F0-9]{64}$'),
    mime_type text NOT NULL,
    byte_size bigint NOT NULL CHECK (byte_size > 0),
    scan_status text NOT NULL DEFAULT 'PENDING' CHECK (scan_status IN ('PENDING', 'CLEAN', 'REJECTED')),
    uploaded_by uuid NOT NULL REFERENCES users(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0)
);

CREATE TABLE onboarding_reviews (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id uuid NOT NULL REFERENCES hospital_applications(id),
    reviewer_id uuid NOT NULL REFERENCES users(id),
    decision text NOT NULL CHECK (decision IN ('UNDER_REVIEW', 'NEEDS_CHANGES', 'APPROVED', 'REJECTED')),
    reason text NOT NULL,
    application_version integer NOT NULL CHECK (application_version > 0),
    checklist jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE hospital_status_history (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    previous_status text NOT NULL,
    new_status text NOT NULL,
    reason text NOT NULL,
    actor_id uuid NOT NULL REFERENCES users(id),
    effective_at timestamptz NOT NULL DEFAULT now(),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (hospital_id, id)
);

CREATE TABLE hospital_settings (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    setting_key text NOT NULL,
    value jsonb NOT NULL DEFAULT '{}'::jsonb,
    updated_by uuid REFERENCES users(id),
    UNIQUE (hospital_id, setting_key),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE hospital_setup_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    item_key text NOT NULL,
    status text NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'COMPLETE', 'WAIVED')),
    completed_at timestamptz,
    completed_by uuid REFERENCES users(id),
    reason text,
    UNIQUE (hospital_id, item_key),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE memberships (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    user_id uuid NOT NULL REFERENCES users(id),
    role_id uuid NOT NULL REFERENCES roles(id),
    employee_code text,
    job_title text,
    status text NOT NULL DEFAULT 'INVITED' CHECK (status IN ('INVITED', 'PENDING_VERIFICATION', 'ACTIVE', 'SUSPENDED', 'REVOKED')),
    access_version bigint NOT NULL DEFAULT 1 CHECK (access_version > 0),
    joined_at timestamptz,
    ended_at timestamptz,
    created_by uuid REFERENCES users(id),
    UNIQUE (hospital_id, id, user_id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE UNIQUE INDEX uq_current_membership ON memberships (hospital_id, user_id, role_id) WHERE status <> 'REVOKED';

CREATE TABLE membership_permissions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    membership_id uuid NOT NULL,
    permission_id uuid NOT NULL REFERENCES permissions(id),
    allowed boolean NOT NULL,
    granted_by uuid REFERENCES users(id),
    UNIQUE (membership_id, permission_id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE moderation_actions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    target_user_id uuid REFERENCES users(id),
    target_hospital_id uuid REFERENCES hospitals(id),
    target_membership_id uuid,
    action text NOT NULL,
    previous_status text,
    new_status text NOT NULL,
    reason text NOT NULL,
    actor_id uuid NOT NULL REFERENCES users(id),
    effective_at timestamptz NOT NULL DEFAULT now(),
    expires_at timestamptz,
    CHECK (num_nonnulls(target_user_id, target_hospital_id, target_membership_id) = 1),
    CHECK (expires_at IS NULL OR expires_at > effective_at),
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE invitations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid REFERENCES hospitals(id),
    role_id uuid REFERENCES roles(id),
    recipient_email text,
    recipient_phone text,
    recipient_user_id uuid REFERENCES users(id),
    token_digest bytea NOT NULL UNIQUE,
    purpose text NOT NULL CHECK (purpose IN ('PLATFORM_ADMIN', 'HOSPITAL_ADMIN', 'STAFF', 'PORTAL_LINK', 'CAREGIVER')),
    scope jsonb NOT NULL DEFAULT '{}',
    expires_at timestamptz NOT NULL,
    consumed_at timestamptz,
    revoked_at timestamptz,
    invited_by uuid NOT NULL REFERENCES users(id),
    accepted_by uuid REFERENCES users(id),
    attempt_count integer NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
    CHECK (num_nonnulls(recipient_email, recipient_phone, recipient_user_id) >= 1),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0)
);

CREATE TABLE credential_reviews (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    membership_id uuid NOT NULL,
    credential_type text NOT NULL,
    registration_number_masked text,
    issuer text,
    object_id uuid,
    valid_until date,
    status text NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED', 'EXPIRED')),
    reviewed_by uuid REFERENCES users(id),
    reviewed_at timestamptz,
    reason text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE access_requests (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    membership_id uuid NOT NULL,
    requested_permission_id uuid REFERENCES permissions(id),
    requested_scope jsonb NOT NULL DEFAULT '{}'::jsonb,
    status text NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED', 'REVOKED')),
    reviewed_by uuid REFERENCES users(id),
    reviewed_at timestamptz,
    reason text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE sessions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES users(id),
    hospital_id uuid REFERENCES hospitals(id),
    membership_id uuid,
    context_type text NOT NULL CHECK (context_type IN ('PLATFORM', 'STAFF', 'PATIENT', 'CAREGIVER', 'REFERRAL')),
    refresh_token_digest bytea NOT NULL UNIQUE,
    token_family_id uuid NOT NULL,
    user_access_version bigint NOT NULL,
    hospital_access_version bigint,
    membership_access_version bigint,
    ip_hash bytea,
    user_agent text,
    mfa_verified_at timestamptz,
    last_seen_at timestamptz,
    expires_at timestamptz NOT NULL,
    revoked_at timestamptz,
    revoke_reason text,
    CHECK ((context_type = 'STAFF' AND hospital_id IS NOT NULL AND membership_id IS NOT NULL) OR (context_type <> 'STAFF' AND membership_id IS NULL)),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0)
);

CREATE TABLE auth_challenges (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES users(id),
    purpose text NOT NULL,
    challenge_digest bytea NOT NULL UNIQUE,
    code_digest bytea,
    expires_at timestamptz NOT NULL,
    consumed_at timestamptz,
    attempt_count integer NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
    max_attempts integer NOT NULL DEFAULT 5 CHECK (max_attempts > 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0)
);

CREATE TABLE password_reset_tokens (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES users(id),
    token_digest bytea NOT NULL UNIQUE,
    expires_at timestamptz NOT NULL,
    consumed_at timestamptz,
    revoked_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0)
);

CREATE TABLE mfa_credentials (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES users(id),
    method text NOT NULL CHECK (method IN ('TOTP', 'WEBAUTHN', 'RECOVERY_CODE')),
    encrypted_secret bytea,
    public_credential jsonb,
    secret_key_version integer,
    recovery_code_digest bytea,
    verified_at timestamptz,
    revoked_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0)
);

CREATE TABLE user_preferences (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL UNIQUE REFERENCES users(id),
    theme text NOT NULL DEFAULT 'SYSTEM' CHECK (theme IN ('LIGHT', 'DARK', 'SYSTEM')),
    language text NOT NULL DEFAULT 'en',
    timezone text,
    sidebar_collapsed boolean NOT NULL DEFAULT false,
    notification_preferences jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0)
);

-- ============================================================================
-- 02 | Hospital structure, patients, intake, admissions and bed management
-- ============================================================================

CREATE TABLE departments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    code text NOT NULL,
    name text NOT NULL,
    description text,
    active boolean NOT NULL DEFAULT true,
    UNIQUE (hospital_id, code),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE wards (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    department_id uuid NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    ward_type text,
    floor text,
    active boolean NOT NULL DEFAULT true,
    UNIQUE (hospital_id, code),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE beds (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    ward_id uuid NOT NULL,
    label text NOT NULL,
    bed_type text,
    readiness text NOT NULL DEFAULT 'READY' CHECK (readiness IN ('READY', 'CLEANING', 'MAINTENANCE', 'OUT_OF_SERVICE')),
    active boolean NOT NULL DEFAULT true,
    UNIQUE (hospital_id, ward_id, label),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE staff_profiles (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    membership_id uuid NOT NULL UNIQUE,
    specialization text,
    qualification text,
    registration_number_masked text,
    work_phone text,
    work_email text,
    employment_started_on date,
    employment_ended_on date,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE staff_department_assignments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    membership_id uuid NOT NULL,
    department_id uuid NOT NULL,
    starts_at timestamptz NOT NULL DEFAULT now(),
    ends_at timestamptz,
    CHECK (ends_at IS NULL OR ends_at > starts_at),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE patients (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    given_name text NOT NULL,
    family_name text,
    display_name text,
    date_of_birth date,
    birth_date_estimated boolean NOT NULL DEFAULT false,
    sex_at_birth text,
    gender_identity text,
    blood_group text CHECK (blood_group IN ('A+','A-','B+','B-','AB+','AB-','O+','O-')),
    preferred_language text,
    is_synthetic boolean NOT NULL DEFAULT true,
    status text NOT NULL DEFAULT 'PROVISIONAL' CHECK (status IN ('PROVISIONAL', 'ACTIVE', 'MERGED', 'DECEASED', 'ARCHIVED')),
    merged_into_id uuid REFERENCES patients(id),
    deceased_at timestamptz,
    CHECK (merged_into_id IS NULL OR merged_into_id <> id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0)
);

CREATE TABLE hospital_patient_links (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    patient_id uuid NOT NULL REFERENCES patients(id),
    mrn text NOT NULL,
    local_display_name text,
    phone_e164 text,
    email text,
    address_line1 text,
    address_line2 text,
    city text,
    state text,
    postal_code text,
    country_code char(2),
    identity_verified_at timestamptz,
    identity_status text NOT NULL DEFAULT 'PROVISIONAL' CHECK (identity_status IN ('PROVISIONAL', 'PENDING_REVIEW', 'VERIFIED', 'REJECTED', 'MERGED')),
    verified_by uuid REFERENCES users(id),
    registered_by uuid REFERENCES users(id),
    archived_at timestamptz,
    UNIQUE (hospital_id, mrn),
    UNIQUE (hospital_id, patient_id),
    UNIQUE (hospital_id, id, patient_id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE patient_identifiers (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    patient_link_id uuid NOT NULL,
    identifier_type text NOT NULL CHECK (identifier_type IN ('LOCAL', 'ABHA', 'AADHAAR', 'OTHER')),
    identifier_digest bytea NOT NULL,
    last4 varchar(4),
    key_version integer NOT NULL CHECK (key_version > 0),
    verification_status text NOT NULL DEFAULT 'UNVERIFIED' CHECK (verification_status IN ('UNVERIFIED', 'VERIFIED', 'REVOKED')),
    verified_by uuid REFERENCES users(id),
    verified_at timestamptz,
    revoked_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE UNIQUE INDEX uq_scoped_identifier ON patient_identifiers (hospital_id, identifier_type, key_version, identifier_digest) WHERE revoked_at IS NULL;

CREATE TABLE patient_contacts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    patient_link_id uuid NOT NULL,
    contact_name text NOT NULL,
    relationship text,
    phone_e164 text,
    email text,
    is_emergency_contact boolean NOT NULL DEFAULT false,
    is_authorized_representative boolean NOT NULL DEFAULT false,
    verified_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE identity_match_reviews (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    patient_link_id uuid NOT NULL,
    candidate_patient_link_id uuid NOT NULL,
    status text NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'MATCHED', 'NOT_MATCHED', 'REJECTED')),
    reviewed_by uuid REFERENCES users(id),
    reviewed_at timestamptz,
    reason text,
    CHECK (patient_link_id <> candidate_patient_link_id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE consents (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    patient_link_id uuid NOT NULL,
    recipient_user_id uuid REFERENCES users(id),
    recipient_hospital_id uuid REFERENCES hospitals(id),
    purpose text NOT NULL,
    scope jsonb NOT NULL DEFAULT '{}'::jsonb,
    status text NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'GRANTED', 'DENIED', 'REVOKED', 'EXPIRED')),
    valid_from timestamptz,
    expires_at timestamptz,
    revoked_at timestamptz,
    provenance text,
    recorded_by uuid REFERENCES users(id),
    CHECK (expires_at IS NULL OR valid_from IS NULL OR expires_at > valid_from),
    UNIQUE (hospital_id, id, patient_link_id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE consent_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    consent_id uuid NOT NULL,
    event_type text NOT NULL,
    actor_id uuid REFERENCES users(id),
    reason text,
    scope jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (hospital_id, id)
);

CREATE TABLE reception_queue (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    patient_link_id uuid NOT NULL,
    department_id uuid,
    queue_number text NOT NULL,
    queue_date date NOT NULL,
    status text NOT NULL DEFAULT 'WAITING' CHECK (status IN ('WAITING', 'IN_REVIEW', 'APPROVED', 'REJECTED', 'ADMITTED', 'COMPLETED', 'CANCELLED')),
    arrival_at timestamptz NOT NULL DEFAULT now(),
    reason text,
    priority_label text,
    created_by uuid REFERENCES users(id),
    assigned_membership_id uuid,
    UNIQUE (hospital_id, queue_date, queue_number),
    UNIQUE (hospital_id, id, patient_link_id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE admission_decisions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    queue_id uuid NOT NULL,
    patient_link_id uuid NOT NULL,
    doctor_membership_id uuid NOT NULL,
    decision text NOT NULL CHECK (decision IN ('APPROVED', 'REJECTED')),
    reason text,
    decided_at timestamptz NOT NULL DEFAULT now(),
    consumed_at timestamptz,
    UNIQUE (hospital_id, id, patient_link_id),
    UNIQUE (hospital_id, id, queue_id, patient_link_id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE admissions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    patient_link_id uuid NOT NULL,
    encounter_number text NOT NULL,
    queue_id uuid,
    decision_id uuid UNIQUE,
    attending_doctor_id uuid,
    department_id uuid,
    encounter_type text NOT NULL DEFAULT 'INPATIENT' CHECK (encounter_type IN ('INPATIENT', 'OUTPATIENT', 'EMERGENCY', 'FOLLOW_UP')),
    status text NOT NULL DEFAULT 'PLANNED' CHECK (status IN ('PLANNED', 'ACTIVE', 'DISCHARGE_PENDING', 'DISCHARGED', 'CANCELLED')),
    admitted_at timestamptz,
    discharged_at timestamptz,
    reason text,
    diagnosis_summary text,
    created_by uuid REFERENCES users(id),
    CHECK (discharged_at IS NULL OR (admitted_at IS NOT NULL AND discharged_at >= admitted_at)),
    CHECK ((queue_id IS NULL) = (decision_id IS NULL)),
    UNIQUE (hospital_id, encounter_number),
    UNIQUE (hospital_id, id, patient_link_id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE bed_assignments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    admission_id uuid NOT NULL,
    bed_id uuid NOT NULL,
    started_at timestamptz NOT NULL DEFAULT now(),
    ended_at timestamptz,
    assigned_by uuid NOT NULL REFERENCES users(id),
    end_reason text,
    CHECK (ended_at IS NULL OR ended_at > started_at),
    EXCLUDE USING gist (hospital_id WITH =, bed_id WITH =, tstzrange(started_at, ended_at, '[)') WITH &&),
    EXCLUDE USING gist (hospital_id WITH =, admission_id WITH =, tstzrange(started_at, ended_at, '[)') WITH &&),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE UNIQUE INDEX uq_active_bed ON bed_assignments (hospital_id, bed_id) WHERE ended_at IS NULL;

CREATE UNIQUE INDEX uq_active_encounter_bed ON bed_assignments (hospital_id, admission_id) WHERE ended_at IS NULL;

CREATE TABLE care_assignments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    membership_id uuid NOT NULL,
    ward_id uuid,
    admission_id uuid,
    starts_at timestamptz NOT NULL DEFAULT now(),
    ends_at timestamptz,
    assigned_by uuid REFERENCES users(id),
    CHECK (num_nonnulls(ward_id, admission_id) = 1),
    CHECK (ends_at IS NULL OR ends_at > starts_at),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE ward_tasks (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    ward_id uuid NOT NULL,
    admission_id uuid,
    bed_id uuid,
    assignee_membership_id uuid,
    title text NOT NULL,
    description text,
    task_type text NOT NULL,
    status text NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'ASSIGNED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED')),
    due_at timestamptz,
    completed_at timestamptz,
    created_by uuid REFERENCES users(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE wristbands (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    admission_id uuid NOT NULL,
    token_digest bytea NOT NULL UNIQUE,
    issued_at timestamptz NOT NULL DEFAULT now(),
    expires_at timestamptz NOT NULL,
    revoked_at timestamptz,
    issued_by uuid NOT NULL REFERENCES users(id),
    revoke_reason text,
    CHECK (expires_at > issued_at),
    UNIQUE (hospital_id, id, admission_id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE UNIQUE INDEX uq_current_wristband ON wristbands (hospital_id, admission_id) WHERE revoked_at IS NULL;

CREATE TABLE allergies (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    patient_link_id uuid NOT NULL,
    substance_code text,
    code_system text,
    substance_name text,
    reaction text,
    severity text,
    assertion text NOT NULL DEFAULT 'UNKNOWN' CHECK (assertion IN ('PRESENT', 'NO_KNOWN', 'UNKNOWN')),
    verification_status text NOT NULL DEFAULT 'UNVERIFIED' CHECK (verification_status IN ('UNVERIFIED', 'VERIFIED', 'ENTERED_IN_ERROR')),
    source text,
    recorded_at timestamptz NOT NULL DEFAULT now(),
    recorded_by uuid REFERENCES users(id),
    supersedes_id uuid,
    CHECK (assertion <> 'PRESENT' OR substance_name IS NOT NULL OR substance_code IS NOT NULL),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE conditions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    patient_link_id uuid NOT NULL,
    admission_id uuid,
    code_system text,
    condition_code text,
    display_name text NOT NULL,
    clinical_status text NOT NULL,
    verification_status text NOT NULL,
    onset_date date,
    resolved_date date,
    recorded_by uuid REFERENCES users(id),
    source text,
    supersedes_id uuid,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

-- ============================================================================
-- 03 | Private files, patient portal, caregivers and patient releases
-- ============================================================================

CREATE TABLE objects (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    patient_link_id uuid,
    admission_id uuid,
    storage_bucket text NOT NULL,
    object_key text NOT NULL,
    original_filename text,
    mime_type text NOT NULL,
    byte_size bigint NOT NULL CHECK (byte_size > 0),
    sha256 text CHECK (sha256 ~ '^[a-fA-F0-9]{64}$'),
    status text NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'UPLOADED', 'QUARANTINED', 'CLEAN', 'REJECTED', 'ARCHIVED')),
    encryption_key_ref text,
    uploaded_by uuid REFERENCES users(id),
    uploaded_at timestamptz,
    scanned_at timestamptz,
    retention_until timestamptz,
    UNIQUE (storage_bucket, object_key),
    UNIQUE (hospital_id, id, patient_link_id),
    CHECK (admission_id IS NULL OR patient_link_id IS NOT NULL),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE upload_intents (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    object_id uuid NOT NULL,
    requested_by uuid NOT NULL REFERENCES users(id),
    purpose text NOT NULL,
    expires_at timestamptz NOT NULL,
    completed_at timestamptz,
    status text NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'COMPLETE', 'EXPIRED', 'REJECTED')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE portal_link_requests (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    user_id uuid NOT NULL REFERENCES users(id),
    patient_link_id uuid NOT NULL,
    invitation_id uuid REFERENCES invitations(id),
    proof_object_id uuid,
    status text NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED', 'REVOKED')),
    reviewed_by uuid REFERENCES users(id),
    reviewed_at timestamptz,
    reason text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE patient_portal_links (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    user_id uuid NOT NULL REFERENCES users(id),
    patient_link_id uuid NOT NULL,
    request_id uuid,
    verified_at timestamptz NOT NULL,
    verified_by uuid NOT NULL REFERENCES users(id),
    status text NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'REVOKED', 'SUSPENDED')),
    revoked_at timestamptz,
    revocation_reason text,
    UNIQUE (hospital_id, id, patient_link_id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE UNIQUE INDEX uq_self_portal_link ON patient_portal_links (hospital_id, patient_link_id) WHERE status = 'ACTIVE' AND revoked_at IS NULL;

CREATE TABLE caregiver_grants (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    patient_link_id uuid NOT NULL,
    portal_link_id uuid,
    caregiver_user_id uuid NOT NULL REFERENCES users(id),
    invitation_id uuid REFERENCES invitations(id),
    consent_id uuid,
    relationship text,
    authority_basis text NOT NULL,
    scope jsonb NOT NULL DEFAULT '{}'::jsonb,
    status text NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'ACTIVE', 'REVOKED', 'EXPIRED', 'REJECTED')),
    starts_at timestamptz,
    expires_at timestamptz NOT NULL,
    accepted_at timestamptz,
    revoked_at timestamptz,
    granted_by uuid REFERENCES users(id),
    CHECK (starts_at IS NULL OR expires_at > starts_at),
    UNIQUE (hospital_id, id, patient_link_id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE clinical_record_versions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    patient_link_id uuid NOT NULL,
    admission_id uuid,
    record_key uuid NOT NULL,
    revision integer NOT NULL CHECK (revision > 0),
    record_type text NOT NULL,
    source_table text NOT NULL,
    source_id uuid NOT NULL,
    title text NOT NULL,
    object_id uuid,
    verification_status text NOT NULL DEFAULT 'DRAFT' CHECK (verification_status IN ('DRAFT', 'PATIENT_UPLOADED', 'VERIFIED', 'REJECTED', 'ENTERED_IN_ERROR')),
    event_at timestamptz NOT NULL,
    verified_at timestamptz,
    verified_by uuid REFERENCES users(id),
    supersedes_id uuid,
    content_hash bytea,
    UNIQUE (hospital_id, record_key, revision),
    UNIQUE (hospital_id, source_table, source_id, revision),
    UNIQUE (hospital_id, id, patient_link_id),
    CHECK (verification_status <> 'VERIFIED' OR (verified_at IS NOT NULL AND verified_by IS NOT NULL)),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (hospital_id, id)
);

CREATE TABLE record_releases (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    patient_link_id uuid NOT NULL,
    record_version_id uuid NOT NULL,
    released_by uuid NOT NULL REFERENCES users(id),
    released_at timestamptz NOT NULL DEFAULT now(),
    withdrawn_at timestamptz,
    withdrawn_by uuid REFERENCES users(id),
    withdrawal_reason text,
    UNIQUE (hospital_id, id, patient_link_id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE UNIQUE INDEX uq_active_record_release ON record_releases (hospital_id, record_version_id) WHERE withdrawn_at IS NULL;

CREATE TABLE caregiver_grant_records (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    patient_link_id uuid NOT NULL,
    grant_id uuid NOT NULL,
    release_id uuid NOT NULL,
    UNIQUE (grant_id, release_id),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (hospital_id, id)
);

CREATE TABLE correction_requests (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    patient_link_id uuid NOT NULL,
    record_version_id uuid,
    requested_by uuid NOT NULL REFERENCES users(id),
    category text NOT NULL,
    description text NOT NULL,
    proposed_changes jsonb NOT NULL DEFAULT '{}'::jsonb,
    status text NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'IN_REVIEW', 'APPROVED', 'REJECTED', 'RESOLVED')),
    reviewed_by uuid REFERENCES users(id),
    reviewed_at timestamptz,
    resolution text,
    corrected_record_version_id uuid,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE patient_uploaded_documents (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    patient_link_id uuid NOT NULL,
    object_id uuid NOT NULL,
    uploaded_by uuid NOT NULL REFERENCES users(id),
    title text NOT NULL,
    category text NOT NULL,
    reported_hospital_name text,
    document_date date,
    description text,
    status text NOT NULL DEFAULT 'PENDING_REVIEW' CHECK (status IN ('PENDING_REVIEW', 'ACCEPTED', 'REJECTED', 'WITHDRAWN')),
    reviewed_at timestamptz,
    reviewed_by uuid REFERENCES users(id),
    record_version_id uuid,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE download_tickets (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    patient_link_id uuid NOT NULL,
    release_id uuid NOT NULL,
    user_id uuid NOT NULL REFERENCES users(id),
    token_digest bytea NOT NULL UNIQUE,
    expires_at timestamptz NOT NULL,
    revoked_at timestamptz,
    consumed_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE patient_notifications (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    user_id uuid NOT NULL REFERENCES users(id),
    patient_link_id uuid,
    notification_type text NOT NULL,
    title text NOT NULL,
    generic_message text,
    target_route text,
    read_at timestamptz,
    dismissed_at timestamptz,
    dedupe_key text NOT NULL,
    UNIQUE (hospital_id, user_id, dedupe_key),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE support_tickets (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    user_id uuid NOT NULL REFERENCES users(id),
    patient_link_id uuid,
    subject text NOT NULL,
    category text NOT NULL,
    description text NOT NULL,
    status text NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED')),
    assigned_to uuid REFERENCES users(id),
    closed_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

-- ============================================================================
-- 04 | Medication catalog, prescriptions, dose safety and interactions
-- ============================================================================

CREATE TABLE medication_catalog (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    code_system text NOT NULL,
    drug_code text NOT NULL,
    generic_name text NOT NULL,
    brand_name text,
    strength_value numeric(18,6) CHECK (strength_value > 0),
    strength_unit text,
    dose_form text,
    manufacturer text,
    active boolean NOT NULL DEFAULT true,
    UNIQUE (hospital_id, code_system, drug_code),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE product_barcodes (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    medication_id uuid NOT NULL,
    barcode text NOT NULL,
    barcode_type text NOT NULL,
    package_description text,
    active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE UNIQUE INDEX uq_active_product_barcode ON product_barcodes (hospital_id, barcode) WHERE active;

CREATE TABLE medication_orders (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    admission_id uuid NOT NULL,
    prescriber_membership_id uuid NOT NULL,
    medication_id uuid NOT NULL,
    status text NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT', 'ACTIVE', 'ON_HOLD', 'COMPLETED', 'CANCELLED')),
    current_revision_id uuid,
    ordered_at timestamptz NOT NULL DEFAULT now(),
    cancelled_at timestamptz,
    cancel_reason text,
    UNIQUE (hospital_id, id, admission_id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE medication_order_revisions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    order_id uuid NOT NULL,
    admission_id uuid NOT NULL,
    revision integer NOT NULL CHECK (revision > 0),
    medication_id uuid NOT NULL,
    dose_value numeric(18,6) NOT NULL CHECK (dose_value > 0),
    dose_unit text NOT NULL,
    route text NOT NULL,
    schedule_type text NOT NULL,
    schedule jsonb NOT NULL DEFAULT '{}'::jsonb,
    interval_minutes integer CHECK (interval_minutes > 0),
    effective_from timestamptz NOT NULL,
    effective_until timestamptz,
    instructions text,
    indication text,
    signed_by uuid NOT NULL REFERENCES users(id),
    signed_at timestamptz NOT NULL DEFAULT now(),
    change_reason text,
    CHECK (effective_until IS NULL OR effective_until > effective_from),
    UNIQUE (order_id, revision),
    UNIQUE (hospital_id, id, order_id, admission_id),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (hospital_id, id)
);

CREATE TABLE medication_dose_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    order_id uuid NOT NULL,
    order_revision_id uuid NOT NULL,
    admission_id uuid NOT NULL,
    occurrence_key text NOT NULL,
    due_at timestamptz NOT NULL,
    eligible_from timestamptz,
    eligible_until timestamptz,
    state text NOT NULL DEFAULT 'SCHEDULED' CHECK (state IN ('SCHEDULED', 'RESERVED', 'IN_PROGRESS', 'REVIEW_REQUIRED', 'ADMINISTERED', 'NOT_GIVEN', 'CANCELLED')),
    reservation_owner_id uuid,
    reservation_token_digest bytea,
    reserved_at timestamptz,
    reservation_expires_at timestamptz,
    started_at timestamptz,
    completed_at timestamptz,
    review_reason text,
    UNIQUE (order_revision_id, occurrence_key),
    UNIQUE (hospital_id, id, admission_id),
    CHECK (eligible_until IS NULL OR eligible_from IS NULL OR eligible_until >= eligible_from),
    CHECK (state NOT IN ('RESERVED','IN_PROGRESS') OR (reservation_owner_id IS NOT NULL AND reservation_token_digest IS NOT NULL AND reserved_at IS NOT NULL AND reservation_expires_at IS NOT NULL AND reservation_expires_at > reserved_at)),
    CHECK (state <> 'IN_PROGRESS' OR started_at IS NOT NULL),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE INDEX ix_medication_dose_events_hospital_id_state_due_at ON medication_dose_events (hospital_id, state, due_at);

CREATE INDEX ix_medication_dose_events_hospital_id_admission_id_due_at ON medication_dose_events (hospital_id, admission_id, due_at);

CREATE UNIQUE INDEX uq_reservation_digest ON medication_dose_events (reservation_token_digest) WHERE reservation_token_digest IS NOT NULL;

CREATE TABLE medication_scan_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    admission_id uuid NOT NULL,
    dose_event_id uuid,
    wristband_id uuid,
    barcode_id uuid,
    nurse_membership_id uuid NOT NULL,
    result_code text NOT NULL,
    scanned_at timestamptz NOT NULL DEFAULT now(),
    request_id text,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (hospital_id, id)
);

CREATE TABLE medication_administration_records (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    dose_event_id uuid NOT NULL,
    admission_id uuid NOT NULL,
    actor_membership_id uuid NOT NULL,
    outcome text NOT NULL CHECK (outcome IN ('ADMINISTERED', 'NOT_GIVEN', 'UNKNOWN')),
    actual_at timestamptz,
    recorded_at timestamptz NOT NULL DEFAULT now(),
    administered_dose numeric(18,6) CHECK (administered_dose > 0),
    dose_unit text,
    route text,
    source text NOT NULL CHECK (source IN ('SCAN', 'PAPER_DOWNTIME', 'RECONCILIATION')),
    rationale text,
    supersedes_id uuid,
    superseded_at timestamptz,
    CHECK (outcome <> 'ADMINISTERED' OR actual_at IS NOT NULL),
    UNIQUE (hospital_id, id, dose_event_id),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (hospital_id, id)
);

CREATE UNIQUE INDEX uq_confirmed_admin ON medication_administration_records (dose_event_id) WHERE outcome = 'ADMINISTERED' AND superseded_at IS NULL;

CREATE UNIQUE INDEX uq_administration_amendment ON medication_administration_records (supersedes_id) WHERE supersedes_id IS NOT NULL;

CREATE TABLE dose_reconciliations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    dose_event_id uuid NOT NULL,
    reviewer_membership_id uuid NOT NULL,
    second_reviewer_membership_id uuid,
    resolution text NOT NULL CHECK (resolution IN ('ADMINISTERED', 'NOT_GIVEN', 'REISSUE', 'UNRESOLVED')),
    reason text NOT NULL,
    evidence_refs jsonb NOT NULL DEFAULT '[]'::jsonb,
    reviewed_at timestamptz NOT NULL DEFAULT now(),
    second_approved_at timestamptz,
    CHECK (second_reviewer_membership_id IS NULL OR second_reviewer_membership_id <> reviewer_membership_id),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (hospital_id, id)
);

CREATE TABLE downtime_incidents (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    ward_id uuid,
    started_at timestamptz NOT NULL,
    ended_at timestamptz,
    reason text NOT NULL,
    protocol_reference text,
    reported_by uuid REFERENCES users(id),
    status text NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'RECONCILING', 'CLOSED')),
    CHECK (ended_at IS NULL OR ended_at >= started_at),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE downtime_entries (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    incident_id uuid NOT NULL,
    admission_id uuid NOT NULL,
    dose_event_id uuid,
    paper_reference text NOT NULL,
    observed_at timestamptz,
    recorded_outcome text,
    recorded_by uuid REFERENCES users(id),
    status text NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'REVIEWED', 'REJECTED')),
    reconciliation_id uuid,
    UNIQUE (hospital_id, incident_id, paper_reference),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE interaction_rule_versions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    source_name text NOT NULL,
    rule_version text NOT NULL,
    artifact_hash text,
    license_reference text,
    published_at timestamptz,
    active boolean NOT NULL DEFAULT false,
    coverage jsonb NOT NULL DEFAULT '{}'::jsonb,
    UNIQUE (source_name, rule_version),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0)
);

CREATE TABLE interaction_rules (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_version_id uuid NOT NULL REFERENCES interaction_rule_versions(id),
    rule_code text NOT NULL,
    interaction_type text NOT NULL,
    substance_a_code text NOT NULL,
    substance_b_code text NOT NULL,
    severity text NOT NULL,
    evidence_reference text NOT NULL,
    description text NOT NULL,
    UNIQUE (rule_version_id, rule_code),
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE interaction_checks (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    admission_id uuid NOT NULL,
    order_id uuid,
    rule_version_id uuid REFERENCES interaction_rule_versions(id),
    input_hash bytea NOT NULL,
    coverage jsonb NOT NULL DEFAULT '{}'::jsonb,
    findings jsonb NOT NULL DEFAULT '[]'::jsonb,
    result text NOT NULL CHECK (result IN ('CLEAR', 'WARNING', 'BLOCK', 'INCOMPLETE', 'ERROR')),
    review_status text NOT NULL DEFAULT 'PENDING' CHECK (review_status IN ('PENDING', 'ACCEPTED', 'REJECTED', 'OVERRIDDEN')),
    reviewed_by uuid REFERENCES users(id),
    reviewed_at timestamptz,
    override_reason text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE diet_orders (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    admission_id uuid NOT NULL,
    ordered_by_membership_id uuid NOT NULL,
    diet_type text NOT NULL,
    instructions text,
    effective_from timestamptz NOT NULL,
    effective_until timestamptz,
    status text NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'ON_HOLD', 'CANCELLED', 'COMPLETED')),
    CHECK (effective_until IS NULL OR effective_until > effective_from),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE diet_logs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    admission_id uuid NOT NULL,
    diet_order_id uuid,
    interaction_check_id uuid,
    food_description text NOT NULL,
    quantity numeric(18,6) CHECK (quantity >= 0),
    quantity_unit text,
    consumed_at timestamptz NOT NULL,
    recorded_by uuid NOT NULL REFERENCES users(id),
    status text NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT', 'VERIFIED', 'REJECTED')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

-- ============================================================================
-- 05 | Connected devices, clinical observations, NEWS2 and alerts
-- ============================================================================

CREATE TABLE devices (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    serial_number text NOT NULL UNIQUE,
    device_name text NOT NULL,
    device_type text NOT NULL,
    firmware_version text,
    hardware_version text,
    is_simulator boolean NOT NULL DEFAULT true,
    status text NOT NULL DEFAULT 'PROVISIONED' CHECK (status IN ('PROVISIONED', 'ACTIVE', 'INACTIVE', 'REVOKED', 'MAINTENANCE')),
    last_seen_at timestamptz,
    last_boot_id uuid,
    last_ip_hash bytea,
    registered_by uuid REFERENCES users(id),
    capabilities jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE device_credentials (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    device_id uuid NOT NULL,
    credential_type text NOT NULL,
    credential_digest bytea,
    secret_manager_ref text,
    certificate_fingerprint text,
    issued_at timestamptz NOT NULL DEFAULT now(),
    expires_at timestamptz,
    revoked_at timestamptz,
    CHECK (num_nonnulls(credential_digest, secret_manager_ref, certificate_fingerprint) >= 1),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE device_assignments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    device_id uuid NOT NULL,
    admission_id uuid NOT NULL,
    starts_at timestamptz NOT NULL,
    ends_at timestamptz,
    assigned_by uuid NOT NULL REFERENCES users(id),
    reason text,
    CHECK (ends_at IS NULL OR ends_at > starts_at),
    UNIQUE (hospital_id, id, device_id, admission_id),
    EXCLUDE USING gist (hospital_id WITH =, device_id WITH =, tstzrange(starts_at, ends_at, '[)') WITH &&),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE UNIQUE INDEX uq_active_device_assignment ON device_assignments (hospital_id, device_id) WHERE ends_at IS NULL;

CREATE TABLE device_health_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    device_id uuid NOT NULL,
    event_type text NOT NULL,
    event_at timestamptz NOT NULL,
    details jsonb NOT NULL DEFAULT '{}'::jsonb,
    is_simulated boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (hospital_id, id)
);

CREATE TABLE telemetry_ingest_dedupe (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    device_id uuid NOT NULL,
    boot_id uuid NOT NULL,
    sequence_no bigint NOT NULL CHECK (sequence_no >= 0),
    payload_hash bytea NOT NULL,
    measured_at timestamptz NOT NULL,
    UNIQUE (device_id, boot_id, sequence_no),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (hospital_id, id)
);

CREATE TABLE telemetry_samples (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    device_id uuid NOT NULL,
    assignment_id uuid NOT NULL,
    admission_id uuid NOT NULL,
    boot_id uuid NOT NULL,
    sequence_no bigint NOT NULL CHECK (sequence_no >= 0),
    measured_at timestamptz NOT NULL,
    received_at timestamptz NOT NULL DEFAULT now(),
    heart_rate_bpm numeric(9,3),
    spo2_percent numeric(6,3) CHECK (spo2_percent BETWEEN 0 AND 100),
    temperature_c numeric(7,3),
    respiratory_rate_bpm numeric(9,3),
    systolic_bp_mmhg numeric(9,3),
    diastolic_bp_mmhg numeric(9,3),
    iv_weight_g numeric(14,4),
    iv_flow_ml_hour numeric(14,4),
    iv_status text,
    signal_quality text NOT NULL,
    clock_quality text NOT NULL,
    is_simulated boolean NOT NULL DEFAULT true,
    quality_flags jsonb NOT NULL DEFAULT '[]'::jsonb,
    extra_metrics jsonb NOT NULL DEFAULT '{}'::jsonb,
    PRIMARY KEY (id, measured_at),
    UNIQUE (hospital_id, device_id, boot_id, sequence_no, measured_at)
) PARTITION BY RANGE (measured_at);

CREATE TABLE telemetry_samples_default PARTITION OF telemetry_samples DEFAULT;

CREATE INDEX ix_telemetry_admission_time ON telemetry_samples (hospital_id, admission_id, measured_at DESC);

CREATE INDEX ix_telemetry_device_time ON telemetry_samples (hospital_id, device_id, measured_at DESC);

CREATE TABLE telemetry_rejections (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    device_id uuid,
    boot_id uuid,
    sequence_no bigint,
    reason_code text NOT NULL,
    payload_hash bytea,
    received_at timestamptz NOT NULL DEFAULT now(),
    reviewed_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (hospital_id, id)
);

CREATE TABLE ecg_artifacts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    admission_id uuid NOT NULL,
    device_id uuid,
    assignment_id uuid,
    object_id uuid NOT NULL,
    started_at timestamptz NOT NULL,
    ended_at timestamptz,
    sampling_rate_hz numeric(12,4) NOT NULL CHECK (sampling_rate_hz > 0),
    lead_configuration text NOT NULL,
    signal_quality text NOT NULL,
    checksum text,
    is_simulated boolean NOT NULL DEFAULT true,
    CHECK (ended_at IS NULL OR ended_at > started_at),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE observations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    admission_id uuid NOT NULL,
    patient_link_id uuid NOT NULL,
    code_system text NOT NULL,
    observation_code text NOT NULL,
    display_name text NOT NULL,
    value_numeric numeric(18,6),
    value_text text,
    value_boolean boolean,
    value_json jsonb,
    unit_code text,
    unit_display text,
    observed_at timestamptz NOT NULL,
    recorded_at timestamptz NOT NULL DEFAULT now(),
    source text NOT NULL CHECK (source IN ('MANUAL', 'DEVICE', 'IMPORT', 'REPORT', 'VOICE', 'SIMULATOR')),
    device_id uuid,
    quality_status text NOT NULL,
    verification_status text NOT NULL DEFAULT 'DRAFT' CHECK (verification_status IN ('DRAFT', 'VERIFIED', 'REJECTED', 'ENTERED_IN_ERROR')),
    recorded_by uuid REFERENCES users(id),
    verified_by uuid REFERENCES users(id),
    verified_at timestamptz,
    supersedes_id uuid,
    is_simulated boolean NOT NULL DEFAULT true,
    CHECK (num_nonnulls(value_numeric, value_text, value_boolean, value_json) <= 1),
    UNIQUE (hospital_id, id, admission_id),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (hospital_id, id)
);

CREATE INDEX ix_observations_encounter_metric_time ON observations (hospital_id, admission_id, observation_code, observed_at DESC);

CREATE TABLE news2_rule_versions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_version text NOT NULL UNIQUE,
    source_reference text NOT NULL,
    configuration_hash bytea NOT NULL,
    approved_for_demo boolean NOT NULL DEFAULT false,
    published_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE news2_assessments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    admission_id uuid NOT NULL,
    rule_version_id uuid NOT NULL REFERENCES news2_rule_versions(id),
    assessed_at timestamptz NOT NULL,
    spo2_scale smallint CHECK (spo2_scale IN (1,2)),
    status text NOT NULL CHECK (status IN ('COMPLETE', 'INCOMPLETE', 'NOT_APPLICABLE', 'INVALID')),
    score smallint CHECK (score BETWEEN 0 AND 20),
    component_scores jsonb NOT NULL DEFAULT '{}'::jsonb,
    missing_fields jsonb NOT NULL DEFAULT '[]'::jsonb,
    quality_flags jsonb NOT NULL DEFAULT '[]'::jsonb,
    is_simulated boolean NOT NULL DEFAULT true,
    assessed_by uuid REFERENCES users(id),
    CHECK ((status = 'COMPLETE' AND score IS NOT NULL) OR (status <> 'COMPLETE' AND score IS NULL)),
    UNIQUE (hospital_id, id, admission_id),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (hospital_id, id)
);

CREATE TABLE news2_inputs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    admission_id uuid NOT NULL,
    assessment_id uuid NOT NULL,
    observation_id uuid NOT NULL,
    component text NOT NULL,
    UNIQUE (assessment_id, component),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (hospital_id, id)
);

CREATE TABLE alert_policies (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    policy_key text NOT NULL,
    policy_version integer NOT NULL CHECK (policy_version > 0),
    enabled boolean NOT NULL DEFAULT false,
    rules jsonb NOT NULL DEFAULT '{}'::jsonb,
    approved_by uuid REFERENCES users(id),
    approved_at timestamptz,
    UNIQUE (hospital_id, policy_key, policy_version),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE alerts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    admission_id uuid NOT NULL,
    news2_assessment_id uuid,
    policy_id uuid,
    fingerprint text NOT NULL,
    episode_key text NOT NULL,
    alert_type text NOT NULL,
    severity text NOT NULL CHECK (severity IN ('INFO', 'WARNING', 'CRITICAL')),
    status text NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'ACKNOWLEDGED', 'ESCALATED', 'RESOLVED', 'CLOSED')),
    title text NOT NULL,
    message text,
    raised_at timestamptz NOT NULL DEFAULT now(),
    last_seen_at timestamptz NOT NULL DEFAULT now(),
    owner_membership_id uuid,
    acknowledged_at timestamptz,
    resolved_at timestamptz,
    next_escalation_at timestamptz,
    escalation_level integer NOT NULL DEFAULT 0 CHECK (escalation_level >= 0),
    is_simulated boolean NOT NULL DEFAULT true,
    UNIQUE (hospital_id, episode_key),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE UNIQUE INDEX uq_active_alert ON alerts (hospital_id, fingerprint) WHERE status IN ('OPEN','ACKNOWLEDGED','ESCALATED');

CREATE INDEX ix_alerts_escalation_due ON alerts (next_escalation_at) WHERE status IN ('OPEN','ESCALATED');

CREATE TABLE alert_actions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    alert_id uuid NOT NULL,
    action_type text NOT NULL,
    actor_id uuid REFERENCES users(id),
    action_at timestamptz NOT NULL DEFAULT now(),
    reason text,
    previous_status text,
    new_status text,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (hospital_id, id)
);

CREATE TABLE notification_deliveries (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    alert_id uuid,
    patient_notification_id uuid,
    recipient_user_id uuid REFERENCES users(id),
    logical_delivery_key text NOT NULL,
    channel text NOT NULL CHECK (channel IN ('IN_APP', 'PUSH', 'SMS', 'EMAIL', 'WARD_DISPLAY')),
    attempt_no integer NOT NULL DEFAULT 1 CHECK (attempt_no > 0),
    status text NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'SENT', 'DELIVERED', 'FAILED', 'CANCELLED')),
    provider_message_id text,
    error_code text,
    next_attempt_at timestamptz,
    sent_at timestamptz,
    delivered_at timestamptz,
    UNIQUE (hospital_id, logical_delivery_key, attempt_no),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

-- ============================================================================
-- 06 | Nursing shifts, handoff, clinical documents and longitudinal history
-- ============================================================================

CREATE TABLE shifts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    ward_id uuid NOT NULL,
    nurse_membership_id uuid NOT NULL,
    scheduled_start timestamptz NOT NULL,
    scheduled_end timestamptz NOT NULL,
    clock_in_at timestamptz,
    clock_out_at timestamptz,
    status text NOT NULL DEFAULT 'SCHEDULED' CHECK (status IN ('SCHEDULED', 'ACTIVE', 'COMPLETED', 'CANCELLED')),
    CHECK (scheduled_end > scheduled_start),
    CHECK (clock_out_at IS NULL OR (clock_in_at IS NOT NULL AND clock_out_at >= clock_in_at)),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE UNIQUE INDEX uq_active_nursing_shift ON shifts (hospital_id, nurse_membership_id) WHERE status = 'ACTIVE';

CREATE TABLE handoffs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    ward_id uuid NOT NULL,
    outgoing_shift_id uuid NOT NULL,
    incoming_shift_id uuid,
    outgoing_membership_id uuid NOT NULL,
    incoming_membership_id uuid,
    snapshot_cutoff_at timestamptz NOT NULL,
    status text NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT', 'SIGNED', 'ACCEPTED', 'STALE', 'CANCELLED')),
    current_revision integer NOT NULL DEFAULT 1 CHECK (current_revision > 0),
    signed_at timestamptz,
    accepted_at timestamptz,
    accepted_by uuid REFERENCES users(id),
    stale_reason text,
    CHECK (outgoing_shift_id <> incoming_shift_id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE handoff_versions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    handoff_id uuid NOT NULL,
    revision integer NOT NULL CHECK (revision > 0),
    situation text,
    background text,
    assessment text,
    recommendation text,
    snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
    ai_draft jsonb NOT NULL DEFAULT '{}'::jsonb,
    model_version text,
    signed_at timestamptz,
    signed_by uuid REFERENCES users(id),
    snapshot_hash bytea NOT NULL,
    UNIQUE (handoff_id, revision),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (hospital_id, id)
);

CREATE TABLE handoff_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    handoff_version_id uuid NOT NULL,
    admission_id uuid NOT NULL,
    item_type text NOT NULL,
    dose_event_id uuid,
    alert_id uuid,
    description text NOT NULL,
    priority text,
    due_at timestamptz,
    resolved_at_snapshot boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (hospital_id, id)
);

CREATE TABLE clinical_reports (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    admission_id uuid,
    patient_link_id uuid NOT NULL,
    object_id uuid NOT NULL,
    report_type text NOT NULL,
    title text NOT NULL,
    source_format text NOT NULL,
    ordering_doctor_id uuid,
    performing_lab text,
    report_at timestamptz,
    specimen_at timestamptz,
    status text NOT NULL DEFAULT 'UPLOADED' CHECK (status IN ('UPLOADED', 'QUEUED', 'EXTRACTING', 'REVIEW_REQUIRED', 'VERIFIED', 'REJECTED', 'ARCHIVED')),
    current_revision_id uuid,
    uploaded_by uuid NOT NULL REFERENCES users(id),
    UNIQUE (hospital_id, id, patient_link_id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE report_extraction_jobs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    report_id uuid NOT NULL,
    pipeline_stage text NOT NULL,
    engine_name text NOT NULL,
    engine_version text,
    input_hash bytea NOT NULL,
    status text NOT NULL DEFAULT 'QUEUED' CHECK (status IN ('QUEUED', 'RUNNING', 'SUCCEEDED', 'FAILED', 'CANCELLED')),
    attempt_count integer NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
    started_at timestamptz,
    finished_at timestamptz,
    error_code text,
    extraction_metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE report_revisions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    report_id uuid NOT NULL,
    patient_link_id uuid NOT NULL,
    revision integer NOT NULL CHECK (revision > 0),
    pipeline_type text NOT NULL,
    verification_status text NOT NULL CHECK (verification_status IN ('DRAFT', 'VERIFIED', 'REJECTED')),
    source_match_verified boolean NOT NULL DEFAULT false,
    parsed_data jsonb NOT NULL DEFAULT '{}'::jsonb,
    verified_at timestamptz,
    verified_by uuid REFERENCES users(id),
    content_hash bytea,
    supersedes_id uuid,
    UNIQUE (report_id, revision),
    UNIQUE (hospital_id, id, report_id, patient_link_id),
    CHECK (verification_status <> 'VERIFIED' OR (source_match_verified AND verified_at IS NOT NULL AND verified_by IS NOT NULL)),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (hospital_id, id)
);

CREATE TABLE report_fields (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    report_revision_id uuid NOT NULL,
    field_key text NOT NULL,
    test_code text,
    code_system text,
    field_label text NOT NULL,
    candidate_value_text text,
    candidate_value_numeric numeric(18,6),
    candidate_unit text,
    reviewed_value_text text,
    reviewed_value_numeric numeric(18,6),
    reviewed_unit text,
    reference_range_text text,
    reference_low numeric(18,6),
    reference_high numeric(18,6),
    abnormal_flag text,
    is_clinically_consequential boolean NOT NULL DEFAULT true,
    disagreement boolean NOT NULL DEFAULT false,
    evidence_page integer CHECK (evidence_page > 0),
    evidence_locator jsonb NOT NULL DEFAULT '{}'::jsonb,
    review_status text NOT NULL DEFAULT 'PENDING' CHECK (review_status IN ('PENDING', 'CONFIRMED', 'CORRECTED', 'REJECTED')),
    reviewed_by uuid REFERENCES users(id),
    reviewed_at timestamptz,
    review_reason text,
    UNIQUE (report_revision_id, field_key),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE report_field_candidates (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    report_field_id uuid NOT NULL,
    extraction_job_id uuid NOT NULL,
    value_text text,
    value_numeric numeric(18,6),
    unit_text text,
    confidence numeric(6,5) CHECK (confidence BETWEEN 0 AND 1),
    evidence_locator jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (hospital_id, id)
);

CREATE TABLE report_review_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    report_revision_id uuid NOT NULL,
    field_id uuid,
    review_action text NOT NULL,
    reviewed_by uuid NOT NULL REFERENCES users(id),
    reason text,
    review_details jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (hospital_id, id)
);

CREATE TABLE voice_jobs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    admission_id uuid NOT NULL,
    patient_link_id uuid NOT NULL,
    audio_object_id uuid NOT NULL,
    requested_by uuid NOT NULL REFERENCES users(id),
    language_hint text,
    detected_language text,
    speech_model_version text,
    structuring_model_version text,
    transcript text,
    structured_draft jsonb NOT NULL DEFAULT '{}'::jsonb,
    status text NOT NULL DEFAULT 'QUEUED' CHECK (status IN ('QUEUED', 'PROCESSING', 'REVIEW_REQUIRED', 'COMPLETED', 'FAILED', 'REJECTED')),
    reviewed_at timestamptz,
    reviewed_by uuid REFERENCES users(id),
    error_code text,
    started_at timestamptz,
    finished_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE clinical_notes (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    admission_id uuid NOT NULL,
    patient_link_id uuid NOT NULL,
    voice_job_id uuid,
    note_type text NOT NULL,
    body text NOT NULL,
    observed_at timestamptz NOT NULL,
    author_id uuid NOT NULL REFERENCES users(id),
    status text NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT', 'SIGNED', 'REJECTED', 'ENTERED_IN_ERROR')),
    signed_at timestamptz,
    signed_by uuid REFERENCES users(id),
    supersedes_id uuid,
    source text NOT NULL,
    UNIQUE (hospital_id, id, patient_link_id),
    CHECK (status <> 'SIGNED' OR (signed_at IS NOT NULL AND signed_by IS NOT NULL)),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE timeline_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    patient_link_id uuid NOT NULL,
    admission_id uuid,
    record_version_id uuid NOT NULL,
    event_type text NOT NULL,
    event_at timestamptz NOT NULL,
    title text NOT NULL,
    UNIQUE (hospital_id, record_version_id, event_type),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (hospital_id, id)
);

CREATE INDEX ix_timeline_patient_time ON timeline_events (hospital_id, patient_link_id, event_at DESC);

CREATE TABLE discharge_summaries (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    admission_id uuid NOT NULL,
    patient_link_id uuid NOT NULL,
    revision integer NOT NULL CHECK (revision > 0),
    reason_for_admission text,
    treatment_summary text,
    diagnosis_summary text,
    discharge_instructions text,
    follow_up_instructions text,
    follow_up_at timestamptz,
    medication_summary jsonb NOT NULL DEFAULT '[]'::jsonb,
    pending_items jsonb NOT NULL DEFAULT '[]'::jsonb,
    status text NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT', 'SIGNED', 'REJECTED')),
    prepared_by uuid NOT NULL REFERENCES users(id),
    signed_by uuid REFERENCES users(id),
    signed_at timestamptz,
    pdf_object_id uuid,
    supersedes_id uuid,
    UNIQUE (admission_id, revision),
    UNIQUE (hospital_id, id, patient_link_id),
    CHECK (status <> 'SIGNED' OR (signed_at IS NOT NULL AND signed_by IS NOT NULL)),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE fhir_exports (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    patient_link_id uuid NOT NULL,
    admission_id uuid,
    requested_by uuid NOT NULL REFERENCES users(id),
    consent_id uuid,
    fhir_version text NOT NULL DEFAULT 'R4',
    profile_version text,
    bundle_object_id uuid,
    status text NOT NULL DEFAULT 'QUEUED' CHECK (status IN ('QUEUED', 'COMPLETE', 'FAILED', 'REVOKED')),
    error_code text,
    completed_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

-- ============================================================================
-- 07 | Referrals, record sharing, clinical RAG and AI research
-- ============================================================================

CREATE TABLE referrals (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    patient_link_id uuid NOT NULL,
    admission_id uuid,
    destination_hospital_id uuid REFERENCES hospitals(id),
    destination_name text,
    recipient_user_id uuid REFERENCES users(id),
    referring_membership_id uuid NOT NULL,
    discharge_summary_id uuid,
    reason text NOT NULL,
    purpose text NOT NULL,
    priority text,
    status text NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT', 'ACTIVE', 'ACCEPTED', 'REVOKED', 'EXPIRED', 'CLOSED')),
    issued_at timestamptz,
    expires_at timestamptz,
    accepted_at timestamptz,
    revoked_at timestamptz,
    pdf_object_id uuid,
    UNIQUE (hospital_id, id, patient_link_id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE referral_grants (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    referral_id uuid NOT NULL,
    patient_link_id uuid NOT NULL,
    consent_id uuid NOT NULL,
    recipient_hospital_id uuid REFERENCES hospitals(id),
    recipient_user_id uuid REFERENCES users(id),
    token_digest bytea NOT NULL UNIQUE,
    purpose text NOT NULL,
    scope jsonb NOT NULL DEFAULT '{}'::jsonb,
    starts_at timestamptz NOT NULL DEFAULT now(),
    expires_at timestamptz NOT NULL,
    redeemed_at timestamptz,
    revoked_at timestamptz,
    granted_by uuid NOT NULL REFERENCES users(id),
    revoke_reason text,
    CHECK (expires_at > starts_at),
    CHECK (num_nonnulls(recipient_hospital_id, recipient_user_id) >= 1),
    UNIQUE (hospital_id, id, patient_link_id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE referral_grant_records (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    patient_link_id uuid NOT NULL,
    grant_id uuid NOT NULL,
    record_version_id uuid NOT NULL,
    UNIQUE (grant_id, record_version_id),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (hospital_id, id)
);

CREATE TABLE referral_sessions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    grant_id uuid NOT NULL,
    patient_link_id uuid NOT NULL,
    recipient_user_id uuid NOT NULL REFERENCES users(id),
    recipient_membership_id uuid REFERENCES memberships(id),
    session_id uuid REFERENCES sessions(id),
    token_digest bytea NOT NULL UNIQUE,
    expires_at timestamptz NOT NULL,
    revoked_at timestamptz,
    last_seen_at timestamptz,
    UNIQUE (hospital_id, id, patient_link_id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE referral_access_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    referral_session_id uuid NOT NULL,
    record_version_id uuid,
    action text NOT NULL,
    actor_id uuid NOT NULL REFERENCES users(id),
    outcome text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (hospital_id, id)
);

CREATE TABLE embedding_models (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    provider text NOT NULL,
    model_name text NOT NULL,
    model_version text NOT NULL,
    dimensions integer NOT NULL CHECK (dimensions > 0),
    active boolean NOT NULL DEFAULT false,
    UNIQUE (provider, model_name, model_version),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0)
);

CREATE TABLE rag_documents (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    patient_link_id uuid NOT NULL,
    record_version_id uuid NOT NULL,
    embedding_model_id uuid NOT NULL REFERENCES embedding_models(id),
    source_hash bytea NOT NULL,
    language text,
    status text NOT NULL DEFAULT 'QUEUED' CHECK (status IN ('QUEUED', 'INDEXED', 'INVALIDATED', 'FAILED')),
    indexed_at timestamptz,
    invalidated_at timestamptz,
    UNIQUE (record_version_id, embedding_model_id),
    UNIQUE (hospital_id, id, patient_link_id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE rag_chunks (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    patient_link_id uuid NOT NULL,
    document_id uuid NOT NULL,
    chunk_index integer NOT NULL CHECK (chunk_index >= 0),
    chunk_text text NOT NULL,
    token_count integer CHECK (token_count >= 0),
    source_locator jsonb NOT NULL DEFAULT '{}',
    content_hash bytea NOT NULL,
    invalidated_at timestamptz,
    UNIQUE (document_id, chunk_index),
    UNIQUE (hospital_id, id, patient_link_id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

-- If pgvector is available and approved, install it before deploying the RAG module.
-- Example (separate privileged migration): CREATE EXTENSION IF NOT EXISTS vector;
-- If the extension is already installed, the block below adds the vector column.
-- Otherwise run ALTER TABLE medishield.rag_chunks ADD COLUMN embedding vector later.
-- Select a model-specific dimension and index only after scoped-retrieval evaluation.
-- Without vector, use verified relational/full-text retrieval or mark vector RAG unavailable.
DO $vector_setup$
DECLARE extension_schema text;
BEGIN
    SELECT n.nspname INTO extension_schema FROM pg_catalog.pg_extension e
    JOIN pg_catalog.pg_namespace n ON n.oid=e.extnamespace WHERE e.extname='vector';
    IF FOUND THEN
        EXECUTE format('ALTER TABLE medishield.rag_chunks ADD COLUMN embedding %I.vector', extension_schema);
    END IF;
END;
$vector_setup$;

CREATE INDEX ix_rag_scoped_chunks ON rag_chunks (hospital_id, patient_link_id, document_id) WHERE invalidated_at IS NULL;

CREATE TABLE rag_conversations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    patient_link_id uuid NOT NULL,
    user_id uuid NOT NULL REFERENCES users(id),
    referral_session_id uuid,
    portal_link_id uuid,
    caregiver_grant_id uuid,
    title text,
    closed_at timestamptz,
    UNIQUE (hospital_id, id, patient_link_id),
    CHECK (num_nonnulls(referral_session_id, portal_link_id, caregiver_grant_id) <= 1),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE rag_queries (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    patient_link_id uuid NOT NULL,
    conversation_id uuid NOT NULL,
    actor_user_id uuid NOT NULL REFERENCES users(id),
    question text NOT NULL,
    answer text,
    model_name text,
    model_version text,
    retrieval_version text,
    prompt_version text,
    status text NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'ANSWERED', 'ABSTAINED', 'BLOCKED', 'FAILED')),
    abstention_reason text,
    latency_ms integer CHECK (latency_ms >= 0),
    input_tokens integer CHECK (input_tokens >= 0),
    output_tokens integer CHECK (output_tokens >= 0),
    completed_at timestamptz,
    UNIQUE (hospital_id, id, patient_link_id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE rag_citations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    patient_link_id uuid NOT NULL,
    query_id uuid NOT NULL,
    chunk_id uuid NOT NULL,
    citation_index integer NOT NULL CHECK (citation_index > 0),
    source_label text NOT NULL,
    retrieval_score double precision,
    UNIQUE (query_id, citation_index),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (hospital_id, id)
);

CREATE TABLE rag_feedback (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    query_id uuid NOT NULL,
    user_id uuid NOT NULL REFERENCES users(id),
    helpful boolean,
    feedback_code text,
    comment text,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (hospital_id, id)
);

CREATE TABLE model_registry (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    model_key text NOT NULL,
    model_version text NOT NULL,
    task_type text NOT NULL,
    architecture text,
    artifact_uri text,
    artifact_sha256 text,
    intended_use text NOT NULL,
    limitations text NOT NULL,
    dataset_provenance jsonb NOT NULL DEFAULT '{}',
    metrics jsonb NOT NULL DEFAULT '{}',
    status text NOT NULL DEFAULT 'EXPERIMENTAL' CHECK (status IN ('EXPERIMENTAL', 'VALIDATED_FOR_RESEARCH', 'RETIRED')),
    registered_by uuid REFERENCES users(id),
    UNIQUE (model_key, model_version),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0)
);

CREATE TABLE research_datasets (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    dataset_name text NOT NULL,
    dataset_version text NOT NULL,
    source_reference text NOT NULL,
    license_reference text,
    approval_reference text,
    data_classification text NOT NULL,
    manifest_hash bytea,
    split_metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    UNIQUE (dataset_name, dataset_version),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0)
);

CREATE TABLE model_training_runs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    model_id uuid NOT NULL REFERENCES model_registry(id),
    dataset_id uuid REFERENCES research_datasets(id),
    run_key text NOT NULL UNIQUE,
    git_commit text,
    random_seed bigint,
    hyperparameters jsonb NOT NULL DEFAULT '{}'::jsonb,
    metrics jsonb NOT NULL DEFAULT '{}'::jsonb,
    environment jsonb NOT NULL DEFAULT '{}'::jsonb,
    status text NOT NULL DEFAULT 'QUEUED' CHECK (status IN ('QUEUED', 'RUNNING', 'COMPLETED', 'FAILED', 'CANCELLED')),
    started_at timestamptz,
    finished_at timestamptz,
    artifact_uri text,
    error_code text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0)
);

CREATE TABLE inference_jobs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    admission_id uuid,
    patient_link_id uuid NOT NULL,
    model_id uuid NOT NULL REFERENCES model_registry(id),
    input_object_id uuid,
    requested_by uuid NOT NULL REFERENCES users(id),
    task_type text NOT NULL,
    input_hash bytea NOT NULL,
    input_refs jsonb NOT NULL DEFAULT '[]'::jsonb,
    status text NOT NULL DEFAULT 'QUEUED' CHECK (status IN ('QUEUED', 'RUNNING', 'REVIEW_REQUIRED', 'FAILED', 'REJECTED', 'COMPLETED')),
    quality_status text,
    ood_status text,
    output_draft jsonb NOT NULL DEFAULT '{}'::jsonb,
    limitations jsonb NOT NULL DEFAULT '[]'::jsonb,
    explanation_object_id uuid,
    latency_ms integer CHECK (latency_ms >= 0),
    started_at timestamptz,
    finished_at timestamptz,
    error_code text,
    research_only boolean NOT NULL DEFAULT true CHECK (research_only),
    UNIQUE (hospital_id, id, patient_link_id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE inference_reviews (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    inference_job_id uuid NOT NULL,
    reviewer_membership_id uuid NOT NULL,
    decision text NOT NULL CHECK (decision IN ('ACKNOWLEDGED', 'REJECTED', 'RESEARCH_ACCEPTED')),
    reason text NOT NULL,
    reviewed_at timestamptz NOT NULL DEFAULT now(),
    reviewed_findings jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (hospital_id, id)
);

CREATE TABLE advisory_jobs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    admission_id uuid,
    patient_link_id uuid NOT NULL,
    model_id uuid REFERENCES model_registry(id),
    advisory_type text NOT NULL CHECK (advisory_type IN ('DETERIORATION', 'PRE_SURGICAL', 'LONGITUDINAL')),
    rule_version text,
    requested_by uuid REFERENCES users(id),
    input_refs jsonb NOT NULL DEFAULT '[]'::jsonb,
    evidence jsonb NOT NULL DEFAULT '[]'::jsonb,
    findings jsonb NOT NULL DEFAULT '[]'::jsonb,
    limitations jsonb NOT NULL DEFAULT '[]'::jsonb,
    status text NOT NULL DEFAULT 'QUEUED' CHECK (status IN ('QUEUED', 'RUNNING', 'REVIEW_REQUIRED', 'FAILED', 'REJECTED', 'COMPLETED')),
    quality_status text,
    research_only boolean NOT NULL DEFAULT true CHECK (research_only),
    completed_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE advisory_reviews (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    advisory_job_id uuid NOT NULL,
    reviewer_membership_id uuid NOT NULL,
    decision text NOT NULL CHECK (decision IN ('ACKNOWLEDGED', 'REJECTED', 'RESEARCH_ACCEPTED')),
    reason text NOT NULL,
    reviewed_at timestamptz NOT NULL DEFAULT now(),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (hospital_id, id)
);

-- ============================================================================
-- 08 | Offline synchronization, audit, jobs and operations
-- ============================================================================

CREATE TABLE sync_operations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    client_operation_id uuid NOT NULL,
    client_device_id text NOT NULL,
    actor_user_id uuid NOT NULL REFERENCES users(id),
    admission_id uuid NOT NULL,
    operation_type text NOT NULL CHECK (operation_type IN ('CREATE_NOTE', 'CREATE_OBSERVATION', 'CREATE_DIET_LOG')),
    payload_hash bytea NOT NULL,
    client_created_at timestamptz NOT NULL,
    received_at timestamptz NOT NULL DEFAULT now(),
    status text NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'APPLIED', 'CONFLICT', 'REJECTED')),
    result_reference uuid,
    error_code text,
    applied_at timestamptz,
    UNIQUE (hospital_id, actor_user_id, client_device_id, client_operation_id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE audit_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid REFERENCES hospitals(id),
    actor_user_id uuid REFERENCES users(id),
    actor_membership_id uuid,
    actor_device_id uuid,
    action text NOT NULL,
    resource_type text NOT NULL,
    resource_id uuid,
    request_id text,
    outcome text NOT NULL,
    reason_code text,
    ip_hash bytea,
    occurred_at timestamptz NOT NULL DEFAULT now(),
    redacted_metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX ix_audit_tenant_time ON audit_events (hospital_id, occurred_at DESC);

CREATE INDEX ix_audit_actor_time ON audit_events (actor_user_id, occurred_at DESC);

CREATE TABLE idempotency_records (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid REFERENCES hospitals(id),
    actor_user_id uuid NOT NULL REFERENCES users(id),
    route_key text NOT NULL,
    idempotency_key uuid NOT NULL,
    request_hash bytea NOT NULL,
    status text NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'COMPLETE')),
    http_status integer CHECK (http_status BETWEEN 100 AND 599),
    encrypted_response bytea,
    response_key_ref text,
    expires_at timestamptz NOT NULL,
    completed_at timestamptz,
    UNIQUE NULLS NOT DISTINCT (hospital_id, actor_user_id, route_key, idempotency_key),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0)
);

CREATE INDEX ix_idempotency_records_expires_at ON idempotency_records (expires_at);

CREATE TABLE outbox_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid REFERENCES hospitals(id),
    event_type text NOT NULL,
    aggregate_type text NOT NULL,
    aggregate_id uuid NOT NULL,
    aggregate_version integer,
    event_key text NOT NULL UNIQUE,
    payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    occurred_at timestamptz NOT NULL DEFAULT now(),
    available_at timestamptz NOT NULL DEFAULT now(),
    published_at timestamptz,
    attempt_count integer NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
    last_error_code text,
    lease_until timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0)
);

CREATE INDEX ix_outbox_pending ON outbox_events (available_at) WHERE published_at IS NULL;

CREATE TABLE background_jobs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid REFERENCES hospitals(id),
    job_type text NOT NULL,
    job_key text NOT NULL UNIQUE,
    resource_id uuid,
    safe_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    status text NOT NULL DEFAULT 'QUEUED' CHECK (status IN ('QUEUED', 'RUNNING', 'COMPLETED', 'FAILED', 'DEAD_LETTER', 'CANCELLED')),
    attempt_count integer NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
    max_attempts integer NOT NULL DEFAULT 5 CHECK (max_attempts > 0),
    scheduled_at timestamptz NOT NULL DEFAULT now(),
    started_at timestamptz,
    finished_at timestamptz,
    lease_until timestamptz,
    error_code text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0)
);

CREATE INDEX ix_background_jobs_status_scheduled_at ON background_jobs (status, scheduled_at);

CREATE TABLE webhook_deliveries (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid REFERENCES hospitals(id),
    provider text NOT NULL,
    provider_event_id text NOT NULL,
    payload_hash bytea NOT NULL,
    status text NOT NULL DEFAULT 'RECEIVED' CHECK (status IN ('RECEIVED', 'PROCESSED', 'REJECTED', 'FAILED')),
    received_at timestamptz NOT NULL DEFAULT now(),
    processed_at timestamptz,
    error_code text,
    UNIQUE (provider, provider_event_id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0)
);

CREATE TABLE integration_connections (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    integration_type text NOT NULL,
    provider_name text NOT NULL,
    secret_manager_ref text,
    external_account_ref text,
    status text NOT NULL DEFAULT 'DISABLED' CHECK (status IN ('DISABLED', 'ACTIVE', 'ERROR', 'REVOKED')),
    non_secret_config jsonb NOT NULL DEFAULT '{}'::jsonb,
    last_success_at timestamptz,
    UNIQUE (hospital_id, integration_type, provider_name),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE benchmark_runs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    run_key text NOT NULL UNIQUE,
    benchmark_type text NOT NULL,
    git_commit text,
    dataset_id uuid REFERENCES research_datasets(id),
    model_id uuid REFERENCES model_registry(id),
    sample_count bigint CHECK (sample_count >= 0),
    configuration jsonb NOT NULL DEFAULT '{}'::jsonb,
    results jsonb NOT NULL DEFAULT '{}'::jsonb,
    started_at timestamptz,
    finished_at timestamptz,
    notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0)
);

-- ============================================================================
-- 09 | Optional patient expansion (not required for original clinical MVP)
-- ============================================================================

-- Appointments, billing and emergency requests were proposed in the later portal discussion.
-- Keep routes disabled until separate authorization, scheduling, payment and operational requirements are approved.

CREATE TABLE appointment_slots (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    doctor_membership_id uuid NOT NULL,
    department_id uuid,
    starts_at timestamptz NOT NULL,
    ends_at timestamptz NOT NULL,
    capacity integer NOT NULL DEFAULT 1 CHECK (capacity > 0),
    status text NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'CLOSED', 'CANCELLED')),
    CHECK (ends_at > starts_at),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE appointments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    patient_link_id uuid NOT NULL,
    slot_id uuid NOT NULL,
    booked_by uuid REFERENCES users(id),
    reason text,
    status text NOT NULL DEFAULT 'REQUESTED' CHECK (status IN ('REQUESTED', 'CONFIRMED', 'CANCELLED', 'COMPLETED', 'NO_SHOW')),
    admission_id uuid,
    cancel_reason text,
    cancelled_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE UNIQUE INDEX uq_current_patient_slot ON appointments (hospital_id, slot_id, patient_link_id) WHERE status IN ('REQUESTED','CONFIRMED');

CREATE TABLE invoices (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    patient_link_id uuid NOT NULL,
    admission_id uuid,
    invoice_number text NOT NULL,
    currency char(3) NOT NULL DEFAULT 'INR',
    total_amount numeric(18,2) NOT NULL CHECK (total_amount >= 0),
    status text NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT', 'ISSUED', 'PARTIALLY_PAID', 'PAID', 'VOID')),
    issued_at timestamptz,
    due_at timestamptz,
    UNIQUE (hospital_id, invoice_number),
    UNIQUE (hospital_id, id, patient_link_id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE invoice_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    invoice_id uuid NOT NULL,
    description text NOT NULL,
    quantity numeric(12,3) NOT NULL CHECK (quantity > 0),
    unit_price numeric(18,2) NOT NULL CHECK (unit_price >= 0),
    tax_amount numeric(18,2) NOT NULL DEFAULT 0 CHECK (tax_amount >= 0),
    line_total numeric(18,2) NOT NULL CHECK (line_total >= 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE payment_transactions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    invoice_id uuid NOT NULL,
    provider text NOT NULL,
    provider_transaction_id text,
    amount numeric(18,2) NOT NULL CHECK (amount > 0),
    currency char(3) NOT NULL,
    status text NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'SUCCEEDED', 'FAILED', 'REFUNDED')),
    settled_at timestamptz,
    UNIQUE (provider, provider_transaction_id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE health_reminders (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    patient_link_id uuid NOT NULL,
    user_id uuid NOT NULL REFERENCES users(id),
    reminder_type text NOT NULL,
    title text NOT NULL,
    scheduled_at timestamptz NOT NULL,
    recurrence jsonb NOT NULL DEFAULT '{}'::jsonb,
    status text NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'COMPLETED', 'CANCELLED')),
    last_sent_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE emergency_requests (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    patient_link_id uuid,
    requested_by uuid REFERENCES users(id),
    request_type text NOT NULL,
    contact_phone text,
    location_encrypted bytea,
    status text NOT NULL DEFAULT 'REQUESTED' CHECK (status IN ('REQUESTED', 'ACKNOWLEDGED', 'CLOSED', 'CANCELLED', 'FAILED')),
    acknowledged_at timestamptz,
    acknowledged_by uuid REFERENCES users(id),
    closed_at timestamptz,
    resolution text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

-- ============================================================================
-- 09A | Additional lifecycle records and patient-facing details
-- ============================================================================

CREATE TABLE portal_account_roles (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES users(id),
    role_id uuid NOT NULL REFERENCES roles(id),
    status text NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'REVOKED')),
    granted_at timestamptz NOT NULL DEFAULT now(),
    revoked_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0)
);

CREATE UNIQUE INDEX uq_active_portal_account_role ON portal_account_roles (user_id, role_id) WHERE status = 'ACTIVE';

CREATE TABLE invitation_reviews (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    invitation_id uuid NOT NULL REFERENCES invitations(id),
    reviewed_by uuid NOT NULL REFERENCES users(id),
    decision text NOT NULL CHECK (decision IN ('APPROVED', 'REJECTED', 'REVOKED')),
    reason text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE account_email_changes (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES users(id),
    new_email text NOT NULL,
    token_digest bytea NOT NULL UNIQUE,
    expires_at timestamptz NOT NULL,
    confirmed_at timestamptz,
    revoked_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0)
);

CREATE TABLE membership_history (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    membership_id uuid NOT NULL,
    old_role_id uuid REFERENCES roles(id),
    new_role_id uuid REFERENCES roles(id),
    old_status text,
    new_status text,
    reason text NOT NULL,
    changed_by uuid NOT NULL REFERENCES users(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (hospital_id, id)
);

CREATE TABLE sharing_requests (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    patient_link_id uuid NOT NULL,
    portal_link_id uuid NOT NULL,
    requested_by uuid NOT NULL REFERENCES users(id),
    recipient_hospital_id uuid REFERENCES hospitals(id),
    recipient_user_id uuid REFERENCES users(id),
    purpose text NOT NULL,
    requested_scope jsonb NOT NULL DEFAULT '{}'::jsonb,
    requested_expires_at timestamptz,
    status text NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED', 'WITHDRAWN')),
    consent_id uuid,
    referral_grant_id uuid,
    reviewed_by uuid REFERENCES users(id),
    reviewed_at timestamptz,
    reason text,
    UNIQUE (hospital_id, id, patient_link_id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE sharing_request_records (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    patient_link_id uuid NOT NULL,
    request_id uuid NOT NULL,
    release_id uuid NOT NULL,
    UNIQUE (request_id, release_id),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (hospital_id, id)
);

CREATE TABLE vaccinations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid NOT NULL REFERENCES hospitals(id),
    patient_link_id uuid NOT NULL,
    admission_id uuid,
    vaccine_code text,
    code_system text,
    vaccine_name text NOT NULL,
    dose_number integer CHECK (dose_number > 0),
    lot_number text,
    administered_at timestamptz,
    source text NOT NULL,
    verification_status text NOT NULL DEFAULT 'DRAFT' CHECK (verification_status IN ('DRAFT', 'VERIFIED', 'REJECTED', 'ENTERED_IN_ERROR')),
    verified_by uuid REFERENCES users(id),
    verified_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (hospital_id, id)
);

CREATE TABLE audit_exports (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hospital_id uuid REFERENCES hospitals(id),
    requested_by uuid NOT NULL REFERENCES users(id),
    filter_scope jsonb NOT NULL DEFAULT '{}'::jsonb,
    status text NOT NULL DEFAULT 'QUEUED' CHECK (status IN ('QUEUED', 'COMPLETE', 'FAILED', 'EXPIRED')),
    private_object_key text,
    expires_at timestamptz,
    completed_at timestamptz,
    error_code text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0)
);

-- ============================================================================
-- 10 | Foreign keys, query indexes and database invariants
-- ============================================================================

ALTER TABLE membership_permissions ADD CONSTRAINT fk_membership_permissions_001 FOREIGN KEY (hospital_id, membership_id) REFERENCES memberships (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE moderation_actions ADD CONSTRAINT fk_moderation_actions_002 FOREIGN KEY (target_membership_id) REFERENCES memberships (id) ON DELETE RESTRICT;

ALTER TABLE credential_reviews ADD CONSTRAINT fk_credential_reviews_003 FOREIGN KEY (hospital_id, membership_id) REFERENCES memberships (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE access_requests ADD CONSTRAINT fk_access_requests_004 FOREIGN KEY (hospital_id, membership_id) REFERENCES memberships (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE sessions ADD CONSTRAINT fk_sessions_005 FOREIGN KEY (hospital_id, membership_id, user_id) REFERENCES memberships (hospital_id, id, user_id) ON DELETE RESTRICT;

ALTER TABLE wards ADD CONSTRAINT fk_wards_006 FOREIGN KEY (hospital_id, department_id) REFERENCES departments (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE beds ADD CONSTRAINT fk_beds_007 FOREIGN KEY (hospital_id, ward_id) REFERENCES wards (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE staff_profiles ADD CONSTRAINT fk_staff_profiles_008 FOREIGN KEY (hospital_id, membership_id) REFERENCES memberships (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE staff_department_assignments ADD CONSTRAINT fk_staff_department_assignments_009 FOREIGN KEY (hospital_id, membership_id) REFERENCES memberships (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE staff_department_assignments ADD CONSTRAINT fk_staff_department_assignments_010 FOREIGN KEY (hospital_id, department_id) REFERENCES departments (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE patient_identifiers ADD CONSTRAINT fk_patient_identifiers_011 FOREIGN KEY (hospital_id, patient_link_id) REFERENCES hospital_patient_links (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE patient_contacts ADD CONSTRAINT fk_patient_contacts_012 FOREIGN KEY (hospital_id, patient_link_id) REFERENCES hospital_patient_links (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE identity_match_reviews ADD CONSTRAINT fk_identity_match_reviews_013 FOREIGN KEY (hospital_id, patient_link_id) REFERENCES hospital_patient_links (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE identity_match_reviews ADD CONSTRAINT fk_identity_match_reviews_014 FOREIGN KEY (hospital_id, candidate_patient_link_id) REFERENCES hospital_patient_links (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE consents ADD CONSTRAINT fk_consents_015 FOREIGN KEY (hospital_id, patient_link_id) REFERENCES hospital_patient_links (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE consent_events ADD CONSTRAINT fk_consent_events_016 FOREIGN KEY (hospital_id, consent_id) REFERENCES consents (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE reception_queue ADD CONSTRAINT fk_reception_queue_017 FOREIGN KEY (hospital_id, patient_link_id) REFERENCES hospital_patient_links (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE reception_queue ADD CONSTRAINT fk_reception_queue_018 FOREIGN KEY (hospital_id, department_id) REFERENCES departments (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE reception_queue ADD CONSTRAINT fk_reception_queue_019 FOREIGN KEY (hospital_id, assigned_membership_id) REFERENCES memberships (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE admission_decisions ADD CONSTRAINT fk_admission_decisions_020 FOREIGN KEY (hospital_id, queue_id, patient_link_id) REFERENCES reception_queue (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE admission_decisions ADD CONSTRAINT fk_admission_decisions_021 FOREIGN KEY (hospital_id, doctor_membership_id) REFERENCES memberships (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE admissions ADD CONSTRAINT fk_admissions_022 FOREIGN KEY (hospital_id, patient_link_id) REFERENCES hospital_patient_links (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE admissions ADD CONSTRAINT fk_admissions_023 FOREIGN KEY (hospital_id, attending_doctor_id) REFERENCES memberships (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE admissions ADD CONSTRAINT fk_admissions_024 FOREIGN KEY (hospital_id, department_id) REFERENCES departments (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE admissions ADD CONSTRAINT fk_admissions_025 FOREIGN KEY (hospital_id, decision_id, queue_id, patient_link_id) REFERENCES admission_decisions (hospital_id, id, queue_id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE bed_assignments ADD CONSTRAINT fk_bed_assignments_026 FOREIGN KEY (hospital_id, admission_id) REFERENCES admissions (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE bed_assignments ADD CONSTRAINT fk_bed_assignments_027 FOREIGN KEY (hospital_id, bed_id) REFERENCES beds (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE care_assignments ADD CONSTRAINT fk_care_assignments_028 FOREIGN KEY (hospital_id, membership_id) REFERENCES memberships (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE care_assignments ADD CONSTRAINT fk_care_assignments_029 FOREIGN KEY (hospital_id, ward_id) REFERENCES wards (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE care_assignments ADD CONSTRAINT fk_care_assignments_030 FOREIGN KEY (hospital_id, admission_id) REFERENCES admissions (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE ward_tasks ADD CONSTRAINT fk_ward_tasks_031 FOREIGN KEY (hospital_id, ward_id) REFERENCES wards (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE ward_tasks ADD CONSTRAINT fk_ward_tasks_032 FOREIGN KEY (hospital_id, admission_id) REFERENCES admissions (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE ward_tasks ADD CONSTRAINT fk_ward_tasks_033 FOREIGN KEY (hospital_id, bed_id) REFERENCES beds (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE ward_tasks ADD CONSTRAINT fk_ward_tasks_034 FOREIGN KEY (hospital_id, assignee_membership_id) REFERENCES memberships (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE wristbands ADD CONSTRAINT fk_wristbands_035 FOREIGN KEY (hospital_id, admission_id) REFERENCES admissions (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE allergies ADD CONSTRAINT fk_allergies_036 FOREIGN KEY (hospital_id, patient_link_id) REFERENCES hospital_patient_links (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE allergies ADD CONSTRAINT fk_allergies_037 FOREIGN KEY (hospital_id, supersedes_id) REFERENCES allergies (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE conditions ADD CONSTRAINT fk_conditions_038 FOREIGN KEY (hospital_id, patient_link_id) REFERENCES hospital_patient_links (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE conditions ADD CONSTRAINT fk_conditions_039 FOREIGN KEY (hospital_id, admission_id, patient_link_id) REFERENCES admissions (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE conditions ADD CONSTRAINT fk_conditions_040 FOREIGN KEY (hospital_id, supersedes_id) REFERENCES conditions (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE objects ADD CONSTRAINT fk_objects_041 FOREIGN KEY (hospital_id, patient_link_id) REFERENCES hospital_patient_links (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE objects ADD CONSTRAINT fk_objects_042 FOREIGN KEY (hospital_id, admission_id, patient_link_id) REFERENCES admissions (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE credential_reviews ADD CONSTRAINT fk_credential_reviews_043 FOREIGN KEY (hospital_id, object_id) REFERENCES objects (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE upload_intents ADD CONSTRAINT fk_upload_intents_044 FOREIGN KEY (hospital_id, object_id) REFERENCES objects (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE portal_link_requests ADD CONSTRAINT fk_portal_link_requests_045 FOREIGN KEY (hospital_id, patient_link_id) REFERENCES hospital_patient_links (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE portal_link_requests ADD CONSTRAINT fk_portal_link_requests_046 FOREIGN KEY (hospital_id, proof_object_id, patient_link_id) REFERENCES objects (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE patient_portal_links ADD CONSTRAINT fk_patient_portal_links_047 FOREIGN KEY (hospital_id, patient_link_id) REFERENCES hospital_patient_links (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE patient_portal_links ADD CONSTRAINT fk_patient_portal_links_048 FOREIGN KEY (hospital_id, request_id) REFERENCES portal_link_requests (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE caregiver_grants ADD CONSTRAINT fk_caregiver_grants_049 FOREIGN KEY (hospital_id, patient_link_id) REFERENCES hospital_patient_links (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE caregiver_grants ADD CONSTRAINT fk_caregiver_grants_050 FOREIGN KEY (hospital_id, portal_link_id, patient_link_id) REFERENCES patient_portal_links (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE caregiver_grants ADD CONSTRAINT fk_caregiver_grants_051 FOREIGN KEY (hospital_id, consent_id, patient_link_id) REFERENCES consents (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE clinical_record_versions ADD CONSTRAINT fk_clinical_record_versions_052 FOREIGN KEY (hospital_id, patient_link_id) REFERENCES hospital_patient_links (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE clinical_record_versions ADD CONSTRAINT fk_clinical_record_versions_053 FOREIGN KEY (hospital_id, admission_id, patient_link_id) REFERENCES admissions (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE clinical_record_versions ADD CONSTRAINT fk_clinical_record_versions_054 FOREIGN KEY (hospital_id, object_id, patient_link_id) REFERENCES objects (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE clinical_record_versions ADD CONSTRAINT fk_clinical_record_versions_055 FOREIGN KEY (hospital_id, supersedes_id, patient_link_id) REFERENCES clinical_record_versions (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE record_releases ADD CONSTRAINT fk_record_releases_056 FOREIGN KEY (hospital_id, record_version_id, patient_link_id) REFERENCES clinical_record_versions (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE caregiver_grant_records ADD CONSTRAINT fk_caregiver_grant_records_057 FOREIGN KEY (hospital_id, grant_id, patient_link_id) REFERENCES caregiver_grants (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE caregiver_grant_records ADD CONSTRAINT fk_caregiver_grant_records_058 FOREIGN KEY (hospital_id, release_id, patient_link_id) REFERENCES record_releases (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE correction_requests ADD CONSTRAINT fk_correction_requests_059 FOREIGN KEY (hospital_id, patient_link_id) REFERENCES hospital_patient_links (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE correction_requests ADD CONSTRAINT fk_correction_requests_060 FOREIGN KEY (hospital_id, record_version_id, patient_link_id) REFERENCES clinical_record_versions (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE correction_requests ADD CONSTRAINT fk_correction_requests_061 FOREIGN KEY (hospital_id, corrected_record_version_id, patient_link_id) REFERENCES clinical_record_versions (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE patient_uploaded_documents ADD CONSTRAINT fk_patient_uploaded_documents_062 FOREIGN KEY (hospital_id, object_id, patient_link_id) REFERENCES objects (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE patient_uploaded_documents ADD CONSTRAINT fk_patient_uploaded_documents_063 FOREIGN KEY (hospital_id, record_version_id, patient_link_id) REFERENCES clinical_record_versions (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE download_tickets ADD CONSTRAINT fk_download_tickets_064 FOREIGN KEY (hospital_id, release_id, patient_link_id) REFERENCES record_releases (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE patient_notifications ADD CONSTRAINT fk_patient_notifications_065 FOREIGN KEY (hospital_id, patient_link_id) REFERENCES hospital_patient_links (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE support_tickets ADD CONSTRAINT fk_support_tickets_066 FOREIGN KEY (hospital_id, patient_link_id) REFERENCES hospital_patient_links (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE product_barcodes ADD CONSTRAINT fk_product_barcodes_067 FOREIGN KEY (hospital_id, medication_id) REFERENCES medication_catalog (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE medication_orders ADD CONSTRAINT fk_medication_orders_068 FOREIGN KEY (hospital_id, admission_id) REFERENCES admissions (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE medication_orders ADD CONSTRAINT fk_medication_orders_069 FOREIGN KEY (hospital_id, prescriber_membership_id) REFERENCES memberships (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE medication_orders ADD CONSTRAINT fk_medication_orders_070 FOREIGN KEY (hospital_id, medication_id) REFERENCES medication_catalog (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE medication_order_revisions ADD CONSTRAINT fk_medication_order_revisions_071 FOREIGN KEY (hospital_id, order_id, admission_id) REFERENCES medication_orders (hospital_id, id, admission_id) ON DELETE RESTRICT;

ALTER TABLE medication_order_revisions ADD CONSTRAINT fk_medication_order_revisions_072 FOREIGN KEY (hospital_id, medication_id) REFERENCES medication_catalog (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE medication_orders ADD CONSTRAINT fk_medication_orders_073 FOREIGN KEY (hospital_id, current_revision_id, id, admission_id) REFERENCES medication_order_revisions (hospital_id, id, order_id, admission_id) ON DELETE RESTRICT;

ALTER TABLE medication_dose_events ADD CONSTRAINT fk_medication_dose_events_074 FOREIGN KEY (hospital_id, order_revision_id, order_id, admission_id) REFERENCES medication_order_revisions (hospital_id, id, order_id, admission_id) ON DELETE RESTRICT;

ALTER TABLE medication_dose_events ADD CONSTRAINT fk_medication_dose_events_075 FOREIGN KEY (hospital_id, reservation_owner_id) REFERENCES memberships (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE medication_scan_events ADD CONSTRAINT fk_medication_scan_events_076 FOREIGN KEY (hospital_id, admission_id) REFERENCES admissions (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE medication_scan_events ADD CONSTRAINT fk_medication_scan_events_077 FOREIGN KEY (hospital_id, dose_event_id, admission_id) REFERENCES medication_dose_events (hospital_id, id, admission_id) ON DELETE RESTRICT;

ALTER TABLE medication_scan_events ADD CONSTRAINT fk_medication_scan_events_078 FOREIGN KEY (hospital_id, wristband_id, admission_id) REFERENCES wristbands (hospital_id, id, admission_id) ON DELETE RESTRICT;

ALTER TABLE medication_scan_events ADD CONSTRAINT fk_medication_scan_events_079 FOREIGN KEY (hospital_id, barcode_id) REFERENCES product_barcodes (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE medication_scan_events ADD CONSTRAINT fk_medication_scan_events_080 FOREIGN KEY (hospital_id, nurse_membership_id) REFERENCES memberships (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE medication_administration_records ADD CONSTRAINT fk_medication_administration_records_081 FOREIGN KEY (hospital_id, dose_event_id, admission_id) REFERENCES medication_dose_events (hospital_id, id, admission_id) ON DELETE RESTRICT;

ALTER TABLE medication_administration_records ADD CONSTRAINT fk_medication_administration_records_082 FOREIGN KEY (hospital_id, actor_membership_id) REFERENCES memberships (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE medication_administration_records ADD CONSTRAINT fk_medication_administration_records_083 FOREIGN KEY (hospital_id, supersedes_id, dose_event_id) REFERENCES medication_administration_records (hospital_id, id, dose_event_id) ON DELETE RESTRICT;

ALTER TABLE dose_reconciliations ADD CONSTRAINT fk_dose_reconciliations_084 FOREIGN KEY (hospital_id, dose_event_id) REFERENCES medication_dose_events (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE dose_reconciliations ADD CONSTRAINT fk_dose_reconciliations_085 FOREIGN KEY (hospital_id, reviewer_membership_id) REFERENCES memberships (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE dose_reconciliations ADD CONSTRAINT fk_dose_reconciliations_086 FOREIGN KEY (hospital_id, second_reviewer_membership_id) REFERENCES memberships (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE downtime_incidents ADD CONSTRAINT fk_downtime_incidents_087 FOREIGN KEY (hospital_id, ward_id) REFERENCES wards (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE downtime_entries ADD CONSTRAINT fk_downtime_entries_088 FOREIGN KEY (hospital_id, incident_id) REFERENCES downtime_incidents (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE downtime_entries ADD CONSTRAINT fk_downtime_entries_089 FOREIGN KEY (hospital_id, admission_id) REFERENCES admissions (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE downtime_entries ADD CONSTRAINT fk_downtime_entries_090 FOREIGN KEY (hospital_id, dose_event_id, admission_id) REFERENCES medication_dose_events (hospital_id, id, admission_id) ON DELETE RESTRICT;

ALTER TABLE downtime_entries ADD CONSTRAINT fk_downtime_entries_091 FOREIGN KEY (hospital_id, reconciliation_id) REFERENCES dose_reconciliations (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE interaction_checks ADD CONSTRAINT fk_interaction_checks_092 FOREIGN KEY (hospital_id, admission_id) REFERENCES admissions (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE interaction_checks ADD CONSTRAINT fk_interaction_checks_093 FOREIGN KEY (hospital_id, order_id, admission_id) REFERENCES medication_orders (hospital_id, id, admission_id) ON DELETE RESTRICT;

ALTER TABLE diet_orders ADD CONSTRAINT fk_diet_orders_094 FOREIGN KEY (hospital_id, admission_id) REFERENCES admissions (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE diet_orders ADD CONSTRAINT fk_diet_orders_095 FOREIGN KEY (hospital_id, ordered_by_membership_id) REFERENCES memberships (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE diet_logs ADD CONSTRAINT fk_diet_logs_096 FOREIGN KEY (hospital_id, admission_id) REFERENCES admissions (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE diet_logs ADD CONSTRAINT fk_diet_logs_097 FOREIGN KEY (hospital_id, diet_order_id) REFERENCES diet_orders (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE diet_logs ADD CONSTRAINT fk_diet_logs_098 FOREIGN KEY (hospital_id, interaction_check_id) REFERENCES interaction_checks (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE device_credentials ADD CONSTRAINT fk_device_credentials_099 FOREIGN KEY (hospital_id, device_id) REFERENCES devices (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE device_assignments ADD CONSTRAINT fk_device_assignments_100 FOREIGN KEY (hospital_id, device_id) REFERENCES devices (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE device_assignments ADD CONSTRAINT fk_device_assignments_101 FOREIGN KEY (hospital_id, admission_id) REFERENCES admissions (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE device_health_events ADD CONSTRAINT fk_device_health_events_102 FOREIGN KEY (hospital_id, device_id) REFERENCES devices (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE telemetry_ingest_dedupe ADD CONSTRAINT fk_telemetry_ingest_dedupe_103 FOREIGN KEY (hospital_id, device_id) REFERENCES devices (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE telemetry_samples ADD CONSTRAINT fk_telemetry_samples_104 FOREIGN KEY (hospital_id, assignment_id, device_id, admission_id) REFERENCES device_assignments (hospital_id, id, device_id, admission_id) ON DELETE RESTRICT;

ALTER TABLE telemetry_samples ADD CONSTRAINT fk_telemetry_samples_105 FOREIGN KEY (device_id, boot_id, sequence_no) REFERENCES telemetry_ingest_dedupe (device_id, boot_id, sequence_no) ON DELETE RESTRICT;

ALTER TABLE telemetry_rejections ADD CONSTRAINT fk_telemetry_rejections_106 FOREIGN KEY (hospital_id, device_id) REFERENCES devices (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE ecg_artifacts ADD CONSTRAINT fk_ecg_artifacts_107 FOREIGN KEY (hospital_id, admission_id) REFERENCES admissions (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE ecg_artifacts ADD CONSTRAINT fk_ecg_artifacts_108 FOREIGN KEY (hospital_id, device_id) REFERENCES devices (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE ecg_artifacts ADD CONSTRAINT fk_ecg_artifacts_109 FOREIGN KEY (hospital_id, assignment_id) REFERENCES device_assignments (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE ecg_artifacts ADD CONSTRAINT fk_ecg_artifacts_110 FOREIGN KEY (hospital_id, object_id) REFERENCES objects (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE observations ADD CONSTRAINT fk_observations_111 FOREIGN KEY (hospital_id, admission_id, patient_link_id) REFERENCES admissions (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE observations ADD CONSTRAINT fk_observations_112 FOREIGN KEY (hospital_id, device_id) REFERENCES devices (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE observations ADD CONSTRAINT fk_observations_113 FOREIGN KEY (hospital_id, supersedes_id, admission_id) REFERENCES observations (hospital_id, id, admission_id) ON DELETE RESTRICT;

ALTER TABLE news2_assessments ADD CONSTRAINT fk_news2_assessments_114 FOREIGN KEY (hospital_id, admission_id) REFERENCES admissions (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE news2_inputs ADD CONSTRAINT fk_news2_inputs_115 FOREIGN KEY (hospital_id, assessment_id, admission_id) REFERENCES news2_assessments (hospital_id, id, admission_id) ON DELETE RESTRICT;

ALTER TABLE news2_inputs ADD CONSTRAINT fk_news2_inputs_116 FOREIGN KEY (hospital_id, observation_id, admission_id) REFERENCES observations (hospital_id, id, admission_id) ON DELETE RESTRICT;

ALTER TABLE alerts ADD CONSTRAINT fk_alerts_117 FOREIGN KEY (hospital_id, admission_id) REFERENCES admissions (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE alerts ADD CONSTRAINT fk_alerts_118 FOREIGN KEY (hospital_id, news2_assessment_id, admission_id) REFERENCES news2_assessments (hospital_id, id, admission_id) ON DELETE RESTRICT;

ALTER TABLE alerts ADD CONSTRAINT fk_alerts_119 FOREIGN KEY (hospital_id, policy_id) REFERENCES alert_policies (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE alerts ADD CONSTRAINT fk_alerts_120 FOREIGN KEY (hospital_id, owner_membership_id) REFERENCES memberships (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE alert_actions ADD CONSTRAINT fk_alert_actions_121 FOREIGN KEY (hospital_id, alert_id) REFERENCES alerts (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE notification_deliveries ADD CONSTRAINT fk_notification_deliveries_122 FOREIGN KEY (hospital_id, alert_id) REFERENCES alerts (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE notification_deliveries ADD CONSTRAINT fk_notification_deliveries_123 FOREIGN KEY (hospital_id, patient_notification_id) REFERENCES patient_notifications (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE shifts ADD CONSTRAINT fk_shifts_124 FOREIGN KEY (hospital_id, ward_id) REFERENCES wards (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE shifts ADD CONSTRAINT fk_shifts_125 FOREIGN KEY (hospital_id, nurse_membership_id) REFERENCES memberships (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE handoffs ADD CONSTRAINT fk_handoffs_126 FOREIGN KEY (hospital_id, ward_id) REFERENCES wards (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE handoffs ADD CONSTRAINT fk_handoffs_127 FOREIGN KEY (hospital_id, outgoing_shift_id) REFERENCES shifts (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE handoffs ADD CONSTRAINT fk_handoffs_128 FOREIGN KEY (hospital_id, incoming_shift_id) REFERENCES shifts (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE handoffs ADD CONSTRAINT fk_handoffs_129 FOREIGN KEY (hospital_id, outgoing_membership_id) REFERENCES memberships (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE handoffs ADD CONSTRAINT fk_handoffs_130 FOREIGN KEY (hospital_id, incoming_membership_id) REFERENCES memberships (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE handoff_versions ADD CONSTRAINT fk_handoff_versions_131 FOREIGN KEY (hospital_id, handoff_id) REFERENCES handoffs (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE handoff_items ADD CONSTRAINT fk_handoff_items_132 FOREIGN KEY (hospital_id, handoff_version_id) REFERENCES handoff_versions (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE handoff_items ADD CONSTRAINT fk_handoff_items_133 FOREIGN KEY (hospital_id, admission_id) REFERENCES admissions (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE handoff_items ADD CONSTRAINT fk_handoff_items_134 FOREIGN KEY (hospital_id, dose_event_id, admission_id) REFERENCES medication_dose_events (hospital_id, id, admission_id) ON DELETE RESTRICT;

ALTER TABLE handoff_items ADD CONSTRAINT fk_handoff_items_135 FOREIGN KEY (hospital_id, alert_id) REFERENCES alerts (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE clinical_reports ADD CONSTRAINT fk_clinical_reports_136 FOREIGN KEY (hospital_id, admission_id, patient_link_id) REFERENCES admissions (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE clinical_reports ADD CONSTRAINT fk_clinical_reports_137 FOREIGN KEY (hospital_id, object_id, patient_link_id) REFERENCES objects (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE clinical_reports ADD CONSTRAINT fk_clinical_reports_138 FOREIGN KEY (hospital_id, ordering_doctor_id) REFERENCES memberships (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE report_extraction_jobs ADD CONSTRAINT fk_report_extraction_jobs_139 FOREIGN KEY (hospital_id, report_id) REFERENCES clinical_reports (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE report_revisions ADD CONSTRAINT fk_report_revisions_140 FOREIGN KEY (hospital_id, report_id, patient_link_id) REFERENCES clinical_reports (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE report_revisions ADD CONSTRAINT fk_report_revisions_141 FOREIGN KEY (hospital_id, supersedes_id, report_id, patient_link_id) REFERENCES report_revisions (hospital_id, id, report_id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE clinical_reports ADD CONSTRAINT fk_clinical_reports_142 FOREIGN KEY (hospital_id, current_revision_id, id, patient_link_id) REFERENCES report_revisions (hospital_id, id, report_id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE report_fields ADD CONSTRAINT fk_report_fields_143 FOREIGN KEY (hospital_id, report_revision_id) REFERENCES report_revisions (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE report_field_candidates ADD CONSTRAINT fk_report_field_candidates_144 FOREIGN KEY (hospital_id, report_field_id) REFERENCES report_fields (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE report_field_candidates ADD CONSTRAINT fk_report_field_candidates_145 FOREIGN KEY (hospital_id, extraction_job_id) REFERENCES report_extraction_jobs (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE report_review_events ADD CONSTRAINT fk_report_review_events_146 FOREIGN KEY (hospital_id, report_revision_id) REFERENCES report_revisions (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE report_review_events ADD CONSTRAINT fk_report_review_events_147 FOREIGN KEY (hospital_id, field_id) REFERENCES report_fields (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE voice_jobs ADD CONSTRAINT fk_voice_jobs_148 FOREIGN KEY (hospital_id, admission_id, patient_link_id) REFERENCES admissions (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE voice_jobs ADD CONSTRAINT fk_voice_jobs_149 FOREIGN KEY (hospital_id, audio_object_id, patient_link_id) REFERENCES objects (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE clinical_notes ADD CONSTRAINT fk_clinical_notes_150 FOREIGN KEY (hospital_id, admission_id, patient_link_id) REFERENCES admissions (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE clinical_notes ADD CONSTRAINT fk_clinical_notes_151 FOREIGN KEY (hospital_id, voice_job_id) REFERENCES voice_jobs (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE clinical_notes ADD CONSTRAINT fk_clinical_notes_152 FOREIGN KEY (hospital_id, supersedes_id, patient_link_id) REFERENCES clinical_notes (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE timeline_events ADD CONSTRAINT fk_timeline_events_153 FOREIGN KEY (hospital_id, admission_id, patient_link_id) REFERENCES admissions (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE timeline_events ADD CONSTRAINT fk_timeline_events_154 FOREIGN KEY (hospital_id, record_version_id, patient_link_id) REFERENCES clinical_record_versions (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE discharge_summaries ADD CONSTRAINT fk_discharge_summaries_155 FOREIGN KEY (hospital_id, admission_id, patient_link_id) REFERENCES admissions (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE discharge_summaries ADD CONSTRAINT fk_discharge_summaries_156 FOREIGN KEY (hospital_id, pdf_object_id, patient_link_id) REFERENCES objects (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE discharge_summaries ADD CONSTRAINT fk_discharge_summaries_157 FOREIGN KEY (hospital_id, supersedes_id, patient_link_id) REFERENCES discharge_summaries (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE fhir_exports ADD CONSTRAINT fk_fhir_exports_158 FOREIGN KEY (hospital_id, patient_link_id) REFERENCES hospital_patient_links (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE fhir_exports ADD CONSTRAINT fk_fhir_exports_159 FOREIGN KEY (hospital_id, admission_id, patient_link_id) REFERENCES admissions (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE fhir_exports ADD CONSTRAINT fk_fhir_exports_160 FOREIGN KEY (hospital_id, consent_id, patient_link_id) REFERENCES consents (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE fhir_exports ADD CONSTRAINT fk_fhir_exports_161 FOREIGN KEY (hospital_id, bundle_object_id, patient_link_id) REFERENCES objects (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE referrals ADD CONSTRAINT fk_referrals_162 FOREIGN KEY (hospital_id, patient_link_id) REFERENCES hospital_patient_links (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE referrals ADD CONSTRAINT fk_referrals_163 FOREIGN KEY (hospital_id, admission_id, patient_link_id) REFERENCES admissions (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE referrals ADD CONSTRAINT fk_referrals_164 FOREIGN KEY (hospital_id, referring_membership_id) REFERENCES memberships (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE referrals ADD CONSTRAINT fk_referrals_165 FOREIGN KEY (hospital_id, discharge_summary_id, patient_link_id) REFERENCES discharge_summaries (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE referrals ADD CONSTRAINT fk_referrals_166 FOREIGN KEY (hospital_id, pdf_object_id, patient_link_id) REFERENCES objects (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE referral_grants ADD CONSTRAINT fk_referral_grants_167 FOREIGN KEY (hospital_id, referral_id, patient_link_id) REFERENCES referrals (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE referral_grants ADD CONSTRAINT fk_referral_grants_168 FOREIGN KEY (hospital_id, consent_id, patient_link_id) REFERENCES consents (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE referral_grant_records ADD CONSTRAINT fk_referral_grant_records_169 FOREIGN KEY (hospital_id, grant_id, patient_link_id) REFERENCES referral_grants (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE referral_grant_records ADD CONSTRAINT fk_referral_grant_records_170 FOREIGN KEY (hospital_id, record_version_id, patient_link_id) REFERENCES clinical_record_versions (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE referral_sessions ADD CONSTRAINT fk_referral_sessions_171 FOREIGN KEY (hospital_id, grant_id, patient_link_id) REFERENCES referral_grants (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE referral_access_events ADD CONSTRAINT fk_referral_access_events_172 FOREIGN KEY (hospital_id, referral_session_id) REFERENCES referral_sessions (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE referral_access_events ADD CONSTRAINT fk_referral_access_events_173 FOREIGN KEY (hospital_id, record_version_id) REFERENCES clinical_record_versions (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE rag_documents ADD CONSTRAINT fk_rag_documents_174 FOREIGN KEY (hospital_id, record_version_id, patient_link_id) REFERENCES clinical_record_versions (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE rag_chunks ADD CONSTRAINT fk_rag_chunks_175 FOREIGN KEY (hospital_id, document_id, patient_link_id) REFERENCES rag_documents (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE rag_conversations ADD CONSTRAINT fk_rag_conversations_176 FOREIGN KEY (hospital_id, patient_link_id) REFERENCES hospital_patient_links (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE rag_conversations ADD CONSTRAINT fk_rag_conversations_177 FOREIGN KEY (hospital_id, referral_session_id, patient_link_id) REFERENCES referral_sessions (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE rag_conversations ADD CONSTRAINT fk_rag_conversations_178 FOREIGN KEY (hospital_id, portal_link_id, patient_link_id) REFERENCES patient_portal_links (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE rag_conversations ADD CONSTRAINT fk_rag_conversations_179 FOREIGN KEY (hospital_id, caregiver_grant_id, patient_link_id) REFERENCES caregiver_grants (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE rag_queries ADD CONSTRAINT fk_rag_queries_180 FOREIGN KEY (hospital_id, conversation_id, patient_link_id) REFERENCES rag_conversations (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE rag_citations ADD CONSTRAINT fk_rag_citations_181 FOREIGN KEY (hospital_id, query_id, patient_link_id) REFERENCES rag_queries (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE rag_citations ADD CONSTRAINT fk_rag_citations_182 FOREIGN KEY (hospital_id, chunk_id, patient_link_id) REFERENCES rag_chunks (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE rag_feedback ADD CONSTRAINT fk_rag_feedback_183 FOREIGN KEY (hospital_id, query_id) REFERENCES rag_queries (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE inference_jobs ADD CONSTRAINT fk_inference_jobs_184 FOREIGN KEY (hospital_id, patient_link_id) REFERENCES hospital_patient_links (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE inference_jobs ADD CONSTRAINT fk_inference_jobs_185 FOREIGN KEY (hospital_id, admission_id, patient_link_id) REFERENCES admissions (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE inference_jobs ADD CONSTRAINT fk_inference_jobs_186 FOREIGN KEY (hospital_id, input_object_id, patient_link_id) REFERENCES objects (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE inference_jobs ADD CONSTRAINT fk_inference_jobs_187 FOREIGN KEY (hospital_id, explanation_object_id, patient_link_id) REFERENCES objects (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE inference_reviews ADD CONSTRAINT fk_inference_reviews_188 FOREIGN KEY (hospital_id, inference_job_id) REFERENCES inference_jobs (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE inference_reviews ADD CONSTRAINT fk_inference_reviews_189 FOREIGN KEY (hospital_id, reviewer_membership_id) REFERENCES memberships (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE advisory_jobs ADD CONSTRAINT fk_advisory_jobs_190 FOREIGN KEY (hospital_id, patient_link_id) REFERENCES hospital_patient_links (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE advisory_jobs ADD CONSTRAINT fk_advisory_jobs_191 FOREIGN KEY (hospital_id, admission_id, patient_link_id) REFERENCES admissions (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE advisory_reviews ADD CONSTRAINT fk_advisory_reviews_192 FOREIGN KEY (hospital_id, advisory_job_id) REFERENCES advisory_jobs (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE advisory_reviews ADD CONSTRAINT fk_advisory_reviews_193 FOREIGN KEY (hospital_id, reviewer_membership_id) REFERENCES memberships (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE sync_operations ADD CONSTRAINT fk_sync_operations_194 FOREIGN KEY (hospital_id, admission_id) REFERENCES admissions (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE audit_events ADD CONSTRAINT fk_audit_events_195 FOREIGN KEY (hospital_id, actor_membership_id) REFERENCES memberships (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE audit_events ADD CONSTRAINT fk_audit_events_196 FOREIGN KEY (hospital_id, actor_device_id) REFERENCES devices (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE appointment_slots ADD CONSTRAINT fk_appointment_slots_197 FOREIGN KEY (hospital_id, doctor_membership_id) REFERENCES memberships (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE appointment_slots ADD CONSTRAINT fk_appointment_slots_198 FOREIGN KEY (hospital_id, department_id) REFERENCES departments (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE appointments ADD CONSTRAINT fk_appointments_199 FOREIGN KEY (hospital_id, patient_link_id) REFERENCES hospital_patient_links (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE appointments ADD CONSTRAINT fk_appointments_200 FOREIGN KEY (hospital_id, slot_id) REFERENCES appointment_slots (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE appointments ADD CONSTRAINT fk_appointments_201 FOREIGN KEY (hospital_id, admission_id, patient_link_id) REFERENCES admissions (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE invoices ADD CONSTRAINT fk_invoices_202 FOREIGN KEY (hospital_id, patient_link_id) REFERENCES hospital_patient_links (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE invoices ADD CONSTRAINT fk_invoices_203 FOREIGN KEY (hospital_id, admission_id, patient_link_id) REFERENCES admissions (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE invoice_items ADD CONSTRAINT fk_invoice_items_204 FOREIGN KEY (hospital_id, invoice_id) REFERENCES invoices (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE payment_transactions ADD CONSTRAINT fk_payment_transactions_205 FOREIGN KEY (hospital_id, invoice_id) REFERENCES invoices (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE health_reminders ADD CONSTRAINT fk_health_reminders_206 FOREIGN KEY (hospital_id, patient_link_id) REFERENCES hospital_patient_links (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE emergency_requests ADD CONSTRAINT fk_emergency_requests_207 FOREIGN KEY (hospital_id, patient_link_id) REFERENCES hospital_patient_links (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE membership_history ADD CONSTRAINT fk_membership_history_208 FOREIGN KEY (hospital_id, membership_id) REFERENCES memberships (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE sharing_requests ADD CONSTRAINT fk_sharing_requests_209 FOREIGN KEY (hospital_id, portal_link_id, patient_link_id) REFERENCES patient_portal_links (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE sharing_requests ADD CONSTRAINT fk_sharing_requests_210 FOREIGN KEY (hospital_id, consent_id, patient_link_id) REFERENCES consents (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE sharing_requests ADD CONSTRAINT fk_sharing_requests_211 FOREIGN KEY (hospital_id, referral_grant_id, patient_link_id) REFERENCES referral_grants (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE sharing_request_records ADD CONSTRAINT fk_sharing_request_records_212 FOREIGN KEY (hospital_id, request_id, patient_link_id) REFERENCES sharing_requests (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE sharing_request_records ADD CONSTRAINT fk_sharing_request_records_213 FOREIGN KEY (hospital_id, release_id, patient_link_id) REFERENCES record_releases (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

ALTER TABLE vaccinations ADD CONSTRAINT fk_vaccinations_214 FOREIGN KEY (hospital_id, patient_link_id) REFERENCES hospital_patient_links (hospital_id, id) ON DELETE RESTRICT;

ALTER TABLE vaccinations ADD CONSTRAINT fk_vaccinations_215 FOREIGN KEY (hospital_id, admission_id, patient_link_id) REFERENCES admissions (hospital_id, id, patient_link_id) ON DELETE RESTRICT;

CREATE INDEX ix_fk_membership_permissions_001 ON membership_permissions (hospital_id, membership_id);

CREATE INDEX ix_fk_moderation_actions_002 ON moderation_actions (target_membership_id);

CREATE INDEX ix_fk_credential_reviews_003 ON credential_reviews (hospital_id, membership_id);

CREATE INDEX ix_fk_access_requests_004 ON access_requests (hospital_id, membership_id);

CREATE INDEX ix_fk_sessions_005 ON sessions (hospital_id, membership_id, user_id);

CREATE INDEX ix_fk_wards_006 ON wards (hospital_id, department_id);

CREATE INDEX ix_fk_beds_007 ON beds (hospital_id, ward_id);

CREATE INDEX ix_fk_staff_profiles_008 ON staff_profiles (hospital_id, membership_id);

CREATE INDEX ix_fk_staff_department_assignments_009 ON staff_department_assignments (hospital_id, membership_id);

CREATE INDEX ix_fk_staff_department_assignments_010 ON staff_department_assignments (hospital_id, department_id);

CREATE INDEX ix_fk_patient_identifiers_011 ON patient_identifiers (hospital_id, patient_link_id);

CREATE INDEX ix_fk_patient_contacts_012 ON patient_contacts (hospital_id, patient_link_id);

CREATE INDEX ix_fk_identity_match_reviews_013 ON identity_match_reviews (hospital_id, patient_link_id);

CREATE INDEX ix_fk_identity_match_reviews_014 ON identity_match_reviews (hospital_id, candidate_patient_link_id);

CREATE INDEX ix_fk_consents_015 ON consents (hospital_id, patient_link_id);

CREATE INDEX ix_fk_consent_events_016 ON consent_events (hospital_id, consent_id);

CREATE INDEX ix_fk_reception_queue_017 ON reception_queue (hospital_id, patient_link_id);

CREATE INDEX ix_fk_reception_queue_018 ON reception_queue (hospital_id, department_id);

CREATE INDEX ix_fk_reception_queue_019 ON reception_queue (hospital_id, assigned_membership_id);

CREATE INDEX ix_fk_admission_decisions_020 ON admission_decisions (hospital_id, queue_id, patient_link_id);

CREATE INDEX ix_fk_admission_decisions_021 ON admission_decisions (hospital_id, doctor_membership_id);

CREATE INDEX ix_fk_admissions_022 ON admissions (hospital_id, patient_link_id);

CREATE INDEX ix_fk_admissions_023 ON admissions (hospital_id, attending_doctor_id);

CREATE INDEX ix_fk_admissions_024 ON admissions (hospital_id, department_id);

CREATE INDEX ix_fk_admissions_025 ON admissions (hospital_id, decision_id, queue_id, patient_link_id);

CREATE INDEX ix_fk_bed_assignments_026 ON bed_assignments (hospital_id, admission_id);

CREATE INDEX ix_fk_bed_assignments_027 ON bed_assignments (hospital_id, bed_id);

CREATE INDEX ix_fk_care_assignments_028 ON care_assignments (hospital_id, membership_id);

CREATE INDEX ix_fk_care_assignments_029 ON care_assignments (hospital_id, ward_id);

CREATE INDEX ix_fk_care_assignments_030 ON care_assignments (hospital_id, admission_id);

CREATE INDEX ix_fk_ward_tasks_031 ON ward_tasks (hospital_id, ward_id);

CREATE INDEX ix_fk_ward_tasks_032 ON ward_tasks (hospital_id, admission_id);

CREATE INDEX ix_fk_ward_tasks_033 ON ward_tasks (hospital_id, bed_id);

CREATE INDEX ix_fk_ward_tasks_034 ON ward_tasks (hospital_id, assignee_membership_id);

CREATE INDEX ix_fk_wristbands_035 ON wristbands (hospital_id, admission_id);

CREATE INDEX ix_fk_allergies_036 ON allergies (hospital_id, patient_link_id);

CREATE INDEX ix_fk_allergies_037 ON allergies (hospital_id, supersedes_id);

CREATE INDEX ix_fk_conditions_038 ON conditions (hospital_id, patient_link_id);

CREATE INDEX ix_fk_conditions_039 ON conditions (hospital_id, admission_id, patient_link_id);

CREATE INDEX ix_fk_conditions_040 ON conditions (hospital_id, supersedes_id);

CREATE INDEX ix_fk_objects_041 ON objects (hospital_id, patient_link_id);

CREATE INDEX ix_fk_objects_042 ON objects (hospital_id, admission_id, patient_link_id);

CREATE INDEX ix_fk_credential_reviews_043 ON credential_reviews (hospital_id, object_id);

CREATE INDEX ix_fk_upload_intents_044 ON upload_intents (hospital_id, object_id);

CREATE INDEX ix_fk_portal_link_requests_045 ON portal_link_requests (hospital_id, patient_link_id);

CREATE INDEX ix_fk_portal_link_requests_046 ON portal_link_requests (hospital_id, proof_object_id, patient_link_id);

CREATE INDEX ix_fk_patient_portal_links_047 ON patient_portal_links (hospital_id, patient_link_id);

CREATE INDEX ix_fk_patient_portal_links_048 ON patient_portal_links (hospital_id, request_id);

CREATE INDEX ix_fk_caregiver_grants_049 ON caregiver_grants (hospital_id, patient_link_id);

CREATE INDEX ix_fk_caregiver_grants_050 ON caregiver_grants (hospital_id, portal_link_id, patient_link_id);

CREATE INDEX ix_fk_caregiver_grants_051 ON caregiver_grants (hospital_id, consent_id, patient_link_id);

CREATE INDEX ix_fk_clinical_record_versions_052 ON clinical_record_versions (hospital_id, patient_link_id);

CREATE INDEX ix_fk_clinical_record_versions_053 ON clinical_record_versions (hospital_id, admission_id, patient_link_id);

CREATE INDEX ix_fk_clinical_record_versions_054 ON clinical_record_versions (hospital_id, object_id, patient_link_id);

CREATE INDEX ix_fk_clinical_record_versions_055 ON clinical_record_versions (hospital_id, supersedes_id, patient_link_id);

CREATE INDEX ix_fk_record_releases_056 ON record_releases (hospital_id, record_version_id, patient_link_id);

CREATE INDEX ix_fk_caregiver_grant_records_057 ON caregiver_grant_records (hospital_id, grant_id, patient_link_id);

CREATE INDEX ix_fk_caregiver_grant_records_058 ON caregiver_grant_records (hospital_id, release_id, patient_link_id);

CREATE INDEX ix_fk_correction_requests_059 ON correction_requests (hospital_id, patient_link_id);

CREATE INDEX ix_fk_correction_requests_060 ON correction_requests (hospital_id, record_version_id, patient_link_id);

CREATE INDEX ix_fk_correction_requests_061 ON correction_requests (hospital_id, corrected_record_version_id, patient_link_id);

CREATE INDEX ix_fk_patient_uploaded_documents_062 ON patient_uploaded_documents (hospital_id, object_id, patient_link_id);

CREATE INDEX ix_fk_patient_uploaded_documents_063 ON patient_uploaded_documents (hospital_id, record_version_id, patient_link_id);

CREATE INDEX ix_fk_download_tickets_064 ON download_tickets (hospital_id, release_id, patient_link_id);

CREATE INDEX ix_fk_patient_notifications_065 ON patient_notifications (hospital_id, patient_link_id);

CREATE INDEX ix_fk_support_tickets_066 ON support_tickets (hospital_id, patient_link_id);

CREATE INDEX ix_fk_product_barcodes_067 ON product_barcodes (hospital_id, medication_id);

CREATE INDEX ix_fk_medication_orders_068 ON medication_orders (hospital_id, admission_id);

CREATE INDEX ix_fk_medication_orders_069 ON medication_orders (hospital_id, prescriber_membership_id);

CREATE INDEX ix_fk_medication_orders_070 ON medication_orders (hospital_id, medication_id);

CREATE INDEX ix_fk_medication_order_revisions_071 ON medication_order_revisions (hospital_id, order_id, admission_id);

CREATE INDEX ix_fk_medication_order_revisions_072 ON medication_order_revisions (hospital_id, medication_id);

CREATE INDEX ix_fk_medication_orders_073 ON medication_orders (hospital_id, current_revision_id, id, admission_id);

CREATE INDEX ix_fk_medication_dose_events_074 ON medication_dose_events (hospital_id, order_revision_id, order_id, admission_id);

CREATE INDEX ix_fk_medication_dose_events_075 ON medication_dose_events (hospital_id, reservation_owner_id);

CREATE INDEX ix_fk_medication_scan_events_076 ON medication_scan_events (hospital_id, admission_id);

CREATE INDEX ix_fk_medication_scan_events_077 ON medication_scan_events (hospital_id, dose_event_id, admission_id);

CREATE INDEX ix_fk_medication_scan_events_078 ON medication_scan_events (hospital_id, wristband_id, admission_id);

CREATE INDEX ix_fk_medication_scan_events_079 ON medication_scan_events (hospital_id, barcode_id);

CREATE INDEX ix_fk_medication_scan_events_080 ON medication_scan_events (hospital_id, nurse_membership_id);

CREATE INDEX ix_fk_medication_administration_records_081 ON medication_administration_records (hospital_id, dose_event_id, admission_id);

CREATE INDEX ix_fk_medication_administration_records_082 ON medication_administration_records (hospital_id, actor_membership_id);

CREATE INDEX ix_fk_medication_administration_records_083 ON medication_administration_records (hospital_id, supersedes_id, dose_event_id);

CREATE INDEX ix_fk_dose_reconciliations_084 ON dose_reconciliations (hospital_id, dose_event_id);

CREATE INDEX ix_fk_dose_reconciliations_085 ON dose_reconciliations (hospital_id, reviewer_membership_id);

CREATE INDEX ix_fk_dose_reconciliations_086 ON dose_reconciliations (hospital_id, second_reviewer_membership_id);

CREATE INDEX ix_fk_downtime_incidents_087 ON downtime_incidents (hospital_id, ward_id);

CREATE INDEX ix_fk_downtime_entries_088 ON downtime_entries (hospital_id, incident_id);

CREATE INDEX ix_fk_downtime_entries_089 ON downtime_entries (hospital_id, admission_id);

CREATE INDEX ix_fk_downtime_entries_090 ON downtime_entries (hospital_id, dose_event_id, admission_id);

CREATE INDEX ix_fk_downtime_entries_091 ON downtime_entries (hospital_id, reconciliation_id);

CREATE INDEX ix_fk_interaction_checks_092 ON interaction_checks (hospital_id, admission_id);

CREATE INDEX ix_fk_interaction_checks_093 ON interaction_checks (hospital_id, order_id, admission_id);

CREATE INDEX ix_fk_diet_orders_094 ON diet_orders (hospital_id, admission_id);

CREATE INDEX ix_fk_diet_orders_095 ON diet_orders (hospital_id, ordered_by_membership_id);

CREATE INDEX ix_fk_diet_logs_096 ON diet_logs (hospital_id, admission_id);

CREATE INDEX ix_fk_diet_logs_097 ON diet_logs (hospital_id, diet_order_id);

CREATE INDEX ix_fk_diet_logs_098 ON diet_logs (hospital_id, interaction_check_id);

CREATE INDEX ix_fk_device_credentials_099 ON device_credentials (hospital_id, device_id);

CREATE INDEX ix_fk_device_assignments_100 ON device_assignments (hospital_id, device_id);

CREATE INDEX ix_fk_device_assignments_101 ON device_assignments (hospital_id, admission_id);

CREATE INDEX ix_fk_device_health_events_102 ON device_health_events (hospital_id, device_id);

CREATE INDEX ix_fk_telemetry_ingest_dedupe_103 ON telemetry_ingest_dedupe (hospital_id, device_id);

CREATE INDEX ix_fk_telemetry_samples_104 ON telemetry_samples (hospital_id, assignment_id, device_id, admission_id);

CREATE INDEX ix_fk_telemetry_samples_105 ON telemetry_samples (device_id, boot_id, sequence_no);

CREATE INDEX ix_fk_telemetry_rejections_106 ON telemetry_rejections (hospital_id, device_id);

CREATE INDEX ix_fk_ecg_artifacts_107 ON ecg_artifacts (hospital_id, admission_id);

CREATE INDEX ix_fk_ecg_artifacts_108 ON ecg_artifacts (hospital_id, device_id);

CREATE INDEX ix_fk_ecg_artifacts_109 ON ecg_artifacts (hospital_id, assignment_id);

CREATE INDEX ix_fk_ecg_artifacts_110 ON ecg_artifacts (hospital_id, object_id);

CREATE INDEX ix_fk_observations_111 ON observations (hospital_id, admission_id, patient_link_id);

CREATE INDEX ix_fk_observations_112 ON observations (hospital_id, device_id);

CREATE INDEX ix_fk_observations_113 ON observations (hospital_id, supersedes_id, admission_id);

CREATE INDEX ix_fk_news2_assessments_114 ON news2_assessments (hospital_id, admission_id);

CREATE INDEX ix_fk_news2_inputs_115 ON news2_inputs (hospital_id, assessment_id, admission_id);

CREATE INDEX ix_fk_news2_inputs_116 ON news2_inputs (hospital_id, observation_id, admission_id);

CREATE INDEX ix_fk_alerts_117 ON alerts (hospital_id, admission_id);

CREATE INDEX ix_fk_alerts_118 ON alerts (hospital_id, news2_assessment_id, admission_id);

CREATE INDEX ix_fk_alerts_119 ON alerts (hospital_id, policy_id);

CREATE INDEX ix_fk_alerts_120 ON alerts (hospital_id, owner_membership_id);

CREATE INDEX ix_fk_alert_actions_121 ON alert_actions (hospital_id, alert_id);

CREATE INDEX ix_fk_notification_deliveries_122 ON notification_deliveries (hospital_id, alert_id);

CREATE INDEX ix_fk_notification_deliveries_123 ON notification_deliveries (hospital_id, patient_notification_id);

CREATE INDEX ix_fk_shifts_124 ON shifts (hospital_id, ward_id);

CREATE INDEX ix_fk_shifts_125 ON shifts (hospital_id, nurse_membership_id);

CREATE INDEX ix_fk_handoffs_126 ON handoffs (hospital_id, ward_id);

CREATE INDEX ix_fk_handoffs_127 ON handoffs (hospital_id, outgoing_shift_id);

CREATE INDEX ix_fk_handoffs_128 ON handoffs (hospital_id, incoming_shift_id);

CREATE INDEX ix_fk_handoffs_129 ON handoffs (hospital_id, outgoing_membership_id);

CREATE INDEX ix_fk_handoffs_130 ON handoffs (hospital_id, incoming_membership_id);

CREATE INDEX ix_fk_handoff_versions_131 ON handoff_versions (hospital_id, handoff_id);

CREATE INDEX ix_fk_handoff_items_132 ON handoff_items (hospital_id, handoff_version_id);

CREATE INDEX ix_fk_handoff_items_133 ON handoff_items (hospital_id, admission_id);

CREATE INDEX ix_fk_handoff_items_134 ON handoff_items (hospital_id, dose_event_id, admission_id);

CREATE INDEX ix_fk_handoff_items_135 ON handoff_items (hospital_id, alert_id);

CREATE INDEX ix_fk_clinical_reports_136 ON clinical_reports (hospital_id, admission_id, patient_link_id);

CREATE INDEX ix_fk_clinical_reports_137 ON clinical_reports (hospital_id, object_id, patient_link_id);

CREATE INDEX ix_fk_clinical_reports_138 ON clinical_reports (hospital_id, ordering_doctor_id);

CREATE INDEX ix_fk_report_extraction_jobs_139 ON report_extraction_jobs (hospital_id, report_id);

CREATE INDEX ix_fk_report_revisions_140 ON report_revisions (hospital_id, report_id, patient_link_id);

CREATE INDEX ix_fk_report_revisions_141 ON report_revisions (hospital_id, supersedes_id, report_id, patient_link_id);

CREATE INDEX ix_fk_clinical_reports_142 ON clinical_reports (hospital_id, current_revision_id, id, patient_link_id);

CREATE INDEX ix_fk_report_fields_143 ON report_fields (hospital_id, report_revision_id);

CREATE INDEX ix_fk_report_field_candidates_144 ON report_field_candidates (hospital_id, report_field_id);

CREATE INDEX ix_fk_report_field_candidates_145 ON report_field_candidates (hospital_id, extraction_job_id);

CREATE INDEX ix_fk_report_review_events_146 ON report_review_events (hospital_id, report_revision_id);

CREATE INDEX ix_fk_report_review_events_147 ON report_review_events (hospital_id, field_id);

CREATE INDEX ix_fk_voice_jobs_148 ON voice_jobs (hospital_id, admission_id, patient_link_id);

CREATE INDEX ix_fk_voice_jobs_149 ON voice_jobs (hospital_id, audio_object_id, patient_link_id);

CREATE INDEX ix_fk_clinical_notes_150 ON clinical_notes (hospital_id, admission_id, patient_link_id);

CREATE INDEX ix_fk_clinical_notes_151 ON clinical_notes (hospital_id, voice_job_id);

CREATE INDEX ix_fk_clinical_notes_152 ON clinical_notes (hospital_id, supersedes_id, patient_link_id);

CREATE INDEX ix_fk_timeline_events_153 ON timeline_events (hospital_id, admission_id, patient_link_id);

CREATE INDEX ix_fk_timeline_events_154 ON timeline_events (hospital_id, record_version_id, patient_link_id);

CREATE INDEX ix_fk_discharge_summaries_155 ON discharge_summaries (hospital_id, admission_id, patient_link_id);

CREATE INDEX ix_fk_discharge_summaries_156 ON discharge_summaries (hospital_id, pdf_object_id, patient_link_id);

CREATE INDEX ix_fk_discharge_summaries_157 ON discharge_summaries (hospital_id, supersedes_id, patient_link_id);

CREATE INDEX ix_fk_fhir_exports_158 ON fhir_exports (hospital_id, patient_link_id);

CREATE INDEX ix_fk_fhir_exports_159 ON fhir_exports (hospital_id, admission_id, patient_link_id);

CREATE INDEX ix_fk_fhir_exports_160 ON fhir_exports (hospital_id, consent_id, patient_link_id);

CREATE INDEX ix_fk_fhir_exports_161 ON fhir_exports (hospital_id, bundle_object_id, patient_link_id);

CREATE INDEX ix_fk_referrals_162 ON referrals (hospital_id, patient_link_id);

CREATE INDEX ix_fk_referrals_163 ON referrals (hospital_id, admission_id, patient_link_id);

CREATE INDEX ix_fk_referrals_164 ON referrals (hospital_id, referring_membership_id);

CREATE INDEX ix_fk_referrals_165 ON referrals (hospital_id, discharge_summary_id, patient_link_id);

CREATE INDEX ix_fk_referrals_166 ON referrals (hospital_id, pdf_object_id, patient_link_id);

CREATE INDEX ix_fk_referral_grants_167 ON referral_grants (hospital_id, referral_id, patient_link_id);

CREATE INDEX ix_fk_referral_grants_168 ON referral_grants (hospital_id, consent_id, patient_link_id);

CREATE INDEX ix_fk_referral_grant_records_169 ON referral_grant_records (hospital_id, grant_id, patient_link_id);

CREATE INDEX ix_fk_referral_grant_records_170 ON referral_grant_records (hospital_id, record_version_id, patient_link_id);

CREATE INDEX ix_fk_referral_sessions_171 ON referral_sessions (hospital_id, grant_id, patient_link_id);

CREATE INDEX ix_fk_referral_access_events_172 ON referral_access_events (hospital_id, referral_session_id);

CREATE INDEX ix_fk_referral_access_events_173 ON referral_access_events (hospital_id, record_version_id);

CREATE INDEX ix_fk_rag_documents_174 ON rag_documents (hospital_id, record_version_id, patient_link_id);

CREATE INDEX ix_fk_rag_chunks_175 ON rag_chunks (hospital_id, document_id, patient_link_id);

CREATE INDEX ix_fk_rag_conversations_176 ON rag_conversations (hospital_id, patient_link_id);

CREATE INDEX ix_fk_rag_conversations_177 ON rag_conversations (hospital_id, referral_session_id, patient_link_id);

CREATE INDEX ix_fk_rag_conversations_178 ON rag_conversations (hospital_id, portal_link_id, patient_link_id);

CREATE INDEX ix_fk_rag_conversations_179 ON rag_conversations (hospital_id, caregiver_grant_id, patient_link_id);

CREATE INDEX ix_fk_rag_queries_180 ON rag_queries (hospital_id, conversation_id, patient_link_id);

CREATE INDEX ix_fk_rag_citations_181 ON rag_citations (hospital_id, query_id, patient_link_id);

CREATE INDEX ix_fk_rag_citations_182 ON rag_citations (hospital_id, chunk_id, patient_link_id);

CREATE INDEX ix_fk_rag_feedback_183 ON rag_feedback (hospital_id, query_id);

CREATE INDEX ix_fk_inference_jobs_184 ON inference_jobs (hospital_id, patient_link_id);

CREATE INDEX ix_fk_inference_jobs_185 ON inference_jobs (hospital_id, admission_id, patient_link_id);

CREATE INDEX ix_fk_inference_jobs_186 ON inference_jobs (hospital_id, input_object_id, patient_link_id);

CREATE INDEX ix_fk_inference_jobs_187 ON inference_jobs (hospital_id, explanation_object_id, patient_link_id);

CREATE INDEX ix_fk_inference_reviews_188 ON inference_reviews (hospital_id, inference_job_id);

CREATE INDEX ix_fk_inference_reviews_189 ON inference_reviews (hospital_id, reviewer_membership_id);

CREATE INDEX ix_fk_advisory_jobs_190 ON advisory_jobs (hospital_id, patient_link_id);

CREATE INDEX ix_fk_advisory_jobs_191 ON advisory_jobs (hospital_id, admission_id, patient_link_id);

CREATE INDEX ix_fk_advisory_reviews_192 ON advisory_reviews (hospital_id, advisory_job_id);

CREATE INDEX ix_fk_advisory_reviews_193 ON advisory_reviews (hospital_id, reviewer_membership_id);

CREATE INDEX ix_fk_sync_operations_194 ON sync_operations (hospital_id, admission_id);

CREATE INDEX ix_fk_audit_events_195 ON audit_events (hospital_id, actor_membership_id);

CREATE INDEX ix_fk_audit_events_196 ON audit_events (hospital_id, actor_device_id);

CREATE INDEX ix_fk_appointment_slots_197 ON appointment_slots (hospital_id, doctor_membership_id);

CREATE INDEX ix_fk_appointment_slots_198 ON appointment_slots (hospital_id, department_id);

CREATE INDEX ix_fk_appointments_199 ON appointments (hospital_id, patient_link_id);

CREATE INDEX ix_fk_appointments_200 ON appointments (hospital_id, slot_id);

CREATE INDEX ix_fk_appointments_201 ON appointments (hospital_id, admission_id, patient_link_id);

CREATE INDEX ix_fk_invoices_202 ON invoices (hospital_id, patient_link_id);

CREATE INDEX ix_fk_invoices_203 ON invoices (hospital_id, admission_id, patient_link_id);

CREATE INDEX ix_fk_invoice_items_204 ON invoice_items (hospital_id, invoice_id);

CREATE INDEX ix_fk_payment_transactions_205 ON payment_transactions (hospital_id, invoice_id);

CREATE INDEX ix_fk_health_reminders_206 ON health_reminders (hospital_id, patient_link_id);

CREATE INDEX ix_fk_emergency_requests_207 ON emergency_requests (hospital_id, patient_link_id);

CREATE INDEX ix_fk_membership_history_208 ON membership_history (hospital_id, membership_id);

CREATE INDEX ix_fk_sharing_requests_209 ON sharing_requests (hospital_id, portal_link_id, patient_link_id);

CREATE INDEX ix_fk_sharing_requests_210 ON sharing_requests (hospital_id, consent_id, patient_link_id);

CREATE INDEX ix_fk_sharing_requests_211 ON sharing_requests (hospital_id, referral_grant_id, patient_link_id);

CREATE INDEX ix_fk_sharing_request_records_212 ON sharing_request_records (hospital_id, request_id, patient_link_id);

CREATE INDEX ix_fk_sharing_request_records_213 ON sharing_request_records (hospital_id, release_id, patient_link_id);

CREATE INDEX ix_fk_vaccinations_214 ON vaccinations (hospital_id, patient_link_id);

CREATE INDEX ix_fk_vaccinations_215 ON vaccinations (hospital_id, admission_id, patient_link_id);

CREATE INDEX ix_query_memberships ON memberships (hospital_id, status);

CREATE INDEX ix_query_hospital_patient_links ON hospital_patient_links (hospital_id, patient_id);

CREATE INDEX ix_query_admissions ON admissions (hospital_id, patient_link_id, admitted_at DESC);

CREATE INDEX ix_query_record_releases ON record_releases (hospital_id, patient_link_id, released_at DESC);

CREATE INDEX ix_query_clinical_record_versions ON clinical_record_versions (hospital_id, patient_link_id, event_at DESC);

CREATE INDEX ix_query_patient_notifications ON patient_notifications (hospital_id, user_id, read_at);

CREATE INDEX ix_query_clinical_reports ON clinical_reports (hospital_id, patient_link_id, report_at DESC);

CREATE INDEX ix_query_sessions ON sessions (user_id, revoked_at, expires_at);

CREATE INDEX ix_query_referral_grants ON referral_grants (expires_at);

CREATE INDEX ix_query_caregiver_grants ON caregiver_grants (caregiver_user_id, status, expires_at);

CREATE INDEX ix_query_inference_jobs ON inference_jobs (hospital_id, status);

CREATE INDEX ix_query_reception_queue ON reception_queue (hospital_id, queue_date, status);

-- ============================================================================
-- 11 | Triggers, safety rules, and safe defaults
-- ============================================================================

-- Version increments on every update. Use WHERE version = expected_version for optimistic concurrency.
CREATE FUNCTION touch_version() RETURNS trigger LANGUAGE plpgsql
SET search_path = pg_catalog, medishield AS $$
BEGIN
    NEW.updated_at := clock_timestamp();
    NEW.version := OLD.version + 1;
    RETURN NEW;
END;
$$;
CREATE FUNCTION reject_mutation() RETURNS trigger LANGUAGE plpgsql
SET search_path = pg_catalog, medishield AS $$
BEGIN
    RAISE EXCEPTION 'Append-only history cannot be modified: %', TG_TABLE_NAME USING ERRCODE = '23514';
END;
$$;
CREATE FUNCTION protect_signed_record() RETURNS trigger LANGUAGE plpgsql
SET search_path = pg_catalog, medishield AS $$
BEGIN
    IF OLD.status = 'SIGNED' THEN
        RAISE EXCEPTION 'Signed clinical content requires a new amendment' USING ERRCODE = '23514';
    END IF;
    IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
    RETURN NEW;
END;
$$;
CREATE FUNCTION protect_verified_revision() RETURNS trigger LANGUAGE plpgsql
SET search_path = pg_catalog, medishield AS $$
BEGIN
    IF OLD.verification_status = 'VERIFIED' THEN
        RAISE EXCEPTION 'Verified revision requires a new amendment' USING ERRCODE = '23514';
    END IF;
    IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
    RETURN NEW;
END;
$$;
-- All field editors lock the revision before modifying fields; verification must use
-- the same lock order. Backend signs only after reviewing every consequential field.
CREATE FUNCTION protect_verified_report_fields() RETURNS trigger LANGUAGE plpgsql
SET search_path = pg_catalog, medishield AS $$
DECLARE v_revision uuid; v_hospital uuid; v_status text;
BEGIN
    IF TG_OP = 'UPDATE' AND (NEW.report_revision_id, NEW.hospital_id) IS DISTINCT FROM (OLD.report_revision_id, OLD.hospital_id) THEN
        RAISE EXCEPTION 'Cannot move fields between report revisions';
    END IF;
    IF TG_OP = 'DELETE' THEN v_revision := OLD.report_revision_id; v_hospital := OLD.hospital_id;
    ELSE v_revision := NEW.report_revision_id; v_hospital := NEW.hospital_id; END IF;
    SELECT verification_status INTO v_status FROM report_revisions
      WHERE hospital_id = v_hospital AND id = v_revision FOR UPDATE;
    IF NOT FOUND OR v_status = 'VERIFIED' THEN
        RAISE EXCEPTION 'Report revision missing or already verified';
    END IF;
    IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER guard_report_fields BEFORE INSERT OR UPDATE OR DELETE ON report_fields
FOR EACH ROW EXECUTE FUNCTION protect_verified_report_fields();
CREATE FUNCTION check_report_verification() RETURNS trigger LANGUAGE plpgsql
SET search_path = pg_catalog, medishield AS $$
BEGIN
    IF NEW.verification_status = 'VERIFIED' AND (
        NOT EXISTS (SELECT 1 FROM report_fields WHERE hospital_id=NEW.hospital_id AND report_revision_id=NEW.id)
        OR EXISTS (SELECT 1 FROM report_fields WHERE hospital_id=NEW.hospital_id AND report_revision_id=NEW.id
          AND is_clinically_consequential AND (review_status NOT IN ('CONFIRMED','CORRECTED') OR reviewed_by IS NULL OR reviewed_at IS NULL))
    ) THEN RAISE EXCEPTION 'Review report fields before verification'; END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER guard_report_verification BEFORE INSERT OR UPDATE ON report_revisions
FOR EACH ROW EXECUTE FUNCTION check_report_verification();
CREATE FUNCTION check_verified_release() RETURNS trigger LANGUAGE plpgsql
SET search_path = pg_catalog, medishield AS $$
BEGIN
    IF TG_OP = 'UPDATE' AND (NEW.hospital_id, NEW.patient_link_id, NEW.record_version_id, NEW.released_at, NEW.released_by)
       IS DISTINCT FROM (OLD.hospital_id, OLD.patient_link_id, OLD.record_version_id, OLD.released_at, OLD.released_by) THEN
        RAISE EXCEPTION 'Release source is immutable';
    END IF;
    IF TG_OP = 'UPDATE' AND OLD.withdrawn_at IS NOT NULL AND NEW.withdrawn_at IS DISTINCT FROM OLD.withdrawn_at THEN
        RAISE EXCEPTION 'A withdrawn release cannot be reactivated';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM clinical_record_versions WHERE hospital_id=NEW.hospital_id
      AND id=NEW.record_version_id AND patient_link_id=NEW.patient_link_id AND verification_status='VERIFIED') THEN
        RAISE EXCEPTION 'Only a verified record revision can be released';
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER guard_record_release BEFORE INSERT OR UPDATE ON record_releases
FOR EACH ROW EXECUTE FUNCTION check_verified_release();
CREATE FUNCTION guard_dose_transition() RETURNS trigger LANGUAGE plpgsql
SET search_path = pg_catalog, medishield AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.state <> 'SCHEDULED' OR NEW.reservation_owner_id IS NOT NULL OR NEW.reservation_token_digest IS NOT NULL OR NEW.reserved_at IS NOT NULL OR NEW.reservation_expires_at IS NOT NULL OR NEW.started_at IS NOT NULL THEN RAISE EXCEPTION 'New dose must start scheduled with no reservation'; END IF;
        RETURN NEW;
    END IF;
    IF (NEW.hospital_id, NEW.order_id, NEW.order_revision_id, NEW.admission_id, NEW.occurrence_key, NEW.due_at)
       IS DISTINCT FROM (OLD.hospital_id, OLD.order_id, OLD.order_revision_id, OLD.admission_id, OLD.occurrence_key, OLD.due_at) THEN
        RAISE EXCEPTION 'Dose identity is immutable';
    END IF;
    IF NEW.state = OLD.state THEN
        IF (NEW.reservation_owner_id, NEW.reservation_token_digest, NEW.reserved_at, NEW.reservation_expires_at, NEW.started_at)
          IS DISTINCT FROM (OLD.reservation_owner_id, OLD.reservation_token_digest, OLD.reserved_at, OLD.reservation_expires_at, OLD.started_at) THEN
            RAISE EXCEPTION 'Cannot rewrite reservation or start evidence';
        END IF;
        RETURN NEW;
    END IF;
    IF NOT (
        (OLD.state='SCHEDULED' AND NEW.state IN ('RESERVED','CANCELLED')) OR
        (OLD.state='RESERVED' AND NEW.state IN ('SCHEDULED','IN_PROGRESS','REVIEW_REQUIRED')) OR
        (OLD.state='IN_PROGRESS' AND NEW.state IN ('ADMINISTERED','REVIEW_REQUIRED')) OR
        (OLD.state='REVIEW_REQUIRED' AND NEW.state IN ('ADMINISTERED','SCHEDULED','NOT_GIVEN'))
    ) THEN RAISE EXCEPTION 'Invalid medication state change: % to %', OLD.state, NEW.state; END IF;
    IF NEW.state='RESERVED' AND (NEW.reservation_expires_at IS NULL OR NEW.reservation_expires_at <= clock_timestamp()) THEN
        RAISE EXCEPTION 'Reservation already expired';
    END IF;
    IF OLD.state='RESERVED' AND NEW.state='IN_PROGRESS' THEN
        IF OLD.reservation_expires_at IS NULL OR OLD.reservation_expires_at <= clock_timestamp()
           OR NEW.started_at IS NULL
           OR (NEW.reservation_owner_id, NEW.reservation_token_digest, NEW.reserved_at, NEW.reservation_expires_at)
           IS DISTINCT FROM (OLD.reservation_owner_id, OLD.reservation_token_digest, OLD.reserved_at, OLD.reservation_expires_at) THEN
            RAISE EXCEPTION 'Invalid or expired reservation';
        END IF;
    END IF;
    IF NEW.state='SCHEDULED' AND (NEW.reservation_owner_id IS NOT NULL OR NEW.reservation_token_digest IS NOT NULL OR NEW.reserved_at IS NOT NULL OR NEW.reservation_expires_at IS NOT NULL OR NEW.started_at IS NOT NULL) THEN
        RAISE EXCEPTION 'Reissued dose must clear active reservation fields';
    END IF;
    -- Actor permissions, verified unused release, and fresh reconciliation evidence
    -- must be checked by authoritative backend under the admission/order/dose locks.
    RETURN NEW;
END;
$$;
CREATE TRIGGER guard_medication_dose BEFORE INSERT OR UPDATE ON medication_dose_events
FOR EACH ROW EXECUTE FUNCTION guard_dose_transition();
-- Recheck final state at commit, so a final administration record and dose update
-- may be written in either order in the same transaction.
CREATE FUNCTION check_dose_outcome() RETURNS trigger LANGUAGE plpgsql
SET search_path = pg_catalog, medishield AS $$
DECLARE v_dose uuid; v_hospital uuid; v_state text; v_confirmed integer;
BEGIN
    IF TG_TABLE_NAME='medication_dose_events' THEN v_dose:=NEW.id; v_hospital:=NEW.hospital_id;
    ELSIF TG_OP='DELETE' THEN v_dose:=OLD.dose_event_id; v_hospital:=OLD.hospital_id;
    ELSE v_dose:=NEW.dose_event_id; v_hospital:=NEW.hospital_id; END IF;
    SELECT state INTO v_state FROM medication_dose_events WHERE hospital_id=v_hospital AND id=v_dose FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Dose missing'; END IF;
    SELECT count(*) INTO v_confirmed FROM medication_administration_records WHERE hospital_id=v_hospital
       AND dose_event_id=v_dose AND outcome='ADMINISTERED' AND superseded_at IS NULL;
    IF (v_state='ADMINISTERED' AND v_confirmed<>1) OR (v_state<>'ADMINISTERED' AND v_confirmed<>0) THEN
        RAISE EXCEPTION 'Confirmed administration and dose state must agree';
    END IF;
    RETURN NULL;
END;
$$;
CREATE CONSTRAINT TRIGGER check_dose_final AFTER INSERT OR UPDATE ON medication_dose_events
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION check_dose_outcome();
CREATE CONSTRAINT TRIGGER check_administration_final AFTER INSERT OR UPDATE OR DELETE ON medication_administration_records
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION check_dose_outcome();
CREATE FUNCTION protect_administration_history() RETURNS trigger LANGUAGE plpgsql
SET search_path = pg_catalog, medishield AS $$
BEGIN
    IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Administration history cannot be deleted'; END IF;
    IF OLD.superseded_at IS NOT NULL OR NEW.superseded_at IS NULL OR
       (to_jsonb(NEW) - 'superseded_at') IS DISTINCT FROM (to_jsonb(OLD) - 'superseded_at') THEN
       RAISE EXCEPTION 'Administration amendment must preserve original details';
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER guard_administration_history BEFORE UPDATE OR DELETE ON medication_administration_records
FOR EACH ROW EXECUTE FUNCTION protect_administration_history();
-- Non-overlapping assignment range is enforced by exclusion constraints. Reject
-- telemetry that falls outside its referenced assignment at time of insert.
CREATE FUNCTION check_telemetry_binding() RETURNS trigger LANGUAGE plpgsql
SET search_path = pg_catalog, medishield AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM device_assignments WHERE hospital_id=NEW.hospital_id AND id=NEW.assignment_id
      AND device_id=NEW.device_id AND admission_id=NEW.admission_id
      AND starts_at<=NEW.measured_at AND (ends_at IS NULL OR NEW.measured_at<ends_at)) THEN
        RAISE EXCEPTION 'Telemetry outside device assignment';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM telemetry_ingest_dedupe WHERE hospital_id=NEW.hospital_id AND device_id=NEW.device_id
      AND boot_id=NEW.boot_id AND sequence_no=NEW.sequence_no AND measured_at=NEW.measured_at) THEN
        RAISE EXCEPTION 'Telemetry missing matching dedupe entry';
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER guard_telemetry_binding BEFORE INSERT ON telemetry_samples
FOR EACH ROW EXECUTE FUNCTION check_telemetry_binding();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON roles FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON permissions FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON platform_role_assignments FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON platform_settings FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON hospital_applications FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON hospitals FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON onboarding_documents FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON hospital_settings FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON hospital_setup_items FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON memberships FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON membership_permissions FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON invitations FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON credential_reviews FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON access_requests FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON sessions FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON auth_challenges FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON password_reset_tokens FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON mfa_credentials FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON user_preferences FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON departments FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON wards FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON beds FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON staff_profiles FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON staff_department_assignments FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON patients FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON hospital_patient_links FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON patient_identifiers FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON patient_contacts FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON identity_match_reviews FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON consents FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON reception_queue FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON admission_decisions FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON admissions FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON bed_assignments FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON care_assignments FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON ward_tasks FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON wristbands FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON allergies FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON conditions FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON objects FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON upload_intents FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON portal_link_requests FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON patient_portal_links FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON caregiver_grants FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON record_releases FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON correction_requests FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON patient_uploaded_documents FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON download_tickets FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON patient_notifications FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON support_tickets FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON medication_catalog FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON product_barcodes FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON medication_orders FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON medication_dose_events FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON downtime_incidents FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON downtime_entries FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON interaction_rule_versions FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON interaction_checks FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON diet_orders FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON diet_logs FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON devices FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON device_credentials FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON device_assignments FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON ecg_artifacts FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON alert_policies FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON alerts FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON notification_deliveries FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON shifts FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON handoffs FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON clinical_reports FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON report_extraction_jobs FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON report_fields FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON voice_jobs FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON clinical_notes FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON discharge_summaries FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON fhir_exports FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON referrals FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON referral_grants FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON referral_sessions FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON embedding_models FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON rag_documents FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON rag_chunks FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON rag_conversations FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON rag_queries FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON model_registry FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON research_datasets FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON model_training_runs FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON inference_jobs FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON advisory_jobs FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON sync_operations FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON idempotency_records FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON outbox_events FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON background_jobs FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON webhook_deliveries FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON integration_connections FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON benchmark_runs FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON appointment_slots FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON appointments FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON invoices FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON invoice_items FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON payment_transactions FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON health_reminders FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON emergency_requests FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON portal_account_roles FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON account_email_changes FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON sharing_requests FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON vaccinations FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER z_touch_version BEFORE UPDATE ON audit_exports FOR EACH ROW EXECUTE FUNCTION touch_version();

CREATE TRIGGER guard_append_only BEFORE UPDATE OR DELETE ON onboarding_reviews FOR EACH ROW EXECUTE FUNCTION reject_mutation();

CREATE TRIGGER guard_append_only BEFORE UPDATE OR DELETE ON hospital_status_history FOR EACH ROW EXECUTE FUNCTION reject_mutation();

CREATE TRIGGER guard_append_only BEFORE UPDATE OR DELETE ON moderation_actions FOR EACH ROW EXECUTE FUNCTION reject_mutation();

CREATE TRIGGER guard_append_only BEFORE UPDATE OR DELETE ON consent_events FOR EACH ROW EXECUTE FUNCTION reject_mutation();

CREATE TRIGGER guard_append_only BEFORE UPDATE OR DELETE ON clinical_record_versions FOR EACH ROW EXECUTE FUNCTION reject_mutation();

CREATE TRIGGER guard_append_only BEFORE UPDATE OR DELETE ON medication_order_revisions FOR EACH ROW EXECUTE FUNCTION reject_mutation();

CREATE TRIGGER guard_append_only BEFORE UPDATE OR DELETE ON medication_scan_events FOR EACH ROW EXECUTE FUNCTION reject_mutation();

CREATE TRIGGER guard_append_only BEFORE UPDATE OR DELETE ON dose_reconciliations FOR EACH ROW EXECUTE FUNCTION reject_mutation();

CREATE TRIGGER guard_append_only BEFORE UPDATE OR DELETE ON interaction_rules FOR EACH ROW EXECUTE FUNCTION reject_mutation();

CREATE TRIGGER guard_append_only BEFORE UPDATE OR DELETE ON device_health_events FOR EACH ROW EXECUTE FUNCTION reject_mutation();

CREATE TRIGGER guard_append_only BEFORE UPDATE OR DELETE ON news2_rule_versions FOR EACH ROW EXECUTE FUNCTION reject_mutation();

CREATE TRIGGER guard_append_only BEFORE UPDATE OR DELETE ON news2_assessments FOR EACH ROW EXECUTE FUNCTION reject_mutation();

CREATE TRIGGER guard_append_only BEFORE UPDATE OR DELETE ON alert_actions FOR EACH ROW EXECUTE FUNCTION reject_mutation();

CREATE TRIGGER guard_append_only BEFORE UPDATE OR DELETE ON handoff_versions FOR EACH ROW EXECUTE FUNCTION reject_mutation();

CREATE TRIGGER guard_append_only BEFORE UPDATE OR DELETE ON handoff_items FOR EACH ROW EXECUTE FUNCTION reject_mutation();

CREATE TRIGGER guard_append_only BEFORE UPDATE OR DELETE ON report_field_candidates FOR EACH ROW EXECUTE FUNCTION reject_mutation();

CREATE TRIGGER guard_append_only BEFORE UPDATE OR DELETE ON report_review_events FOR EACH ROW EXECUTE FUNCTION reject_mutation();

CREATE TRIGGER guard_append_only BEFORE UPDATE OR DELETE ON timeline_events FOR EACH ROW EXECUTE FUNCTION reject_mutation();

CREATE TRIGGER guard_append_only BEFORE UPDATE OR DELETE ON referral_access_events FOR EACH ROW EXECUTE FUNCTION reject_mutation();

CREATE TRIGGER guard_append_only BEFORE UPDATE OR DELETE ON rag_citations FOR EACH ROW EXECUTE FUNCTION reject_mutation();

CREATE TRIGGER guard_append_only BEFORE UPDATE OR DELETE ON inference_reviews FOR EACH ROW EXECUTE FUNCTION reject_mutation();

CREATE TRIGGER guard_append_only BEFORE UPDATE OR DELETE ON advisory_reviews FOR EACH ROW EXECUTE FUNCTION reject_mutation();

CREATE TRIGGER guard_append_only BEFORE UPDATE OR DELETE ON audit_events FOR EACH ROW EXECUTE FUNCTION reject_mutation();

CREATE TRIGGER guard_append_only BEFORE UPDATE OR DELETE ON invitation_reviews FOR EACH ROW EXECUTE FUNCTION reject_mutation();

CREATE TRIGGER guard_append_only BEFORE UPDATE OR DELETE ON membership_history FOR EACH ROW EXECUTE FUNCTION reject_mutation();

CREATE TRIGGER guard_signed BEFORE UPDATE OR DELETE ON clinical_notes FOR EACH ROW EXECUTE FUNCTION protect_signed_record();

CREATE TRIGGER guard_signed BEFORE UPDATE OR DELETE ON discharge_summaries FOR EACH ROW EXECUTE FUNCTION protect_signed_record();

CREATE TRIGGER guard_verified BEFORE UPDATE OR DELETE ON report_revisions FOR EACH ROW EXECUTE FUNCTION protect_verified_revision();

CREATE TRIGGER guard_verified BEFORE UPDATE OR DELETE ON observations FOR EACH ROW EXECUTE FUNCTION protect_verified_revision();

-- ============================================================================
-- 12 | Role catalog and access boundaries
-- ============================================================================

-- These seed rows contain no accounts or secrets. Application grants must be reviewed.
INSERT INTO roles(code,name,scope,description) VALUES
 ('PLATFORM_ADMIN','Super Admin','PLATFORM','Platform operations, no default clinical access'),
 ('HOSPITAL_ADMIN','Hospital Admin','HOSPITAL','Hospital setup and staff operations'),
 ('RECEPTIONIST','Receptionist','HOSPITAL','Scoped intake and administrative queue'),
 ('WARD_STAFF','Ward Staff','HOSPITAL','Assigned non-clinical tasks'),
 ('DOCTOR','Doctor','HOSPITAL','Assigned clinical care'),
 ('NURSE','Nurse','HOSPITAL','Assigned nursing care'),
 ('LAB_TECH','Lab Technician','HOSPITAL','Assigned report verification'),
 ('PATIENT','Patient','PORTAL','Own verified and released records'),
 ('CAREGIVER','Caregiver','PORTAL','Explicit scoped grant'),
 ('REFERRAL_DOCTOR','Receiving Doctor','PORTAL','Authenticated referral scope'),
 ('RESEARCHER','Researcher','HOSPITAL','Approved research scope'),
 ('AUDITOR','Auditor','HOSPITAL','Authorized audit metadata'),
 ('DEVICE','IoT Device','SERVICE','Restricted telemetry'),
 ('SERVICE','Service Worker','SERVICE','Approved background operation');

-- Row-level security is a tenant isolation backstop, NOT complete authorization.
-- A trusted backend must derive hospital context from a verified session and set it
-- in each transaction (SET LOCAL or set_config(..., true)); never trust a client value.
-- Example: SELECT set_config('medishield.hospital_id', verified_hospital_uuid, true);
-- The DB runtime role must be a non-owner, non-superuser, NOBYPASSRLS, with minimum grants.
-- Do NOT grant browser clients arbitrary SQL access or use a global service role in clients.
-- Global tables (users, patients, sessions, etc.) have NO runtime grants in this file.
-- Explicitly implement per-role/object/patient/release authorization before granting access.
-- Cross-hospital referral/portal queries must use a verified grant, then one source tenant
-- per transaction; never bypass RLS as a shortcut. RLS does not validate those grants.
CREATE FUNCTION current_hospital_id() RETURNS uuid LANGUAGE sql STABLE
SET search_path = pg_catalog AS $$
    SELECT NULLIF(current_setting('medishield.hospital_id', true), '')::uuid;
$$;

ALTER TABLE hospital_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE hospital_status_history FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON hospital_status_history USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE hospital_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE hospital_settings FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON hospital_settings USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE hospital_setup_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE hospital_setup_items FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON hospital_setup_items USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE memberships FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON memberships USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE membership_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE membership_permissions FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON membership_permissions USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE credential_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE credential_reviews FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON credential_reviews USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE access_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE access_requests FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON access_requests USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE departments FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON departments USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE wards ENABLE ROW LEVEL SECURITY;
ALTER TABLE wards FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON wards USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE beds ENABLE ROW LEVEL SECURITY;
ALTER TABLE beds FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON beds USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE staff_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_profiles FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON staff_profiles USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE staff_department_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_department_assignments FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON staff_department_assignments USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE hospital_patient_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE hospital_patient_links FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON hospital_patient_links USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE patient_identifiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE patient_identifiers FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON patient_identifiers USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE patient_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE patient_contacts FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON patient_contacts USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE identity_match_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE identity_match_reviews FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON identity_match_reviews USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE consents ENABLE ROW LEVEL SECURITY;
ALTER TABLE consents FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON consents USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE consent_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE consent_events FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON consent_events USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE reception_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE reception_queue FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON reception_queue USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE admission_decisions ENABLE ROW LEVEL SECURITY;
ALTER TABLE admission_decisions FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON admission_decisions USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE admissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE admissions FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON admissions USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE bed_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE bed_assignments FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON bed_assignments USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE care_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE care_assignments FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON care_assignments USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE ward_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE ward_tasks FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON ward_tasks USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE wristbands ENABLE ROW LEVEL SECURITY;
ALTER TABLE wristbands FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON wristbands USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE allergies ENABLE ROW LEVEL SECURITY;
ALTER TABLE allergies FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON allergies USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE conditions FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON conditions USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE objects ENABLE ROW LEVEL SECURITY;
ALTER TABLE objects FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON objects USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE upload_intents ENABLE ROW LEVEL SECURITY;
ALTER TABLE upload_intents FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON upload_intents USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE portal_link_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE portal_link_requests FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON portal_link_requests USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE patient_portal_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE patient_portal_links FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON patient_portal_links USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE caregiver_grants ENABLE ROW LEVEL SECURITY;
ALTER TABLE caregiver_grants FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON caregiver_grants USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE clinical_record_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinical_record_versions FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON clinical_record_versions USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE record_releases ENABLE ROW LEVEL SECURITY;
ALTER TABLE record_releases FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON record_releases USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE caregiver_grant_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE caregiver_grant_records FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON caregiver_grant_records USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE correction_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE correction_requests FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON correction_requests USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE patient_uploaded_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE patient_uploaded_documents FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON patient_uploaded_documents USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE download_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE download_tickets FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON download_tickets USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE patient_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE patient_notifications FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON patient_notifications USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE support_tickets FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON support_tickets USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE medication_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE medication_catalog FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON medication_catalog USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE product_barcodes ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_barcodes FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON product_barcodes USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE medication_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE medication_orders FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON medication_orders USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE medication_order_revisions ENABLE ROW LEVEL SECURITY;
ALTER TABLE medication_order_revisions FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON medication_order_revisions USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE medication_dose_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE medication_dose_events FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON medication_dose_events USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE medication_scan_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE medication_scan_events FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON medication_scan_events USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE medication_administration_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE medication_administration_records FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON medication_administration_records USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE dose_reconciliations ENABLE ROW LEVEL SECURITY;
ALTER TABLE dose_reconciliations FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON dose_reconciliations USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE downtime_incidents ENABLE ROW LEVEL SECURITY;
ALTER TABLE downtime_incidents FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON downtime_incidents USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE downtime_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE downtime_entries FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON downtime_entries USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE interaction_checks ENABLE ROW LEVEL SECURITY;
ALTER TABLE interaction_checks FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON interaction_checks USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE diet_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE diet_orders FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON diet_orders USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE diet_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE diet_logs FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON diet_logs USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE devices FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON devices USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE device_credentials ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_credentials FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON device_credentials USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE device_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_assignments FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON device_assignments USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE device_health_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_health_events FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON device_health_events USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE telemetry_ingest_dedupe ENABLE ROW LEVEL SECURITY;
ALTER TABLE telemetry_ingest_dedupe FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON telemetry_ingest_dedupe USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE telemetry_samples ENABLE ROW LEVEL SECURITY;
ALTER TABLE telemetry_samples FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON telemetry_samples USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE telemetry_rejections ENABLE ROW LEVEL SECURITY;
ALTER TABLE telemetry_rejections FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON telemetry_rejections USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE ecg_artifacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE ecg_artifacts FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON ecg_artifacts USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE observations ENABLE ROW LEVEL SECURITY;
ALTER TABLE observations FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON observations USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE news2_assessments ENABLE ROW LEVEL SECURITY;
ALTER TABLE news2_assessments FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON news2_assessments USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE news2_inputs ENABLE ROW LEVEL SECURITY;
ALTER TABLE news2_inputs FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON news2_inputs USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE alert_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE alert_policies FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON alert_policies USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE alerts FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON alerts USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE alert_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE alert_actions FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON alert_actions USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE notification_deliveries ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_deliveries FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON notification_deliveries USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE shifts FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON shifts USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE handoffs ENABLE ROW LEVEL SECURITY;
ALTER TABLE handoffs FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON handoffs USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE handoff_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE handoff_versions FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON handoff_versions USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE handoff_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE handoff_items FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON handoff_items USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE clinical_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinical_reports FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON clinical_reports USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE report_extraction_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE report_extraction_jobs FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON report_extraction_jobs USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE report_revisions ENABLE ROW LEVEL SECURITY;
ALTER TABLE report_revisions FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON report_revisions USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE report_fields ENABLE ROW LEVEL SECURITY;
ALTER TABLE report_fields FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON report_fields USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE report_field_candidates ENABLE ROW LEVEL SECURITY;
ALTER TABLE report_field_candidates FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON report_field_candidates USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE report_review_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE report_review_events FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON report_review_events USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE voice_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE voice_jobs FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON voice_jobs USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE clinical_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinical_notes FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON clinical_notes USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE timeline_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE timeline_events FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON timeline_events USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE discharge_summaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE discharge_summaries FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON discharge_summaries USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE fhir_exports ENABLE ROW LEVEL SECURITY;
ALTER TABLE fhir_exports FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON fhir_exports USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE referrals FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON referrals USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE referral_grants ENABLE ROW LEVEL SECURITY;
ALTER TABLE referral_grants FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON referral_grants USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE referral_grant_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE referral_grant_records FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON referral_grant_records USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE referral_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE referral_sessions FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON referral_sessions USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE referral_access_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE referral_access_events FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON referral_access_events USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE rag_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE rag_documents FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON rag_documents USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE rag_chunks ENABLE ROW LEVEL SECURITY;
ALTER TABLE rag_chunks FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON rag_chunks USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE rag_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE rag_conversations FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON rag_conversations USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE rag_queries ENABLE ROW LEVEL SECURITY;
ALTER TABLE rag_queries FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON rag_queries USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE rag_citations ENABLE ROW LEVEL SECURITY;
ALTER TABLE rag_citations FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON rag_citations USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE rag_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE rag_feedback FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON rag_feedback USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE inference_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE inference_jobs FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON inference_jobs USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE inference_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE inference_reviews FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON inference_reviews USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE advisory_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE advisory_jobs FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON advisory_jobs USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE advisory_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE advisory_reviews FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON advisory_reviews USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE sync_operations ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_operations FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON sync_operations USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE integration_connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE integration_connections FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON integration_connections USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE appointment_slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointment_slots FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON appointment_slots USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointments FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON appointments USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoices FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON invoices USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE invoice_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoice_items FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON invoice_items USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE payment_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_transactions FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON payment_transactions USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE health_reminders ENABLE ROW LEVEL SECURITY;
ALTER TABLE health_reminders FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON health_reminders USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE emergency_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE emergency_requests FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON emergency_requests USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE membership_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE membership_history FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON membership_history USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE sharing_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE sharing_requests FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON sharing_requests USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE sharing_request_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE sharing_request_records FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON sharing_request_records USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE vaccinations ENABLE ROW LEVEL SECURITY;
ALTER TABLE vaccinations FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON vaccinations USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

ALTER TABLE telemetry_samples_default ENABLE ROW LEVEL SECURITY;
ALTER TABLE telemetry_samples_default FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_scope ON telemetry_samples_default USING (hospital_id = medishield.current_hospital_id()) WITH CHECK (hospital_id = medishield.current_hospital_id());

-- No privileges on the schema, tables, sequences or functions are granted to PUBLIC.
REVOKE ALL ON ALL TABLES IN SCHEMA medishield FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA medishield FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA medishield FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA medishield REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA medishield REVOKE ALL ON TABLES FROM PUBLIC;
COMMIT;

-- ============================================================================
-- 13 | Required next steps (service-level logic; not automatically enforced by this DDL)
-- ============================================================================

-- 1. Bootstrap the first verified PLATFORM_ADMIN from a controlled server command;
--    hash passwords using an approved adaptive password hashing scheme, configure MFA,
--    never seed real credentials or print tokens. Set minimum DB privileges explicitly.
-- 2. Review all API field/status mappings and Prisma schema against this baseline.
--    Existing repository migrations must be inspected; use incremental migrations,
--    do not overwrite existing tables. Use SQL migrations for exclusion constraints,
--    partial indexes, RLS and triggers that Prisma cannot fully represent.
-- 3. Protect last active administrator via serialized transaction and access_version
--    increments; validate hospital approval and status transition, revoke sessions.
--    Platform users/admins must not gain implicit clinical access.
-- 4. Patient identity proof, consent scope, grant expiry, release visibility and
--    recipient authorization must be verified on every read/download/RAG request.
--    Clinical_record_versions is a typed registry populated by trusted services;
--    its polymorphic source_table/source_id must be validated against the real source.
--    Revoke releases and invalidate RAG indexes on amendments. Do not store raw IDs.
-- 5. Medication writers lock admission -> medication_order -> dose consistently.
--    Use same transaction for checks, state, audit, idempotency and outbox. Require
--    approved timing, correct scans, active membership, exact order revision and
--    current safety review. No physical action after ambiguous network response.
--    Expired/uncertain reservations require the approved review workflow; a timer
--    must never authorize a repeat dose. Clinical rules are not seeded here.
-- 6. Telemetry dedupe row + telemetry insert in one transaction, reject replays and
--    check payload hash. Create monthly native partitions before ingest; manage default
--    partition carefully. TimescaleDB is an alternative migration, not a second writer.
-- 7. For RAG, enable pgvector with known embedding dimension; scope retrieval to
--    authorized patient, exact released/verified version and active consent/grant.
--    Research inference never modifies clinical orders. Do not use experimental data
--    or models for real patient decisions without appropriate validation and approval.
-- 8. Application handles signed object URLs, file scanning, encrypted storage, secret
--    rotation, alert acknowledgement and escalation, notifications, outbox retries,
--    offline sync, account recovery, FHIR mappings, and retention/deletion policies.
-- 9. Optional appointment capacity, invoice totals and payment verification require
--    their own transaction logic; no real payment or emergency service is configured.
-- 10. Before adoption run this migration on disposable PostgreSQL 15+; validate all
--     foreign keys, trigger paths, RLS policies with real runtime role, rollback and
--     migration compatibility, and real concurrent medication/bed/device tests.
--     A schema alone does not certify security, clinical safety or legal compliance.
