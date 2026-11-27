import { Slot, usePathname } from 'expo-router';
import Head from 'expo-router/head';
import { createContext, useContext, useEffect, useState, useSyncExternalStore } from 'react';

import { PublicLink } from '@/components/layout/PublicLink';
import { Brand } from '@/features/home/Brand';
import { homepageClasses } from '@/features/home/styles';
import { useHomeTheme } from '@/features/home/theme';

import { ArrowUpRight, ShieldCheck } from './icons';
import { loadDemoPortal, type PortalData } from './demo';
import { filterRecords, initialFilters } from './model';
import { PatientNavbar, PatientSidebar } from './PatientNavigation';
import { button, control, dashboardPath, Dialog, dischargeSummariesPath, EmptyState, LoadingSkeleton, medicationsPath, panel, primary, recordsPath } from './ui';

const PatientContext = createContext<PortalData | null>(null);
const demoSessionKey = 'medishield.patient.demo';
const sidebarKey = 'medishield.patient.sidebar';

const pageTitles: Readonly<Record<string, string>> = {
  [dashboardPath]: 'Dashboard',
  [recordsPath]: 'Medical Records',
  [medicationsPath]: 'Medications',
  [dischargeSummariesPath]: 'Discharge Summaries',
};

type PortalSession = 'checking' | 'closed' | 'demo';

function readDemoSession(): PortalSession {
  try {
    return sessionStorage.getItem(demoSessionKey) === 'open' ? 'demo' : 'closed';
  } catch {
    return 'closed';
  }
}

function readSidebarPreference() {
  try {
    return localStorage.getItem(sidebarKey) === 'collapsed';
  } catch {
    return false;
  }
}

function subscribeToStorage(onChange: () => void) {
  window.addEventListener('storage', onChange);
  return () => window.removeEventListener('storage', onChange);
}

export function usePatientDemo() {
  const data = useContext(PatientContext);
  if (!data) throw new Error('Patient content requires an active demo session.');
  return data;
}

type DataState = { status: 'loading' | 'offline' | 'error' } | { status: 'ready'; data: PortalData };

