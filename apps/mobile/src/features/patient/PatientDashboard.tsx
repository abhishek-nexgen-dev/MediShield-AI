import type { Href } from 'expo-router';
import Head from 'expo-router/head';

import { PublicLink } from '@/components/layout/PublicLink';

import { ArrowRight, Bell, CalendarDays, Download, FileHeart, FlaskConical, Headphones, Hospital, Pill, Share2, Sparkles, UsersRound } from './icons';
import { visits } from './demo';
import { HealthVitals } from './HealthVitals';
import { displayDate, medicationPeriod } from './model';
import { usePatientDemo } from './PatientLayout';
import { NotificationList } from './PatientNavigation';
import { demoDocument } from './RecordViews';
import { button, dischargeSummariesPath, iconButton, medicationsPath, PageHeader, panel, primary, RecordIcon, recordsPath, Section, StatusBadge, SummaryCard } from './ui';

const reportPath = { pathname: recordsPath, params: { category: 'Lab Reports' } } as const;
const quickActions: { label: string; icon: typeof FileHeart; href?: Href }[] = [
  { label: 'View Medical Records', icon: FileHeart, href: recordsPath },
  { label: 'Download Reports', icon: Download, href: reportPath },
  { label: 'View Prescriptions', icon: Pill, href: medicationsPath },
  { label: 'Share Medical Records', icon: Share2 },
  { label: 'Manage Caregiver Access', icon: UsersRound },
  { label: 'Contact Support', icon: Headphones },
];

