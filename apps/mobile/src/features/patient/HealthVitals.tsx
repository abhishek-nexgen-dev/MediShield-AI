import { useState } from 'react';

import { Activity } from './icons';
import { demoVitals, vitalDate } from './demo';
import { displayDate, displayTime } from './model';
import { button, control, Section } from './ui';

const lookback = [86, 79, 72, 65, 58, 51, 44, 37, 30, 24, 18, 12, 8, 6, 4, 2, 1, 0];
const periods = [7, 30, 90] as const;
const day = 86_400_000;

export function HealthVitals() {
  const [metric, setMetric] = useState(0);
  const [period, setPeriod] = useState<typeof periods[number]>(7);
  const [active, setActive] = useState<number>();
  const selected = demoVitals[metric];
  const samples = selected.readings.map((value, index) => ({ value, offset: lookback[index] })).filter(({ offset }) => offset < period);
  const values = samples.map(({ value }) => value);
  const minimum = Math.min(...values);
  const padding = selected.unit === '°C' ? 0.1 : 1;
  const max = Math.max(...values) + padding;
  const min = minimum - padding;
  const points = samples.map(({ value, offset }) => ({
    x: 52 + (1 - offset / (period - 1)) * 446,
    y: 22 + (max - value) / (max - min) * 103,
    value,
    date: displayDate(new Date(new Date(vitalDate).getTime() - offset * day)),
  }));
  const precision = selected.unit === '°C' ? 1 : 0;
  const point = points[active ?? points.length - 1] ?? points[points.length - 1];

  return (
    <Section title="My Health Vitals" description="Recorded measurements from the demo chart." className="min-w-0">
      <div className="grid grid-cols-2 gap-2 xl:grid-cols-4">
        {demoVitals.map((item) => (
          <div key={item.name} className="min-w-0 rounded-xl border border-border bg-canvas p-2.5 sm:p-3">
            <div className="flex items-center gap-1.5 text-xs font-medium text-secondary"><Activity size={14} className="shrink-0 text-primary" aria-hidden />{item.name}</div>
            <p className="my-1.5 text-lg font-semibold tracking-tight sm:text-xl">{item.value} <span className="text-xs font-normal text-secondary">{item.unit}</span></p>
            <p className="text-[.69rem] leading-4 text-muted"><time dateTime={vitalDate}>{displayDate(vitalDate)} · {displayTime(vitalDate)}</time><br />Demo clinic · Historical</p>
          </div>
        ))}
      </div>
      <div className="mt-5 flex flex-wrap items-center justify-between gap-2">
        <label className="text-xs font-medium text-muted">
          <span className="sr-only">Vital trend metric</span>
          <select className={control} value={metric} onChange={(event) => { setMetric(Number(event.target.value)); setActive(undefined); }}>
            {demoVitals.map(({ name }, index) => <option key={name} value={index}>{name === 'Blood pressure' ? 'Systolic blood pressure' : name}</option>)}
          </select>
        </label>
        <div className="flex gap-1" aria-label="Trend period">
          {periods.map((range) => <button key={range} type="button" aria-pressed={period === range} className={`${button} min-h-8 px-2 py-1 text-xs ${period === range ? '!bg-accent !text-on-accent' : ''}`} onClick={() => { setPeriod(range); setActive(undefined); }}>{range} days</button>)}
        </div>
      </div>
      <svg className="mt-2 block w-full overflow-visible text-primary" viewBox="0 0 520 151" aria-label={`${selected.name} historical chart, last ${period} days of demo history`}>
        <title>{selected.name} demo trend in {selected.unit}</title>
        {[max, (max + min) / 2, min].map((value, index) => (
          <g key={index}>
            <line x1="52" x2="498" y1={22 + index * 51.5} y2={22 + index * 51.5} className="stroke-border" />
            <text x="44" y={26 + index * 51.5} textAnchor="end" className="fill-muted text-[12px]">{value.toFixed(precision)}</text>
          </g>
        ))}
        <polyline points={points.map(({ x, y }) => `${x},${y}`).join(' ')} fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinejoin="round" />
        {points.map(({ x, y, date, value }, index) => (
          <circle key={date} cx={x} cy={y} r={point === points[index] ? 5 : 3.5} fill="currentColor" tabIndex={0}
            aria-label={`${date}, ${value} ${selected.unit}`} onFocus={() => setActive(index)} onMouseEnter={() => setActive(index)}>
            <title>{date} · {value} {selected.unit}</title>
          </circle>
        ))}
        <text x="52" y="146" className="fill-muted text-[12px]">{points[0].date}</text>
        <text x="498" y="146" textAnchor="end" className="fill-muted text-[12px]">{points[points.length - 1].date}</text>
      </svg>
      <p className="mt-1 text-xs text-secondary" aria-live="polite">{point.date} · <strong>{point.value} {selected.unit}</strong> · Synthetic reading</p>
    </Section>
  );
}
