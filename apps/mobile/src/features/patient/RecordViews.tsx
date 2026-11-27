import { useState } from 'react';

import { Download, Eye, FileText, ShieldAlert } from './icons';
import { displayDate, type MedicalRecord } from './model';
import { button, Dialog, iconButton, panel, RecordIcon, Section, StatusBadge } from './ui';

export function demoDocument(id: string) {
  return `/patient-demo/${id}.pdf`;
}

function RecordActions({ record, onSelect }: { record: MedicalRecord; onSelect: (record: MedicalRecord, preview?: boolean) => void }) {
  return (
    <div className="flex items-center gap-0.5">
      <button className={iconButton} type="button" onClick={() => onSelect(record)} aria-label={`View details for ${record.name}`} title="View details"><FileText size={16} aria-hidden /></button>
      <button className={iconButton} type="button" onClick={() => onSelect(record, true)} aria-label={`Preview ${record.name}`} title="Preview document"><Eye size={16} aria-hidden /></button>
      <a className={iconButton} href={demoDocument(record.id)} download aria-label={`Download sample ${record.name}`} title="Download sample document"><Download size={16} aria-hidden /></a>
    </div>
  );
}

export function RecordsTable({ records, onSelect }: { records: MedicalRecord[]; onSelect: (record: MedicalRecord, preview?: boolean) => void }) {
  return (
    <table className="w-full border-collapse text-left text-xs xl:text-sm">
      <caption className="sr-only">Matching medical records</caption>
      <thead className="bg-subtle text-secondary">
        <tr>{['Document Name', 'Category', 'Hospital', 'Doctor', 'Date', 'Source', 'Verification Status', 'Actions'].map((column) => <th key={column} scope="col" className="px-2 py-2.5 font-semibold first:pl-3 last:pr-3">{column}</th>)}</tr>
      </thead>
      <tbody>
        {records.map((record) => (
          <tr key={record.id} className="border-b border-border align-middle last:border-0 hover:bg-canvas">
            <th scope="row" className="px-2 py-3 pl-3 text-left font-semibold"><span className="flex items-center gap-2"><RecordIcon />{record.name}</span></th>
            <td className="px-2 py-3 text-secondary">{record.category}</td>
            <td className="px-2 py-3 text-secondary">{record.hospital}</td>
            <td className="px-2 py-3 text-secondary">{record.doctor}</td>
            <td className="px-2 py-3 text-secondary">{displayDate(record.date)}</td>
            <td className="px-2 py-3 text-secondary">{record.source}</td>
            <td className="px-2 py-3"><StatusBadge>{record.status}</StatusBadge></td>
            <td className="px-2 py-3 pr-3"><RecordActions record={record} onSelect={onSelect} /></td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

export function RecordCards({ records, onSelect }: { records: MedicalRecord[]; onSelect: (record: MedicalRecord, preview?: boolean) => void }) {
  return (
    <div className="grid gap-3 p-3 sm:grid-cols-2 xl:grid-cols-3">
      {records.map((record) => (
        <article key={record.id} className={`${panel} flex min-w-0 flex-col gap-2 p-3`}>
          <div className="flex items-start gap-2"><RecordIcon /><div className="min-w-0"><h3 className="font-semibold">{record.name}</h3><p className="text-xs text-secondary">{record.category} · {displayDate(record.date)}</p></div></div>
          <p className="text-sm leading-5 text-secondary">{record.hospital}<br />{record.doctor}</p>
          <div className="flex flex-wrap items-center justify-between gap-1">
            <div><StatusBadge>{record.status}</StatusBadge><p className="mt-1 text-xs text-muted">{record.source}</p></div>
            <RecordActions record={record} onSelect={onSelect} />
          </div>
        </article>
      ))}
    </div>
  );
}

const monthName = new Intl.DateTimeFormat('en-IN', { month: 'long', year: 'numeric', timeZone: 'Asia/Kolkata' });

export function MedicalTimeline({ records, onSelect }: { records: MedicalRecord[]; onSelect: (record: MedicalRecord) => void }) {
  const sorted = [...records].sort((a, b) => b.date.localeCompare(a.date));
  const groups = new Map<string, MedicalRecord[]>();
  for (const record of sorted) {
    const month = record.date.slice(0, 7);
    const events = groups.get(month);
    if (events) events.push(record);
    else groups.set(month, [record]);
  }

  return (
    <div className="space-y-5 p-4">
      {[...groups].map(([month, events]) => (
        <section key={month}>
          <h3 className="mb-2 text-sm font-semibold text-secondary">{monthName.format(new Date(`${month}-01`))}</h3>
          <ol className="m-0 list-none space-y-1 border-l border-border p-0 pl-3">
            {events.map((record) => (
              <li key={record.id}>
                <details className="rounded-lg bg-canvas px-3 py-2 text-sm">
                  <summary className="cursor-pointer font-medium">{record.name} <span className="ml-1 text-xs font-normal text-muted">{displayDate(record.date)}</span></summary>
                  <p className="mb-2 mt-1 text-secondary">{record.note}</p>
                  <button type="button" className={button} onClick={() => onSelect(record)}>View related record</button>
                </details>
              </li>
            ))}
          </ol>
        </section>
      ))}
    </div>
  );
}

export function HealthProfile({ patient, highlight }: { patient: { name: string; id: string; age: number; bloodGroup: string; allergies: string[]; conditions: string[]; updated: string }; highlight: boolean }) {
  return (
    <div id="patient-health-profile" tabIndex={-1} className={highlight ? 'rounded-2xl ring-2 ring-focus' : undefined}>
      <Section title="Patient Health Profile" action={<span className="text-xs text-muted">Updated {displayDate(patient.updated)}</span>}>
        <dl className="grid grid-cols-2 gap-3 sm:grid-cols-3 xl:grid-cols-6">
          {[
            ['Patient name', patient.name], ['Patient ID', patient.id], ['Age', `${patient.age} years`],
            ['Blood group', patient.bloodGroup], ['Recorded allergies', patient.allergies.join(', ') || 'Not recorded'],
            ['Known conditions', patient.conditions.join(', ') || 'Not recorded'],
          ].map(([label, value]) => (
            <div key={label}><dt className="text-xs text-muted">{label}</dt><dd className="mt-1 flex items-center gap-1 text-sm font-semibold">{label === 'Recorded allergies' && patient.allergies.length > 0 && <ShieldAlert size={15} className="shrink-0 text-primary" aria-hidden />}{value}</dd></div>
          ))}
        </dl>
      </Section>
    </div>
  );
}

export function RecordDrawer({ record, initiallyPreview, onClose }: { record: MedicalRecord; initiallyPreview: boolean; onClose: () => void }) {
  const [preview, setPreview] = useState(initiallyPreview);
  const url = demoDocument(record.id);
  return (
    <Dialog title={record.name} drawer="right" onClose={onClose}>
      <dl className="grid grid-cols-2 gap-3 rounded-xl bg-canvas p-3 text-sm">
        {[
          ['Record type', record.category], ['Hospital', record.hospital], ['Doctor', record.doctor],
          ['Date', displayDate(record.date)], ['Source', record.source], ['Verification', record.status],
        ].map(([label, value]) => <div key={label}><dt className="text-xs text-muted">{label}</dt><dd className="mt-1 font-medium">{label === 'Verification' ? <StatusBadge>{value}</StatusBadge> : value}</dd></div>)}
      </dl>
      <section className="my-4"><h3 className="font-semibold">Released notes</h3><p className="mt-1 text-sm leading-6 text-secondary">{record.note}</p></section>
      <div className="flex flex-wrap gap-2">
        <button type="button" className={button} onClick={() => setPreview(!preview)} aria-expanded={preview}><Eye size={16} aria-hidden />{preview ? 'Hide preview' : 'Preview PDF'}</button>
        <a className={button} href={url} download><Download size={16} aria-hidden />Download sample PDF</a>
        <button type="button" className={button} disabled>Share record</button>
        <button type="button" className={button} disabled>Request correction</button>
      </div>
      <p className="my-3 text-xs text-muted">Sharing and correction requests require the patient service.</p>
      {preview && <object data={url} type="application/pdf" aria-label={`Synthetic PDF preview for ${record.name}`} className="h-[56vh] w-full rounded-lg border border-border"><p className="p-3 text-sm">PDF preview is unavailable in this browser. <a href={url} download className="text-primary">Download the sample PDF</a>.</p></object>}
    </Dialog>
  );
}
