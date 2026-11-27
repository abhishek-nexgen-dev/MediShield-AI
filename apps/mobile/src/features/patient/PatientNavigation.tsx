
import { PublicLink } from '@/components/layout/PublicLink';
import { Brand } from '@/features/home/Brand';
import { isTheme, type HomeTheme } from '@/features/home/theme';

import { Activity, Bell, ChevronDown, ChevronRight, ClipboardList, FileHeart, FlaskConical, Headphones, HeartHandshake, Hospital, LayoutDashboard, LogOut, Menu, PanelLeftClose, PanelLeftOpen, Pill, Search, Settings, ShieldCheck, Sparkles, SunMoon, UserRound, UsersRound, type LucideIcon } from './icons';
import { notifications } from './demo';
import { displayDate, displayTime } from './model';
import { dashboardPath, dischargeSummariesPath, iconButton, medicationsPath, recordsPath } from './ui';

type NavigationItem = { label: string; icon: LucideIcon; href?: typeof dashboardPath | typeof recordsPath | typeof medicationsPath | typeof dischargeSummariesPath };
const groups: { label: string; items: NavigationItem[] }[] = [
  { label: 'Overview', items: [{ label: 'Dashboard', icon: LayoutDashboard, href: dashboardPath }] },
  { label: 'My health', items: [
    { label: 'Medical Records', icon: FileHeart, href: recordsPath }, { label: 'Lab Reports', icon: FlaskConical },
    { label: 'Medications', icon: Pill, href: medicationsPath }, { label: 'Health Vitals', icon: Activity },
    { label: 'Hospital Visits', icon: Hospital }, { label: 'Discharge Summaries', icon: ClipboardList, href: dischargeSummariesPath },
  ] },
  { label: 'Connected care', items: [
    { label: 'Referrals', icon: HeartHandshake }, { label: 'AI Health Assistant', icon: Sparkles }, { label: 'Family & Caregivers', icon: UsersRound },
  ] },
  { label: 'Account & preferences', items: [
    { label: 'Privacy & Consent', icon: ShieldCheck }, { label: 'Settings', icon: Settings }, { label: 'Help & Support', icon: Headphones },
  ] },
];

const dropdown = 'absolute right-0 top-full z-30 mt-2 max-w-[calc(100vw-2rem)] rounded-xl border border-border bg-surface p-2 text-sm shadow-lg';

function Avatar() {
  return <span aria-hidden className="inline-flex size-8 shrink-0 items-center justify-center rounded-full bg-accent text-xs font-semibold text-on-accent">AM</span>;
}

function ProfileMenu({ onLogout, onNavigate, sidebar = false }: { onLogout: () => void; onNavigate?: () => void; sidebar?: boolean }) {
  return (
    <details className="relative block">
      <summary className="flex min-h-10 cursor-pointer list-none items-center gap-2 rounded-lg px-1.5 hover:bg-subtle [&::-webkit-details-marker]:hidden" aria-label="Patient profile menu">
        <Avatar />
        {sidebar && <span className="min-w-0 flex-1 text-left"><span className="block truncate text-sm font-semibold">Aarav Mehta</span><span className="block text-xs text-muted">Patient account</span></span>}
        {sidebar && <ChevronDown size={15} aria-hidden />}
      </summary>
      <div className={`${dropdown} w-56 ${sidebar ? '!bottom-full !top-auto mb-2' : ''}`}>
        <PublicLink href={{ pathname: recordsPath, params: { focus: 'profile' } }} onClick={(event) => { event.currentTarget.closest('details')?.removeAttribute('open'); onNavigate?.(); }} className="flex items-center gap-2 rounded-lg px-2 py-2 font-medium text-ink no-underline hover:bg-subtle"><UserRound size={16} aria-hidden />My Profile</PublicLink>
        {['Account Settings', 'Privacy & Consent', 'Help & Support'].map((label) => <div key={label} className="flex justify-between gap-1 px-2 py-2 text-muted"><span>{label}</span><span className="text-[.65rem]">Soon</span></div>)}
        <button type="button" onClick={onLogout} className="flex w-full cursor-pointer items-center gap-2 rounded-lg bg-transparent px-2 py-2 text-left font-medium text-ink hover:bg-subtle"><LogOut size={16} aria-hidden />Log out of demo</button>
      </div>
    </details>
  );
}