export function PatientDashboard() {
  const { patient, records, medications } = usePatientDemo();
  const activeMedications = medications.filter(({ status }) => status === 'Active');
  const reports = records.filter(({ category, status }) => (category === 'Lab Reports' || category === 'Imaging & Scans') && status !== 'Pending Review' && status !== 'Archived');

  return (
    <>
      <Head><title>My Health Dashboard | MediShield AI</title></Head>
      <div className="flex flex-col gap-3">
        <p className="text-xs font-semibold uppercase tracking-[.09em] text-primary">My Health Dashboard</p>
        <PageHeader title={`Welcome back, ${patient.name.split(' ')[0]}!`} description="Stay informed and manage your healthcare journey from one connected place.">
          <PublicLink href={recordsPath} className={primary}>View Medical Records <ArrowRight size={16} aria-hidden /></PublicLink>
        </PageHeader>
        <p className="flex items-center gap-1.5 text-xs text-muted"><CalendarDays size={14} aria-hidden />{displayDate(new Date())}</p>
      </div>
      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <SummaryCard label="Medical Records" count={records.length} icon={FileHeart} action={{ label: 'View records', href: recordsPath }} />
        <SummaryCard label="Active Prescriptions" count={activeMedications.length} icon={Pill} action={{ label: 'View medications', href: medicationsPath }} />
        <SummaryCard label="Hospital Visits" count={visits.length} icon={Hospital} action={{ label: 'View history', href: { pathname: recordsPath, params: { category: 'Medical History' } } }} />
        <SummaryCard label="Lab Reports" count={records.filter(({ category, status }) => category === 'Lab Reports' && status !== 'Archived').length} icon={FlaskConical} action={{ label: 'View reports', href: reportPath }} />
      </div>
      <div className="grid min-w-0 gap-4 xl:grid-cols-[minmax(0,1.8fr)_minmax(0,1fr)]">
        <HealthVitals />
        <Section title="Notifications & Pending Actions" description="Updates from the demo care network." action={<Bell size={19} className="text-primary" aria-hidden />}><NotificationList /></Section>
      </div>
      <div className="grid min-w-0 gap-4 xl:grid-cols-2">
        <Section title="Recent Medical Reports" description="Access your latest medical reports and healthcare documents." action={<PublicLink href={reportPath} className={button}>View All Reports</PublicLink>}>
          <ul className="m-0 list-none divide-y divide-border p-0">
            {reports.slice(0, 4).map((record) => (
              <li key={record.id} className="flex items-start gap-2 py-2.5 last:pb-0">
                <RecordIcon />
                <div className="min-w-0 flex-1">
                  <p className="font-semibold leading-5">{record.name}</p>
                  <p className="text-xs leading-5 text-secondary">{record.category} · {record.hospital}</p>
                  <div className="flex flex-wrap items-center gap-1.5 text-xs text-muted"><time dateTime={record.date}>{displayDate(record.date)}</time><StatusBadge>{record.status}</StatusBadge></div>
                </div>
                <PublicLink href={{ pathname: recordsPath, params: { record: record.id } }} className={iconButton} aria-label={`View ${record.name}`}><ArrowRight size={16} aria-hidden /></PublicLink>
                <a href={demoDocument(record.id)} download className={iconButton} aria-label={`Download sample ${record.name}`}><Download size={16} aria-hidden /></a>
              </li>
            ))}
          </ul>
        </Section>
        <Section title="Current Medications" action={<PublicLink href={medicationsPath} className={button}>View All Medications</PublicLink>}>
          <ul className="m-0 list-none divide-y divide-border p-0">
            {activeMedications.map((item) => (
              <li key={item.id} className="py-3 first:pt-0 last:pb-0">
                <div className="flex flex-wrap items-center justify-between gap-1"><p className="font-semibold">{item.name}</p><StatusBadge>{item.status}</StatusBadge></div>
                <p className="text-sm text-secondary">{item.dosage} · {item.frequency}</p>
                <p className="mt-1 text-xs leading-5 text-secondary">{item.doctor} · {medicationPeriod(item)}<br />{item.instructions}</p>
              </li>
            ))}
          </ul>
        </Section>
      </div>
      <div className="grid min-w-0 gap-4 xl:grid-cols-2">
        <Section title="Recent Hospital Visits" action={<PublicLink href={dischargeSummariesPath} className={button}>Discharge Summaries</PublicLink>}>
          <ol className="m-0 list-none divide-y divide-border p-0">
            {visits.map((visit) => (
              <li key={visit.recordId} className="flex items-start gap-2 py-3 first:pt-0 last:pb-0">
                <span className="inline-flex size-8 shrink-0 items-center justify-center rounded-lg bg-accent text-on-accent"><Hospital size={16} aria-hidden /></span>
                <div className="min-w-0 flex-1">
                  <p className="font-semibold">{visit.hospital}</p>
                  <p className="text-xs leading-5 text-secondary">{visit.doctor} · {visit.department}</p>
                  <div className="flex flex-wrap items-center gap-1.5 text-xs text-muted">{displayDate(visit.date)} · {visit.type}<StatusBadge>{visit.status}</StatusBadge></div>
                </div>
                <PublicLink className={iconButton} href={{ pathname: recordsPath, params: { record: visit.recordId } }} aria-label={`View details for ${visit.hospital} visit on ${displayDate(visit.date)}`}><ArrowRight size={16} aria-hidden /></PublicLink>
              </li>
            ))}
          </ol>
        </Section>
        <Section title="Quick Actions">
          <div className="grid grid-cols-2 gap-2">
            {quickActions.map(({ label, icon: Icon, href }) => (
              href
                ? <PublicLink key={label} href={href} className={`${button} justify-start text-left`}><Icon size={16} className="shrink-0 text-primary" aria-hidden />{label}</PublicLink>
                : <div key={label} className="flex items-center gap-2 rounded-lg border border-border p-2 text-xs text-muted"><Icon size={16} className="shrink-0" aria-hidden /><span>{label}<span className="block text-[.65rem]">Coming soon</span></span></div>
            ))}
          </div>
        </Section>
      </div>
      <section className={`${panel} flex flex-wrap items-center justify-between gap-4 p-4 sm:p-5`}>
        <div className="flex items-start gap-3">
          <span className="inline-flex size-10 shrink-0 items-center justify-center rounded-xl bg-accent text-on-accent"><Sparkles size={19} aria-hidden /></span>
          <div><h2 className="text-lg font-semibold tracking-tight">Understand Your Health Records Better.</h2><p className="text-sm text-secondary">Get simple AI-assisted explanations of your available medical records and reports.</p><p className="mt-1 text-xs text-muted">AI explanations cannot diagnose, prescribe, or replace professional medical advice.</p></div>
        </div>
        <button className={button} type="button" disabled>Ask AI Assistant · Coming soon</button>
      </section>
    </>
  );
}
