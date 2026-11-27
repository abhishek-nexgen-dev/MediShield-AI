import type { Href } from 'expo-router';
import { useEffect, useRef, type ReactNode } from 'react';

import { PublicLink } from '@/components/layout/PublicLink';

import { ArrowUpRight, FileHeart, Inbox, X, type LucideIcon } from './icons';

export const dashboardPath = '/patient/dashboard';
export const recordsPath = '/patient/medical-records';
export const medicationsPath = '/patient/medications';
export const dischargeSummariesPath = '/patient/discharge-summaries';
export const panel = 'rounded-2xl border border-border bg-surface';
export const control = 'min-h-10 rounded-lg border border-border bg-surface px-3 py-2 text-sm text-ink';
const buttonBase = 'inline-flex min-h-10 cursor-pointer items-center justify-center gap-2 rounded-lg border px-3.5 py-2 text-center text-sm font-semibold no-underline disabled:cursor-not-allowed disabled:opacity-60';
export const button = `${buttonBase} border-border bg-surface text-ink hover:bg-subtle`;
export const primary = `${buttonBase} border-primary bg-primary text-on-primary hover:border-primary-hover hover:bg-primary-hover`;
export const iconButton = 'inline-flex size-10 shrink-0 cursor-pointer items-center justify-center rounded-lg bg-transparent text-secondary hover:bg-subtle';

export function PageHeader({ title, description, children }: { title: string; description: string; children?: ReactNode }) {
  return (
    <header className="flex flex-wrap items-end justify-between gap-4">
      <div>
        <h1 className="text-[clamp(1.75rem,4vw,2.25rem)] font-semibold leading-tight tracking-[-.045em]">{title}</h1>
        <p className="mt-1.5 max-w-2xl text-sm leading-6 text-secondary sm:text-base">{description}</p>
      </div>
      {children}
    </header>
  );
}

export function Section({ title, description, action, children, className = '' }: { title: string; description?: string; action?: ReactNode; children: ReactNode; className?: string }) {
  return (
    <section className={`${panel} min-w-0 p-4 sm:p-5 ${className}`}>
      <header className="mb-4 flex flex-wrap items-start justify-between gap-2">
        <div>
          <h2 className="text-lg font-semibold tracking-tight">{title}</h2>
          {description && <p className="mt-1 text-sm text-secondary">{description}</p>}
        </div>
        {action}
      </header>
      {children}
    </section>
  );
}

export function SummaryCard({ label, count, icon: Icon, action }: { label: string; count: number; icon: LucideIcon; action?: { label: string; href: Href } }) {
  return (
    <article className={`${panel} flex min-w-0 flex-col gap-2 p-3.5 sm:p-4`}>
      <div className="mb-1 flex items-center justify-between gap-2">
        <span className="inline-flex size-9 items-center justify-center rounded-lg bg-accent text-on-accent"><Icon size={18} aria-hidden /></span>
        {action && (
          <PublicLink href={action.href} className={iconButton} aria-label={action.label} title={action.label}><ArrowUpRight size={17} aria-hidden /></PublicLink>
        )}
      </div>
      <p className="text-2xl font-semibold leading-none tracking-tight">{count}</p>
      <h2 className="text-sm font-medium text-secondary">{label}</h2>
    </article>
  );
}

export function StatusBadge({ children }: { children: string }) {
  const positive = ['Verified', 'Active', 'Completed', 'Discharged'].includes(children);
  return <span className={`inline-flex w-fit rounded-full px-2 py-1 text-xs font-medium ${positive ? 'bg-accent text-on-accent' : 'bg-subtle text-secondary'}`}>{children}</span>;
}

export function EmptyState({ title, description, children }: { title: string; description: string; children?: ReactNode }) {
  return (
    <div className="flex flex-col items-center gap-2 px-4 py-10 text-center" role="status">
      <Inbox size={25} className="text-muted" aria-hidden />
      <h2 className="font-semibold">{title}</h2>
      <p className="max-w-sm text-sm text-secondary">{description}</p>
      {children}
    </div>
  );
}

export function LoadingSkeleton() {
  return (
    <div role="status" aria-label="Loading patient portal" className="flex flex-col gap-4" data-patient-loading>
      <span className="sr-only">Loading patient portal</span>
      <div className="h-20 rounded-2xl bg-subtle motion-safe:animate-pulse" />
      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        {[0, 1, 2, 3].map((item) => <div key={item} className="h-28 rounded-2xl bg-subtle motion-safe:animate-pulse" />)}
      </div>
    </div>
  );
}

export function Dialog({ title, children, onClose, drawer }: { title: string; children: ReactNode; onClose: () => void; drawer?: 'left' | 'right' }) {
  const ref = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    const dialog = ref.current;
    if (!dialog?.open) dialog?.showModal();
    return () => dialog?.close();
  }, []);

  const layout = drawer === 'left'
    ? 'fixed inset-y-0 left-0 right-auto m-0 h-[100dvh] w-[calc(100%-2rem)] max-w-[20rem] rounded-none border-r'
    : drawer === 'right'
      ? 'fixed inset-y-0 left-auto right-0 m-0 h-[100dvh] w-full max-w-[36rem] rounded-none sm:border-l'
      : 'w-[calc(100%-2rem)] max-w-[32rem]';

  return (
    <dialog
      ref={ref}
      aria-label={title}
      onClose={() => { if (!ref.current?.open) onClose(); }}
      onClick={(event) => { if (event.target === event.currentTarget) ref.current?.close(); }}
      className={`${panel} max-h-[100dvh] text-ink backdrop:bg-black/40 ${layout}`}>
      <div className={drawer === 'left' ? "flex h-full flex-col p-3" : "p-4 sm:p-6"}>
        <header className="mb-4 flex items-center justify-between gap-4">
          <h2 className="text-xl font-semibold tracking-tight">{title}</h2>
          <button type="button" className={iconButton} onClick={() => ref.current?.close()} aria-label="Close dialog"><X size={19} aria-hidden /></button>
        </header>
        {children}
      </div>
    </dialog>
  );
}

export function RecordIcon() {
  return <span className="inline-flex size-9 shrink-0 items-center justify-center rounded-lg bg-accent text-on-accent"><FileHeart size={17} aria-hidden /></span>;
}