export function PatientSidebar({ pathname, collapsed = false, onToggle, onNavigate, onLogout }: { pathname: string; collapsed?: boolean; onToggle?: () => void; onNavigate?: () => void; onLogout: () => void }) {
  return (
    <>
      <div className={`flex min-h-[72px] items-center gap-2 border-b border-border px-3 py-2 ${collapsed ? 'flex-col justify-center' : 'justify-between'}`}>
        <div className={collapsed ? 'w-8 overflow-hidden' : 'pl-1'}>
          <Brand href="/" />
          {!collapsed && <p className="ml-10 -mt-1 text-xs font-medium text-muted">Patient portal</p>}
        </div>
        {onToggle && <button type="button" className={iconButton} onClick={onToggle} aria-label={collapsed ? 'Expand sidebar' : 'Collapse sidebar'} aria-expanded={!collapsed}>{collapsed ? <PanelLeftOpen size={17} aria-hidden /> : <PanelLeftClose size={17} aria-hidden />}</button>}
      </div>
      <nav aria-label="Patient navigation" className="flex-1 overflow-y-auto px-2 py-4">
        {groups.map((group) => (
          <section key={group.label} aria-label={group.label} className="mb-5 last:mb-0">
            <h2 className={collapsed ? 'sr-only' : 'mb-1.5 px-2 text-[.69rem] font-semibold uppercase tracking-[.09em] text-muted'}>{group.label}</h2>
            {group.items.map(({ label, href, icon: Icon }) => {
              const active = !!href && (pathname === href || pathname.startsWith(`${href}/`));
              const className = `my-0.5 flex min-h-9 items-center gap-2.5 rounded-lg px-2 text-[.81rem] no-underline ${collapsed ? 'justify-center' : ''}`;
              return href ? (
                <PublicLink key={label} href={href} onClick={onNavigate} title={collapsed ? label : undefined} aria-current={pathname === href ? 'page' : active ? 'location' : undefined} className={`${className} ${active ? 'bg-accent font-semibold text-on-accent' : 'font-medium text-secondary hover:bg-subtle'}`}><Icon size={17} className="shrink-0" aria-hidden /><span className={collapsed ? 'sr-only' : ''}>{label}</span></PublicLink>
              ) : (
                <div key={label} title={`${label} · Coming soon`} className={`${className} text-muted`}><Icon size={17} className="shrink-0" aria-hidden /><span className={collapsed ? 'sr-only' : 'min-w-0 flex-1'}>{label}</span><span className={collapsed ? 'sr-only' : 'text-[.61rem]'}>Soon</span></div>
              );
            })}
          </section>
        ))}
      </nav>
      <div className={`border-t border-border p-2 ${collapsed ? 'mx-auto w-full pl-2' : ''}`}>
        <ProfileMenu onLogout={onLogout} onNavigate={onNavigate} sidebar={!collapsed} />
      </div>
    </>
  );
}

export function NotificationList({ limit }: { limit?: number }) {
  const items = limit ? notifications.slice(0, limit) : notifications;
  return (
    <ul className="m-0 list-none space-y-0 p-0">
      {items.map((item) => (
        <li key={item.title} className="flex gap-2.5 border-b border-border py-2.5 last:border-b-0">
          <span aria-label={item.unread ? 'Unread' : 'Read'} className={`mt-2 size-1.5 shrink-0 rounded-full ${item.unread ? 'bg-primary' : 'bg-border'}`} />
          <div>
            {item.recordId ? <PublicLink href={{ pathname: recordsPath, params: { record: item.recordId } }} onClick={(event) => event.currentTarget.closest('details')?.removeAttribute('open')} className="font-semibold text-ink no-underline hover:text-primary">{item.title}</PublicLink> : <p className="font-semibold">{item.title}</p>}
            <p className="mt-0.5 text-xs leading-5 text-secondary">{item.detail}</p>
            <time dateTime={item.date} className="text-xs text-muted">{displayDate(item.date)} · {displayTime(item.date)}</time>
          </div>
        </li>
      ))}
    </ul>
  );
}

type NavbarProps = {
  page: string;
  theme: HomeTheme;
  onTheme: (theme: HomeTheme) => void;
  onMenu: () => void;
  onSearch: () => void;
  onLogout: () => void;
};

export function PatientNavbar({ page, theme, onTheme, onMenu, onSearch, onLogout }: NavbarProps) {
  const unread = notifications.filter((item) => item.unread).length;
  return (
    <header className="sticky top-0 z-20 flex min-h-[68px] items-center justify-between gap-1 border-b border-border bg-surface px-3 sm:gap-3 sm:px-6">
      <div className="flex min-w-0 items-center gap-2">
        <button type="button" onClick={onMenu} aria-label="Open patient navigation" className={`${iconButton} lg:hidden`}><Menu size={20} aria-hidden /></button>
        <nav aria-label="Breadcrumb" className="flex min-w-0 items-center gap-1.5 text-sm">
          <PublicLink href={dashboardPath} className="hidden whitespace-nowrap text-muted no-underline hover:text-primary sm:inline">Patient portal</PublicLink>
          <ChevronRight size={14} className="hidden shrink-0 text-muted sm:block" aria-hidden />
          <span aria-current="page" className="truncate font-semibold">{page}</span>
        </nav>
      </div>
      <div className="flex shrink-0 items-center gap-1 text-sm sm:gap-2">
        <button type="button" className={iconButton} onClick={onSearch} aria-label="Search medical records"><Search size={19} aria-hidden /></button>
        <label className="flex min-h-10 items-center gap-1 rounded-lg px-1 text-secondary hover:bg-subtle sm:px-2">
          <SunMoon size={17} className="hidden sm:block" aria-hidden />
          <select aria-label="Portal theme" className="w-[3.8rem] cursor-pointer bg-transparent text-xs text-ink sm:w-auto" value={theme} onChange={(event) => { if (isTheme(event.target.value)) onTheme(event.target.value); }}>
            <option value="system" className="bg-surface">System</option><option value="light" className="bg-surface">Light</option><option value="dark" className="bg-surface">Dark</option>
          </select>
        </label>
        <details className="relative">
          <summary className={`${iconButton} relative list-none [&::-webkit-details-marker]:hidden`} aria-label={`Notifications, ${unread} unread`}><Bell size={19} aria-hidden /><span aria-hidden className="absolute right-0.5 top-0.5 rounded-full bg-primary px-1 text-[.63rem] font-semibold leading-4 text-on-primary">{unread}</span></summary>
          <div className={`${dropdown} w-80 max-sm:fixed max-sm:inset-x-3 max-sm:top-[58px] max-sm:mt-0 max-sm:w-auto max-sm:max-w-none`}><h2 className="px-2 pt-1 text-base font-semibold">Notifications</h2><div className="max-h-[60vh] overflow-auto px-2"><NotificationList /></div></div>
        </details>
        <ProfileMenu onLogout={onLogout} />
      </div>
    </header>
  );
}
