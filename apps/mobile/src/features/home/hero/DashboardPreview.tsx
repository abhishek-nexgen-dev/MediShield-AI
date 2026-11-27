import { wardRooms } from '../content';
import { Icon } from '../Icon';

export function DashboardPreview() {
  const reading = wardRooms[0];

  return (
    <div className="flex items-center gap-3 rounded-xl border border-border bg-surface p-3.5 text-ink shadow-lg sm:w-max">
      <span className="grid size-10 shrink-0 place-items-center rounded-lg bg-accent text-on-accent">
        <Icon name="activity" />
      </span>
      <div className="min-w-0">
        <p className="text-sm font-semibold leading-tight">Ward overview</p>
        <p className="mt-1 text-xs leading-tight text-secondary">Room {reading.room} · Heart rate</p>
      </div>
      <div className="ml-auto border-l border-border pl-3 text-right">
        <p className="whitespace-nowrap text-sm font-semibold tabular-nums">{reading.pulse}</p>
        <p className="whitespace-nowrap text-xs leading-tight text-secondary">Demo data</p>
      </div>
    </div>
  );
}
