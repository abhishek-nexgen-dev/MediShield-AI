import { useLocalSearchParams } from 'expo-router';
import Head from 'expo-router/head';

import { PublicLink } from '@/components/layout/PublicLink';

import { ArrowRight, Eye, Pill } from './icons';
import { MedicationQr } from './MedicationQr';
import { hospitalMedicationsHref, medicationDetailHref } from './medicationRoutes';
import { medicationPeriod, type Medication } from './model';
import { usePatientDemo } from './PatientLayout';
import { button, EmptyState, iconButton, medicationsPath, PageHeader, recordsPath, Section, StatusBadge } from './ui';

export function MedicationList({ medications }: { medications: readonly Medication[] }) {
  return (
    <ul className="m-0 list-none divide-y divide-border p-0">
      {medications.map((medication) => (
        <li key={medication.id} className="flex flex-wrap items-center gap-2 py-3">
          <span className="inline-flex size-9 shrink-0 items-center justify-center rounded-lg bg-accent text-on-accent"><Pill size={17} aria-hidden /></span>
          <div className="min-w-0 flex-1">
            <p className="font-semibold">{medication.name}</p>
            <p className="mt-0.5 text-xs text-secondary">{medication.doctor} · {medicationPeriod(medication)}</p>
          </div>
          <StatusBadge>{medication.status}</StatusBadge>
          <PublicLink
            href={medicationDetailHref(medication.hospitalId, medication.id)}
            className={iconButton}
            aria-label={`View ${medication.name}`}
            title="View prescription details">
            <Eye size={18} aria-hidden />
          </PublicLink>
        </li>
      ))}
    </ul>
  );
}

function MissingMedicationView({ hospital = false }: { hospital?: boolean }) {
  return (
    <EmptyState
      title={hospital ? 'Hospital prescriptions unavailable' : 'Prescription unavailable'}
      description="This view could not be found in the demo session.">
      <PublicLink href={medicationsPath} className={button}>Back to medications</PublicLink>
    </EmptyState>
  );
}

export function PatientHospitalMedications() {
  const { hospitalId } = useLocalSearchParams<{ hospitalId: string }>();
  const { medications } = usePatientDemo();
  const prescriptions = medications.filter((medication) => medication.hospitalId === hospitalId);
  const hospital = prescriptions[0]?.hospital;

  if (!hospital) return <MissingMedicationView hospital />;

  const active = prescriptions.filter((medication) => medication.status === 'Active').length;
  return (
    <>
      <Head><title>{hospital} Medications | MediShield AI</title></Head>
      <PageHeader title={hospital} description="Review medications and their recorded status at this hospital.">
        <PublicLink href={medicationsPath} className={button}>All hospitals</PublicLink>
      </PageHeader>
      <div className="grid min-w-0 items-start gap-4 lg:grid-cols-[minmax(0,1fr)_minmax(240px,18rem)]">
        <Section title="Hospital prescriptions" description={`${prescriptions.length} total · ${active} active · ${prescriptions.length - active} completed`}>
          <MedicationList medications={prescriptions} />
        </Section>
        <MedicationQr key={hospitalId} href={hospitalMedicationsHref(hospitalId)} />
      </div>
    </>
  );
}

export function PatientMedicationDetail() {
  const { hospitalId, medicationId } = useLocalSearchParams<{ hospitalId: string; medicationId: string }>();
  const { medications, records } = usePatientDemo();
  const medication = medications.find((item) => item.hospitalId === hospitalId && item.id === medicationId);

  if (!medication) return <MissingMedicationView />;

  const document = records.find((record) => record.id === medication.recordId);
  const fields = [
    ['Prescribed dose', medication.dosage],
    ['Frequency', medication.frequency],
    ['Prescribed by', medication.doctor],
    ['Prescription period', medicationPeriod(medication)],
    ['Instructions', medication.instructions],
  ];

  return (
    <>
      <Head><title>{medication.name} | MediShield AI</title></Head>
      <PageHeader title={medication.name} description={medication.hospital}>
        <PublicLink href={hospitalMedicationsHref(hospitalId)} className={button}>Back to hospital medications</PublicLink>
      </PageHeader>
      <div className="grid min-w-0 items-start gap-4 lg:grid-cols-[minmax(0,1fr)_minmax(240px,18rem)]">
        <Section title="Prescription details" action={<StatusBadge>{medication.status}</StatusBadge>}>
          <dl className="grid grid-cols-1 gap-4 border-t border-border pt-4 text-sm sm:grid-cols-2">
            {fields.map(([label, value]) => (
              <div key={label} className="min-w-0">
                <dt className="text-xs font-medium text-muted">{label}</dt>
                <dd className="mt-1 leading-5 text-ink">{value || 'Not recorded'}</dd>
              </div>
            ))}
          </dl>
          {document && (
            <PublicLink href={{ pathname: recordsPath, params: { record: document.id } }} className={`${button} mt-5`}>
              View prescription document <ArrowRight size={16} aria-hidden />
            </PublicLink>
          )}
        </Section>
        <MedicationQr key={medication.id} href={medicationDetailHref(hospitalId, medicationId)} />
      </div>
    </>
  );
}
