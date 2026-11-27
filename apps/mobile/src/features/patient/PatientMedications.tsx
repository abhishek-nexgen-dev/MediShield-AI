import Head from 'expo-router/head';
import { useState } from 'react';

import { PublicLink } from '@/components/layout/PublicLink';

import { ClipboardList, Eye, FileText, Hospital, Pill, Search } from './icons';
import { hospitalMedicationsHref } from './medicationRoutes';
import { MedicationList } from './MedicationViews';
import type { Medication } from './model';
import { usePatientDemo } from './PatientLayout';
import { button, control, EmptyState, iconButton, PageHeader, panel, recordsPath, Section, SummaryCard } from './ui';

const statusFilters = ['All', 'Active', 'Completed'] as const;
type StatusFilter = typeof statusFilters[number];

function HospitalMedicationCard({ medications }: { medications: Medication[] }) {
  const { hospitalId, hospital } = medications[0];
  return (
    <article className={`${panel} min-w-0 px-4 py-3`}>
      <div className="flex items-center gap-2.5 border-b border-border pb-3">
        <span className="inline-flex size-10 shrink-0 items-center justify-center rounded-xl bg-accent text-on-accent"><Hospital size={19} aria-hidden /></span>
        <div className="min-w-0 flex-1">
          <h3 className="font-semibold tracking-tight">{hospital}</h3>
          <p className="mt-0.5 text-xs text-secondary">{medications.length} {medications.length === 1 ? 'prescription' : 'prescriptions'} shown</p>
        </div>
        <PublicLink href={hospitalMedicationsHref(hospitalId)} className={iconButton} aria-label={`View all medications at ${hospital}`} title="View all hospital medications">
          <Eye size={19} aria-hidden />
        </PublicLink>
      </div>
      <MedicationList medications={medications} />
    </article>
  );
}

export function PatientMedications() {
  const { medications } = usePatientDemo();
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState<StatusFilter>('All');
  const query = search.trim().toLowerCase();
  const activeCount = medications.filter((medication) => medication.status === 'Active').length;
  const matching = medications.filter((medication) => (
    (status === 'All' || medication.status === status) &&
    [medication.name, medication.doctor, medication.hospital].some((value) => value.toLowerCase().includes(query))
  ));

  const byHospital = new Map<string, Medication[]>();
  for (const medication of matching) {
    const group = byHospital.get(medication.hospitalId);
    if (group) group.push(medication);
    else byHospital.set(medication.hospitalId, [medication]);
  }

  function clearFilters() {
    setSearch('');
    setStatus('All');
  }

  return (
    <>
      <Head><title>My Medications | MediShield AI</title></Head>
      <PageHeader title="My Medications" description="Review your current prescriptions and medication history by hospital.">
        <PublicLink href={{ pathname: recordsPath, params: { category: 'Prescriptions' } }} className={button}>
          <FileText size={16} aria-hidden /> Prescription records
        </PublicLink>
      </PageHeader>
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
        <SummaryCard label="Active prescriptions" count={activeCount} icon={Pill} />
        <SummaryCard label="Completed prescriptions" count={medications.length - activeCount} icon={ClipboardList} />
        <SummaryCard label="Total prescriptions" count={medications.length} icon={FileText} />
      </div>
      <Section title="Medications by hospital">
        <div className="mb-4 flex flex-wrap items-center gap-3">
          <label className="relative min-w-0 flex-1 basis-56">
            <span className="sr-only">Search prescriptions</span>
            <Search size={16} className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-muted" aria-hidden />
            <input type="search" className={`${control} w-full pl-9`} placeholder="Search by prescription, doctor, or hospital" value={search} onChange={(event) => setSearch(event.target.value)} />
          </label>
          <div className="flex flex-wrap gap-1" role="group" aria-label="Prescription status">
            {statusFilters.map((filter) => (
              <button key={filter} type="button" aria-pressed={status === filter} onClick={() => setStatus(filter)} className={`${button} ${status === filter ? '!bg-accent !text-on-accent' : ''}`}>{filter}</button>
            ))}
          </div>
        </div>
        {matching.length ? (
          <>
            <p className="mb-3 text-sm text-secondary" role="status">{matching.length} {matching.length === 1 ? 'prescription' : 'prescriptions'}</p>
            <div className="grid items-start gap-3 xl:grid-cols-2">
              {Array.from(byHospital, ([id, group]) => <HospitalMedicationCard key={id} medications={group} />)}
            </div>
          </>
        ) : medications.length ? (
          <EmptyState title="No matching prescriptions" description="Try a different search term or status.">
            <button type="button" className={button} onClick={clearFilters}>Clear filters</button>
          </EmptyState>
        ) : (
          <EmptyState title="No prescriptions yet" description="Released prescriptions will appear here when available." />
        )}
      </Section>
    </>
  );
}
