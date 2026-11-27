export const categories = ['Medical History', 'Lab Reports', 'Prescriptions', 'Imaging & Scans', 'Discharge Summaries', 'Vaccinations', 'Other Documents'] as const;
export type Category = typeof categories[number];
export const statuses = ['Verified', 'Pending Review', 'Patient Uploaded', 'Corrected', 'Archived'] as const;
export type RecordStatus = typeof statuses[number];

export type MedicalRecord = {
  id: string;
  name: string;
  category: Category;
  hospital: string;
  doctor: string;
  date: string;
  source: 'Hospital release' | 'Patient upload';
  status: RecordStatus;
  note: string;
};

export type Medication = {
  id: string;
  name: string;
  dosage: string;
  frequency: string;
  doctor: string;
  hospital: string;
  hospitalId: string;
  startsOn: string;
  endsOn: string;
  instructions: string;
  status: 'Active' | 'Completed';
  recordId?: string;
};

export function medicationPeriod({ startsOn, endsOn }: Medication) {
  return `${displayDate(startsOn)} – ${displayDate(endsOn)}`;
}

export type RecordFilters = {
  search: string;
  hospital: string;
  category: string;
  from: string;
  to: string;
  status: string;
  sort: 'newest' | 'oldest' | 'name';
};

export const initialFilters: RecordFilters = { search: '', hospital: '', category: '', from: '', to: '', status: '', sort: 'newest' };

export function filterRecords(records: readonly MedicalRecord[], filters: RecordFilters) {
  const query = filters.search.trim().toLowerCase();
  return records.filter((record) => (
    (!query || [record.name, record.hospital, record.doctor, record.category].some((value) => value.toLowerCase().includes(query))) &&
    (!filters.category || record.category === filters.category) &&
    (!filters.hospital || record.hospital === filters.hospital) &&
    (!filters.status || record.status === filters.status) &&
    (!filters.from || record.date >= filters.from) &&
    (!filters.to || record.date <= filters.to)
  )).sort((a, b) => {
    if (filters.sort === 'name') return a.name.localeCompare(b.name, 'en');
    return filters.sort === 'oldest' ? a.date.localeCompare(b.date) : b.date.localeCompare(a.date);
  });
}

export function paginateRecords<T>(items: readonly T[], requestedPage: number, pageSize: number) {
  const pageCount = Math.max(1, Math.ceil(items.length / pageSize));
  const page = Math.max(1, Math.min(requestedPage, pageCount));
  return { page, pageCount, items: items.slice((page - 1) * pageSize, page * pageSize) };
}

const dateFormat = new Intl.DateTimeFormat('en-IN', { day: 'numeric', month: 'short', year: 'numeric', timeZone: 'Asia/Kolkata' });
const timeFormat = new Intl.DateTimeFormat('en-IN', { hour: 'numeric', minute: '2-digit', timeZone: 'Asia/Kolkata' });

export function displayDate(date: string | Date) {
  return dateFormat.format(new Date(date));
}

export function displayTime(date: string) {
  return timeFormat.format(new Date(date));
}
