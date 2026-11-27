import { useLocalSearchParams, useRouter } from 'expo-router';
import Head from 'expo-router/head';
import { useEffect, useState } from 'react';

import { ChevronLeft, ChevronRight, FileHeart, FlaskConical, Grid2X2, Hospital, List, Search, Share2, ShieldAlert, Upload, X } from './icons';
import { categories, filterRecords, initialFilters, paginateRecords, statuses, type MedicalRecord, type RecordFilters } from './model';
import { usePatientDemo } from './PatientLayout';
import { HealthProfile, MedicalTimeline, RecordCards, RecordDrawer, RecordsTable } from './RecordViews';
import { ShareRecordsModal, UploadDocumentModal } from './RecordWorkflowPreviews';
import { button, control, EmptyState, PageHeader, panel, primary, SummaryCard } from './ui';

type Presentation = 'list' | 'grid' | 'timeline';
const views: { key: Presentation; label: string; icon: typeof List }[] = [
  { key: 'list', label: 'List', icon: List },
  { key: 'grid', label: 'Grid', icon: Grid2X2 },
  { key: 'timeline', label: 'Timeline', icon: FileHeart },
];

function FilterSelect({ label, all, options, value, onChange }: { label: string; all?: string; options: readonly (string | { value: string; label: string })[]; value: string; onChange: (value: string) => void }) {
  return (
    <label className="grid min-w-0 gap-1 text-xs font-medium text-secondary">
      {label}
      <select className={`${control} min-w-0`} value={value} onChange={(event) => onChange(event.target.value)}>
        {all && <option value="">{all}</option>}
        {options.map((option) => typeof option === 'string' ? <option key={option}>{option}</option> : <option key={option.value} value={option.value}>{option.label}</option>)}
      </select>
    </label>
  );
}

