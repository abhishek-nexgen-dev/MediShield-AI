import { useState } from 'react';

import { UploadCloud } from './icons';
import { categories, type MedicalRecord } from './model';
import { button, control, Dialog } from './ui';

const fileLimit = 10 * 1024 * 1024;
const fileTypes = ['application/pdf', 'image/jpeg', 'image/png'];

export function UploadDocumentModal({ onClose }: { onClose: () => void }) {
  const [fileFeedback, setFileFeedback] = useState('');

  function validateSample(file: File | undefined) {
    if (!file) return;
    if (!file.size || file.size > fileLimit || !fileTypes.includes(file.type)) {
      setFileFeedback('Choose a sample PDF, JPG, or PNG up to 10 MB.');
      return;
    }
    setFileFeedback('File type and size are valid for this preview. Upload requires the patient service.');
  }

  return (
    <Dialog title="Upload document preview" onClose={onClose}>
      <p className="mb-4 text-sm text-secondary">Use fictional information. Patient uploads would remain separate from hospital-verified records while awaiting review.</p>
      <div className="grid gap-3 text-sm sm:grid-cols-2">
        <label className="grid gap-1">Document title<input className={control} /></label>
        <label className="grid gap-1">Document category<select className={control}>{categories.map((item) => <option key={item}>{item}</option>)}</select></label>
        <label className="grid gap-1">Hospital name<input className={control} /></label>
        <label className="grid gap-1">Document date<input type="date" className={control} /></label>
        <label className="grid gap-1 sm:col-span-2">Description (optional)<textarea className={control} rows={2} /></label>
      </div>
      <label className="mt-4 flex cursor-pointer flex-col items-center gap-2 rounded-xl border border-dashed border-control bg-canvas p-4 text-sm" onDragOver={(event) => event.preventDefault()} onDrop={(event) => { event.preventDefault(); validateSample(event.dataTransfer.files[0]); }}>
        <UploadCloud size={21} aria-hidden />Drop or choose a sample file
        <span className="text-xs text-muted">PDF, JPG, or PNG up to 10 MB</span>
        <input aria-label="Choose a sample file" type="file" accept=".pdf,.jpg,.jpeg,.png" className="max-w-full text-xs" onChange={(event) => { validateSample(event.target.files?.[0]); }} />
      </label>
      <p role="status" className="my-2 text-sm text-secondary">{fileFeedback}</p>
      <button type="button" className={button} disabled>Upload unavailable</button>
    </Dialog>
  );
}

export function ShareRecordsModal({ records, onClose }: { records: MedicalRecord[]; onClose: () => void }) {
  const [selected, setSelected] = useState<string[]>([]);

  return (
    <Dialog title="Share records preview" onClose={onClose}>
      <p className="mb-3 text-sm text-secondary">Sharing requires a verified account and a recipient authorized by the patient service.</p>
      <fieldset className="m-0 min-w-0 p-0">
        <legend className="mb-2 text-sm font-semibold">Select sample records</legend>
        <div className="max-h-44 overflow-auto rounded-lg border border-border p-2">
          {records.filter((record) => record.source === 'Hospital release' && record.status !== 'Archived').map((record) => (
            <label key={record.id} className="flex min-h-9 items-center gap-2 text-sm"><input type="checkbox" className="accent-primary" checked={selected.includes(record.id)} onChange={(event) => setSelected(event.target.checked ? [...selected, record.id] : selected.filter((id) => id !== record.id))} />{record.name}</label>
          ))}
        </div>
      </fieldset>
      <div className="my-3 grid gap-3 text-sm sm:grid-cols-2">
        <label className="grid gap-1">Authorized recipient<select className={control} disabled><option>No verified recipients</option></select></label>
        <label className="grid gap-1">Access expiration<select className={control} disabled><option>Requires a verified recipient</option></select></label>
      </div>
      <p className="mb-3 rounded-lg bg-canvas p-3 text-sm text-secondary" role="status">{selected.length} selected. A verified recipient would receive read-only access to the selected records for the authorized period.</p>
      <button type="button" className={button} disabled>Confirm sharing unavailable</button>
    </Dialog>
  );
}