export function PatientLayout() {
  const pathname = usePathname();
  const [theme, onTheme] = useHomeTheme();
  const storedSession = useSyncExternalStore(subscribeToStorage, readDemoSession, () => 'checking' as const);
  const storedCollapsed = useSyncExternalStore(subscribeToStorage, readSidebarPreference, () => false);
  const [sessionOverride, setSession] = useState<PortalSession>();
  const [sidebarOverride, setCollapsed] = useState<boolean>();
  const session = sessionOverride ?? storedSession;
  const collapsed = sidebarOverride ?? storedCollapsed;
  const [result, setResult] = useState<DataState>({ status: 'loading' });
  const [attempt, setAttempt] = useState(0);
  const [drawer, setDrawer] = useState(false);
  const [searchOpen, setSearchOpen] = useState(false);
  const [search, setSearch] = useState('');

  useEffect(() => {
    if (session !== 'demo') return;
    const controller = new AbortController();
    loadDemoPortal(controller.signal).then((data) => {
      if (!controller.signal.aborted) setResult({ status: 'ready', data });
    }).catch((error: unknown) => {
      if (!controller.signal.aborted) setResult({ status: error instanceof Error && error.message === 'offline' ? 'offline' : 'error' });
    });
    return () => controller.abort();
  }, [session, attempt]);

  function setDemo(open: boolean) {
    setDrawer(false);
    setSearchOpen(false);
    setSearch('');
    setResult({ status: 'loading' });
    setSession(open ? 'demo' : 'closed');
    try {
      if (open) sessionStorage.setItem(demoSessionKey, 'open');
      else sessionStorage.removeItem(demoSessionKey);
    } catch {
      // Demo access lasts for the current page when browser storage is disabled.
    }
  }

  function toggleSidebar() {
    setCollapsed(!collapsed);
    try {
      localStorage.setItem(sidebarKey, collapsed ? 'expanded' : 'collapsed');
    } catch {
      // The current sidebar still responds when storage is disabled.
    }
  }

  function retry() {
    setResult({ status: 'loading' });
    setAttempt((previous) => previous + 1);
  }

  const page = pathname.startsWith(`${medicationsPath}/`) ? 'Medications' : pageTitles[pathname] ?? 'Patient portal';
  const readyData = result.status === 'ready' ? result.data : undefined;

  return (
    <div className={homepageClasses(theme)} data-theme={theme} data-patient-portal>
      <Head><title>{page} | MediShield AI</title></Head>
      {session === 'demo' ? (
        <div className="flex min-h-full items-start">
          <a href="#patient-content" className={`${button} fixed left-4 top-2 z-50 -translate-y-[150%] focus:translate-y-0`}>Skip to content</a>
          <aside className={`sticky top-0 hidden h-[100dvh] shrink-0 flex-col border-r border-border bg-surface motion-safe:transition-[width] lg:flex ${collapsed ? 'w-[76px]' : 'w-[246px]'}`}>
            <PatientSidebar pathname={pathname} collapsed={collapsed} onToggle={toggleSidebar} onLogout={() => setDemo(false)} />
          </aside>
          <div className="min-w-0 flex-1">
            <PatientNavbar page={page} theme={theme} onTheme={onTheme} onMenu={() => setDrawer(true)} onSearch={() => { setSearch(''); setSearchOpen(true); }} onLogout={() => setDemo(false)} />
            <main id="patient-content" tabIndex={-1} className="mx-auto flex min-w-0 max-w-[1520px] flex-col gap-5 px-3 py-4 sm:px-6 sm:py-6 xl:px-8 xl:py-7">
              <div className="flex items-center gap-2 self-start rounded-lg bg-accent px-2.5 py-1 text-xs font-semibold text-on-accent"><ShieldCheck size={14} aria-hidden /> Demo portal · Synthetic data</div>
              {readyData ? <PatientContext.Provider value={readyData}><Slot /></PatientContext.Provider> : result.status === 'loading' ? (
                <LoadingSkeleton />
              ) : (
                <div className={panel}><EmptyState title={result.status === 'offline' ? 'You’re offline' : 'The demo could not load'} description={result.status === 'offline' ? 'Reconnect to the internet, then try again.' : 'Try loading the demo again.'}><button className={button} onClick={retry} type="button">Retry</button></EmptyState></div>
              )}
              <footer className="pb-2 text-xs text-muted">MediShield AI patient portal preview. For urgent medical concerns, contact your local emergency service.</footer>
            </main>
          </div>
          {drawer && (
            <Dialog title="Patient navigation" drawer="left" onClose={() => setDrawer(false)}>
              <div className="flex min-h-0 flex-1 flex-col"><PatientSidebar pathname={pathname} onNavigate={() => setDrawer(false)} onLogout={() => setDemo(false)} /></div>
            </Dialog>
          )}
          {searchOpen && (
            <Dialog title="Search medical records" onClose={() => setSearchOpen(false)}>
              <input autoFocus type="search" className={`${control} w-full`} aria-label="Search demo records" placeholder="Search by document, hospital, or doctor" value={search} onChange={(event) => setSearch(event.target.value)} />
              {search.trim() && readyData && (
                <div className="mt-3 flex flex-col gap-1">
                  {filterRecords(readyData.records, { ...initialFilters, search }).slice(0, 5).map((record) => (
                    <PublicLink key={record.id} href={{ pathname: recordsPath, params: { record: record.id } }} className="rounded-lg p-2 text-ink no-underline hover:bg-subtle" onClick={() => setSearchOpen(false)}>{record.name}<span className="block text-xs text-muted">{record.hospital}</span></PublicLink>
                  ))}
                  <PublicLink href={{ pathname: recordsPath, params: { search: search.trim() } }} className={button} onClick={() => setSearchOpen(false)}>See search results</PublicLink>
                </div>
              )}
            </Dialog>
          )}
        </div>
      ) : (
        <main className="mx-auto grid min-h-full w-full max-w-xl items-center px-5 py-10">
          {session === 'checking' ? <LoadingSkeleton /> : (
            <section className={`${panel} flex flex-col items-start gap-5 p-6 sm:p-9`}>
              <Brand href="/" />
              <div>
                <ShieldCheck size={27} className="mb-3 text-primary" aria-hidden />
                <h1 className="text-2xl font-semibold tracking-tight">Patient access required</h1>
                <p className="mt-2 text-sm leading-6 text-secondary">Personal medical records require a verified patient account. Patient sign-in is unavailable in this prototype.</p>
              </div>
              <p className="text-sm text-secondary">Explore the portal with fictional records in a demo session.</p>
              <div className="flex flex-wrap gap-2">
                <button className={primary} type="button" onClick={() => setDemo(true)}>Open synthetic demo <ArrowUpRight size={16} aria-hidden /></button>
                <PublicLink href="/login" className={button}>Go to sign in</PublicLink>
              </div>
            </section>
          )}
        </main>
      )}
    </div>
  );
}