export function PatientRecords() {
  const { patient, records } = usePatientDemo();
  const router = useRouter();
  const params = useLocalSearchParams<{ category?: string; search?: string; record?: string; focus?: string }>();
  const category = categories.find((item) => item === params.category) ?? '';
  const search = typeof params.search === 'string' ? params.search : '';
  const query = JSON.stringify([category, search]);
  const [appliedQuery, setAppliedQuery] = useState(query);
  const [filters, setFilters] = useState({ ...initialFilters, category, search });
  const [presentation, setPresentation] = useState<Presentation>('list');
  const [page, setPage] = useState(1);
  const [size, setSize] = useState(6);
  const [selected, setSelected] = useState<{ record: MedicalRecord; preview: boolean }>();
  const [workflow, setWorkflow] = useState<'upload' | 'share'>();
  const profileFocus = params.focus === 'profile';
  const linkedRecord = records.find(({ id }) => id === params.record);
  const detail = linkedRecord ? { record: linkedRecord, preview: false } : selected;

  if (query !== appliedQuery) {
    setAppliedQuery(query);
    setFilters({ ...initialFilters, category, search });
    setPage(1);
  }

  useEffect(() => {
    if (profileFocus) document.getElementById('patient-health-profile')?.focus();
  }, [profileFocus]);

  function closeRecord() {
    setSelected(undefined);
    if (params.record) router.setParams({ record: '' });
  }

  function setFilter<K extends keyof RecordFilters>(key: K, value: RecordFilters[K]) {
    setFilters((current) => ({ ...current, [key]: value }));
    setPage(1);
  }

  function clearFilters() {
    setFilters(initialFilters);
    setPage(1);
  }

  function selectRecord(record: MedicalRecord, preview = false) {
    setSelected({ record, preview });
  }

  const hospitals = [...new Set(records.map(({ hospital }) => hospital))].sort();
  const matching = filterRecords(records, filters);
  const pagination = paginateRecords(matching, page, size);
  const dateError = Boolean(filters.from && filters.to && filters.from > filters.to);
  const activeFilters = [
    { key: 'search', label: filters.search.trim() }, { key: 'hospital', label: filters.hospital },
    { key: 'category', label: filters.category }, { key: 'status', label: filters.status },
    { key: 'from', label: filters.from && `From ${filters.from}` }, { key: 'to', label: filters.to && `To ${filters.to}` },
  ].filter(({ label }) => label) as { key: Exclude<keyof RecordFilters, 'sort'>; label: string }[];

  return (
    <>
      <Head><title>My Medical Records | MediShield AI</title></Head>
      <PageHeader title="My Medical Records" description="Your released healthcare records, organized in one place.">
        <div className="flex flex-wrap gap-2">
          <button className={primary} type="button" disabled><Upload size={16} aria-hidden />Upload Document</button>
          <button className={button} type="button" disabled><Share2 size={16} aria-hidden />Share Records</button>
        </div>
      </PageHeader>
      <details className="text-xs text-secondary">
        <summary className="w-fit cursor-pointer font-medium">Upload and sharing unavailable · Preview forms</summary>
        <div className="mt-2 flex flex-wrap gap-2">
          <button type="button" className={button} onClick={() => setWorkflow('upload')}>Preview upload form</button>
          <button type="button" className={button} onClick={() => setWorkflow('share')}>Preview sharing form</button>
        </div>
      </details>
      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <SummaryCard label="Total Records" count={records.length} icon={FileHeart} />
        <SummaryCard label="Connected Hospitals" count={hospitals.length} icon={Hospital} />
        <SummaryCard label="Medical Reports" count={records.filter(({ category }) => category === 'Lab Reports' || category === 'Imaging & Scans').length} icon={FlaskConical} />
        <SummaryCard label="Recorded Allergies" count={patient.allergies.length} icon={ShieldAlert} />
      </div>
      <HealthProfile patient={patient} highlight={profileFocus} />
      <section aria-label="Medical record library" className={`${panel} min-w-0 overflow-hidden`}>
        <div className="overflow-x-auto border-b border-border px-3" aria-label="Record categories">
          <div className="flex w-max gap-1">
            {['', ...categories].map((value) => (
              <button type="button" key={value} onClick={() => setFilter('category', value)} aria-pressed={filters.category === value} className={`min-h-11 cursor-pointer whitespace-nowrap border-b-2 bg-transparent px-2 py-2 text-[.8125rem] font-medium ${filters.category === value ? 'border-primary text-primary' : 'border-transparent text-secondary hover:text-ink'}`}>
                {value || 'All Records'} <span className="rounded-md bg-subtle px-1 text-xs text-muted">{value ? records.filter(({ category }) => category === value).length : records.length}</span>
              </button>
            ))}
          </div>
        </div>
        <div className="space-y-3 border-b border-border p-3 sm:p-4">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <label className="relative min-w-0 flex-1 basis-64">
              <span className="sr-only">Search your medical records</span><Search size={17} aria-hidden className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-muted" />
              <input type="search" className={`${control} w-full pl-9`} placeholder="Search your medical records..." value={filters.search} onChange={(event) => setFilter('search', event.target.value)} />
            </label>
            <div className="flex max-w-full flex-wrap gap-1" aria-label="Record view">
              {views.map(({ key, label, icon: Icon }) => <button key={key} type="button" aria-pressed={presentation === key} className={`${button} gap-1 px-2 text-xs ${presentation === key ? '!bg-accent !text-on-accent' : ''}`} onClick={() => { setPresentation(key); setPage(1); }}><Icon size={14} className="shrink-0" aria-hidden />{label}</button>)}
            </div>
          </div>
          <div className="grid grid-cols-2 gap-2 md:grid-cols-3 2xl:grid-cols-6">
            <FilterSelect label="Hospital" all="All hospitals" options={hospitals} value={filters.hospital} onChange={(value) => setFilter('hospital', value)} />
            <FilterSelect label="Category" all="All categories" options={categories} value={filters.category} onChange={(value) => setFilter('category', value)} />
            <FilterSelect label="Verification" all="All statuses" options={statuses} value={filters.status} onChange={(value) => setFilter('status', value)} />
            <label className="grid min-w-0 gap-1 text-xs font-medium text-secondary">From date<input type="date" aria-invalid={dateError} className={`${control} min-w-0 w-full`} value={filters.from} onChange={(event) => setFilter('from', event.target.value)} /></label>
            <label className="grid min-w-0 gap-1 text-xs font-medium text-secondary">To date<input type="date" aria-invalid={dateError} className={`${control} min-w-0 w-full`} value={filters.to} onChange={(event) => setFilter('to', event.target.value)} /></label>
            {presentation !== 'timeline' && <FilterSelect label="Sort" options={[{ value: 'newest', label: 'Newest first' }, { value: 'oldest', label: 'Oldest first' }, { value: 'name', label: 'Name A–Z' }]} value={filters.sort} onChange={(value) => setFilter('sort', value as RecordFilters['sort'])} />}
          </div>
          <div className="flex flex-wrap items-center gap-2 text-xs">
            <span role="status" className="font-semibold text-secondary">{matching.length} matching {matching.length === 1 ? 'record' : 'records'}</span>
            {activeFilters.map(({ key, label }) => <button key={key} type="button" className="inline-flex min-h-7 max-w-full cursor-pointer items-center gap-1 break-all rounded-md bg-accent px-2 text-on-accent" onClick={() => setFilter(key, '')} aria-label={`Remove filter ${label}`}>{label}<X size={13} className="shrink-0" aria-hidden /></button>)}
            <button type="button" className="ml-auto min-h-8 cursor-pointer rounded-md bg-transparent px-2 font-semibold text-primary hover:bg-subtle disabled:cursor-not-allowed disabled:text-muted" onClick={clearFilters} disabled={!activeFilters.length && filters.sort === initialFilters.sort}>Clear filters</button>
          </div>
        </div>
        {dateError ? <EmptyState title="Check the date range" description="The start date must be on or before the end date." /> : matching.length === 0 ? (
          <EmptyState title={records.length ? 'No matching records' : 'No medical records yet'} description={records.length ? 'Try a different search term or clear one or more filters.' : 'Your available records will appear here when they are released by your hospital.'} />
        ) : presentation === 'timeline' ? (
          <MedicalTimeline records={matching} onSelect={selectRecord} />
        ) : (
          <>
            {presentation === 'list' ? (
              <>
                <div className="hidden xl:block"><RecordsTable records={pagination.items} onSelect={selectRecord} /></div>
                <div className="xl:hidden"><RecordCards records={pagination.items} onSelect={selectRecord} /></div>
              </>
            ) : <RecordCards records={pagination.items} onSelect={selectRecord} />}
            <nav aria-label="Medical records pagination" className="flex flex-wrap items-center justify-between gap-2 border-t border-border px-3 py-3 text-xs sm:px-4">
              <p className="font-medium text-secondary">{(pagination.page - 1) * size + 1}–{Math.min(pagination.page * size, matching.length)} of {matching.length} records</p>
              <div className="flex flex-wrap items-center gap-1">
                <label className="mr-1 flex items-center gap-1 text-secondary">Per page <select className={`${control} min-h-8 px-2 py-1 text-xs`} value={size} onChange={(event) => { setSize(Number(event.target.value)); setPage(1); }}>{[6, 12, 24].map((value) => <option key={value}>{value}</option>)}</select></label>
                <button type="button" className={`${button} min-h-8 px-2 py-1`} onClick={() => setPage(pagination.page - 1)} disabled={pagination.page <= 1} aria-label="Previous page"><ChevronLeft size={15} aria-hidden /></button>
                {Array.from({ length: pagination.pageCount }, (_, index) => index + 1).map((number) => <button key={number} type="button" className={`${button} min-h-8 px-2 py-1 text-xs ${number === pagination.page ? '!bg-accent !text-on-accent' : ''}`} aria-label={`Page ${number}`} aria-current={number === pagination.page ? 'page' : undefined} onClick={() => setPage(number)}>{number}</button>)}
                <button type="button" className={`${button} min-h-8 px-2 py-1`} onClick={() => setPage(pagination.page + 1)} disabled={pagination.page >= pagination.pageCount} aria-label="Next page"><ChevronRight size={15} aria-hidden /></button>
              </div>
            </nav>
          </>
        )}
      </section>
      {detail && <RecordDrawer key={detail.record.id} record={detail.record} initiallyPreview={detail.preview} onClose={closeRecord} />}
      {workflow === 'upload' && <UploadDocumentModal onClose={() => setWorkflow(undefined)} />}
      {workflow === 'share' && <ShareRecordsModal records={records} onClose={() => setWorkflow(undefined)} />}
    </>
  );
}
