import type { IconItem, SectionItem } from '../content';
import { Icon } from '../Icon';
import { itemDescription, itemTitle, sectionTitle } from './section-layout';

type SectionHeadingProps = {
  id: string;
  label: string;
  title: string;
  description?: string;
  align?: 'left' | 'center';
};

export function SectionHeading({ id, label, title, description, align = 'left' }: SectionHeadingProps) {
  return (
    <div className={`max-w-[40rem] ${align === 'center' ? 'mx-auto text-center' : ''}`}>
      <p className="mb-3 text-[0.8125rem] font-[650] uppercase leading-[1.4] tracking-[0.06em] text-primary">
        {label}
      </p>
      <h2 id={id} className={`${sectionTitle} [text-wrap:balance]`}>
        {title}
      </h2>
      {description && <p className="mt-4 text-base leading-[1.65] text-secondary">{description}</p>}
    </div>
  );
}

export function ItemCopy({ item }: { item: SectionItem }) {
  return (
    <>
      <h3 className={itemTitle}>{item.title}</h3>
      <p className={itemDescription}>{item.description}</p>
    </>
  );
}

export function ItemIcon({ name, compact = false }: { name: IconItem['icon']; compact?: boolean }) {
  const shape = compact ? 'size-8 rounded-full bg-surface' : 'size-10 rounded-lg bg-accent';
  return (
    <span className={`inline-flex shrink-0 items-center justify-center text-on-accent ${shape}`} aria-hidden="true">
      <Icon name={name} size={20} />
    </span>
  );
}
