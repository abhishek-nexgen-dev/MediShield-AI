import type { Category, MedicalRecord, Medication } from './model';

export const demoPatient = {
  name: 'Aarav Mehta',
  id: 'DEMO-001',
  age: 34,
  bloodGroup: 'O+',
  allergies: ['Pollen'],
  conditions: [],
  updated: '2026-11-20',
};

const hospitals = ['Greenfield Medical Centre', 'Parkview Specialty Hospital'] as const;
const doctors = ['Dr. Neha Rao', 'Dr. Rohan Iyer', 'Dr. Mira Shah'] as const;

const documents: [string, Category, string, string, 0 | 1, 0 | 1 | 2, MedicalRecord['status']?][] = [
  ['Complete blood count', 'Lab Reports', '2026-11-20', 'Sample laboratory report released to the patient portal.', 0, 0],
  ['ECG report', 'Lab Reports', '2026-11-18', 'Sample cardiac investigation document.', 1, 1],
  ['Chest X-ray report', 'Imaging & Scans', '2026-11-14', 'Sample radiology report for document preview.', 1, 1],
  ['Liver function panel', 'Lab Reports', '2026-11-11', 'Sample laboratory panel with an amended document label.', 0, 0, 'Corrected'],
  ['Follow-up prescription', 'Prescriptions', '2026-11-08', 'Sample prescription record. Clinical instructions are omitted from the demo.', 0, 0],
  ['Follow-up consultation', 'Medical History', '2026-11-08', 'A sample follow-up visit was recorded.', 0, 0],
  ['Discharge summary', 'Discharge Summaries', '2026-10-27', 'Sample discharge event released following a fictional hospital stay.', 1, 1],
  ['Hospital admission summary', 'Medical History', '2026-10-25', 'A sample inpatient encounter was opened.', 1, 1],
  ['Specialist referral', 'Other Documents', '2026-10-12', 'Fictional referral to the cardiology department.', 0, 2],
  ['Vaccination record', 'Vaccinations', '2026-09-23', 'An immunization record was filed in the demo chart.', 0, 2],
  ['Visit notes', 'Other Documents', '2026-09-10', 'Example document added by the demo patient.', 0, 0, 'Patient Uploaded'],
  ['External imaging summary', 'Imaging & Scans', '2026-08-30', 'Example document awaiting review.', 1, 1, 'Pending Review'],
  ['Outpatient examination', 'Medical History', '2026-08-21', 'A sample outpatient examination was recorded.', 0, 2],
  ['Prior lab report', 'Lab Reports', '2026-08-12', 'Archived sample report.', 0, 0, 'Archived'],
];

export const demoRecords = documents.map(([name, category, date, note, hospital, doctor, status = 'Verified'], index): MedicalRecord => ({
  id: `demo-${String(index + 1).padStart(2, '0')}`,
  name, category, date, note, hospital: hospitals[hospital], doctor: doctors[doctor], status,
  source: status === 'Patient Uploaded' || status === 'Pending Review' ? 'Patient upload' : 'Hospital release',
}));

export async function loadDemoPortal(signal: AbortSignal) {
  signal.throwIfAborted();
  if (!navigator.onLine) throw new Error('offline');
  return { patient: demoPatient, records: demoRecords, medications };
}

export type PortalData = Awaited<ReturnType<typeof loadDemoPortal>>;

const medications: Medication[] = [
  {
    id: 'demo-med-01',
    name: 'Example prescription A',
    dosage: '1 tablet (sample)',
    frequency: 'Once daily',
    doctor: doctors[0],
    hospital: hospitals[0],
    hospitalId: 'demo-hospital-01',
    startsOn: '2026-11-20',
    endsOn: '2026-12-04',
    instructions: 'Demo instructions only',
    status: 'Active',
  },
  {
    id: 'demo-med-02',
    name: 'Example prescription B',
    dosage: '1 capsule (sample)',
    frequency: 'Once daily',
    doctor: doctors[2],
    hospital: hospitals[0],
    hospitalId: 'demo-hospital-01',
    startsOn: '2026-11-18',
    endsOn: '2026-12-02',
    instructions: 'Demo instructions only',
    status: 'Active',
  },
  {
    id: 'demo-med-03',
    name: 'Follow-up prescription',
    dosage: 'Not recorded',
    frequency: 'Not recorded',
    doctor: doctors[0],
    hospital: hospitals[0],
    hospitalId: 'demo-hospital-01',
    startsOn: '2026-11-08',
    endsOn: '2026-11-15',
    instructions: 'Clinical instructions are omitted from the demo.',
    status: 'Completed',
    recordId: 'demo-05',
  },
  {
    id: 'demo-med-04',
    name: 'Example discharge prescription',
    dosage: 'Not recorded',
    frequency: 'Not recorded',
    doctor: doctors[1],
    hospital: hospitals[1],
    hospitalId: 'demo-hospital-02',
    startsOn: '2026-10-27',
    endsOn: '2026-11-03',
    instructions: 'Clinical instructions are omitted from the demo.',
    status: 'Completed',
  },
];

export const visits = [
  { hospital: hospitals[0], doctor: doctors[0], department: 'General Medicine', date: '2026-11-08', type: 'Follow-up', status: 'Completed', recordId: 'demo-06' },
  { hospital: hospitals[1], doctor: doctors[1], department: 'Cardiology', date: '2026-10-25', type: 'Inpatient', status: 'Discharged', recordId: 'demo-08' },
  { hospital: hospitals[0], doctor: doctors[2], department: 'General Medicine', date: '2026-08-21', type: 'Outpatient', status: 'Completed', recordId: 'demo-13' },
];

export const notifications = [
  { title: 'New medical report available', detail: 'A sample blood test report has been released.', date: '2026-11-20T10:15:00+05:30', unread: true, recordId: 'demo-01' },
  { title: 'Follow-up reminder', detail: 'A follow-up reminder was added to your demo account.', date: '2026-11-19T14:00:00+05:30', unread: true },
  { title: 'Referral update', detail: 'A sample specialist referral is in your records.', date: '2026-11-18T10:30:00+05:30', unread: false, recordId: 'demo-09' },
  { title: 'Consent request', detail: 'This demo shows a pending request for your review.', date: '2026-11-16T13:00:00+05:30', unread: false },
  { title: 'Hospital record linking request', detail: 'A sample request is pending verification.', date: '2026-11-15T11:00:00+05:30', unread: false },
];

export const vitalDate = '2026-11-20T09:25:00+05:30';
export const demoVitals = [
  { name: 'Heart rate', value: '72', unit: 'bpm', readings: [74, 75, 72, 76, 73, 77, 75, 73, 76, 74, 75, 76, 74, 73, 74, 71, 73, 72] },
  { name: 'Blood pressure', value: '118/76', unit: 'mmHg', readings: [121, 122, 119, 120, 121, 119, 120, 117, 120, 119, 121, 118, 119, 117, 121, 119, 120, 118] },
  { name: 'Oxygen saturation', value: '98', unit: '%', readings: [97, 98, 98, 99, 98, 98, 99, 98, 99, 98, 98, 99, 98, 99, 98, 98, 99, 98] },
  { name: 'Body temperature', value: '36.7', unit: '°C', readings: [36.6, 36.8, 36.5, 36.7, 36.9, 36.5, 36.7, 36.5, 36.6, 36.8, 36.7, 36.6, 36.6, 36.8, 36.7, 36.6, 36.8, 36.7] },
];
