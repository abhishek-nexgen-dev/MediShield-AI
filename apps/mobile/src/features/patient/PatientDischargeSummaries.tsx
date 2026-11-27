import Head from 'expo-router/head';
import { useState } from 'react';

import { PublicLink } from '@/components/layout/PublicLink';

import { ArrowRight, Download, FileText, Search } from './icons';
import { displayDate, filterRecords, initialFilters, type MedicalRecord } from './model';
import { usePatientDemo } from './PatientLayout';
import { demoDocument } from './RecordViews';
import { button, control, EmptyState, PageHeader, panel, primary, RecordIcon, recordsPath, Section, StatusBadge } from './ui';

const dischargeCategory = 'Discharge Summaries';

function DischargeSummaryCard({ record }: { record: MedicalRecord }) {
  return (
    <article className={`${panel} flex flex-col gap-4 p-4 sm:p-5`}>
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div className="flex min-w-0 items-center gap-3">
          <RecordIcon />
          <div>
            <h3 className="font-semibold tracking-tight">{record.name}</h3>
            <p className="mt-0.5 text-sm text-secondary">{record.hospital}</p>
          </div>
        </div>
        <StatusBadge>{record.status}</StatusBadge>
      </div>
      <dl className="grid grid-cols-2 gap-3 border-y border-border py-3 text-sm">
        <div>
          <dt className="text-xs text-muted">Record date</dt>
          <dd className="mt-1"><time dateTime={record.date}>{displayDate(record.date)}</time></dd>
        </div>
        <div>
          <dt className="text-xs text-muted">Recorded by</dt>
          <dd className="mt-1">{record.doctor || 'Not recorded'}</dd>
        </div>
      </dl>
      {record.note && <p className="text-sm leading-6 text-secondary">{record.note}</p>}
      <div className="flex flex-wrap gap-2">
        <PublicLink href={{ pathname: recordsPath, params: { record: record.id } }} className={primary}>
          View summary <ArrowRight size={16} aria-hidden />
        </PublicLink>
        <a href={demoDocument(record.id)} download className={button}><Download size={16} aria-hidden /> Download sample PDF</a>
      </div>
    </article>
  );
}

export function PatientDischargeSummaries() {
  const { records } = usePatientDemo();
  const [search, setSearch] = useState('');
  const [hospital, setHospital] = useState('');
  const releasedSummaries = records.filter((record) => (
    record.category === dischargeCategory && record.source === 'Hospital release' &&
    (record.status === 'Verified' || record.status === 'Corrected')
  ));
  const hospitals = [...new Set(releasedSummaries.map((record) => record.hospital))].sort();
  const matching = filterRecords(releasedSummaries, { ...initialFilters, search, hospital });

  function clearFilters() {
    setSearch('');
    setHospital('');
  }

  return (
    <>
      <Head><title>Discharge Summaries | MediShield AI</title></Head>
      <PageHeader title="Discharge Summaries" description="Find hospital discharge documents that have been released to your patient portal.">
        <PublicLink href={{ pathname: recordsPath, params: { category: dischargeCategory } }} className={button}>
          <FileText size={16} aria-hidden /> Browse medical records
        </PublicLink>
      </PageHeader>
      <Section title="Released summaries" description="Documents are listed newest first.">
        {releasedSummaries.length ? (
          <>
            <div className="mb-4 flex flex-wrap items-end gap-3">
              <label className="min-w-0 flex-1 basis-48 text-xs font-medium text-secondary">
                Search summaries
                <span className="relative mt-1 block">
                  <Search size={16} className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-muted" aria-hidden />
                  <input type="search" className={`${control} w-full pl-9`} placeholder="Search by document, doctor, or hospital" value={search} onChange={(event) => setSearch(event.target.value)} />
                </span>
              </label>
              <label className="grid min-w-0 gap-1 text-xs font-medium text-secondary">
                Hospital
                <select className={`${control} max-w-full`} value={hospital} onChange={(event) => setHospital(event.target.value)}>
                  <option value="">All hospitals</option>
                  {hospitals.map((name) => <option key={name} value={name}>{name}</option>)}
                </select>
              </label>
            </div>
            {matching.length ? (
              <>
                <p className="mb-3 text-sm text-secondary" role="status">{matching.length} {matching.length === 1 ? 'summary' : 'summaries'}</p>
                <div className="grid gap-3 lg:grid-cols-2">
                  {matching.map((record) => <DischargeSummaryCard key={record.id} record={record} />)}
                </div>
              </>
            ) : (
              <EmptyState title="No matching summaries" description="Try a different search term or hospital.">
                <button type="button" className={button} onClick={clearFilters}>Clear filters</button>
              </EmptyState>
            )}
          </>
        ) : (
          <EmptyState title="No discharge summaries yet" description="Available documents will appear here when your hospital releases them." />
        )}
      </Section>
    </>
  );
}
