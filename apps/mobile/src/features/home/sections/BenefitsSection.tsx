import { benefits } from '../content';
import { ItemCopy, ItemIcon, SectionHeading } from './section-content';
import { container } from '../styles';
import { sectionSpacing, sectionSplit } from './section-layout';

export function BenefitsSection() {
  return (
    <section className={sectionSpacing} aria-labelledby="benefits-title">
      <div className={container}>
        <div className={`${sectionSplit} rounded-2xl border border-border bg-accent p-[clamp(1.5rem,4vw,3rem)]`}>
          <SectionHeading
            id="benefits-title"
            label="Why MediShield AI"
            title="Technology That Supports Better Care Coordination"
          />
          <ul className="m-0 list-none divide-y divide-border p-0">
            {benefits.map((item) => (
              <li className="flex items-start gap-4 py-4 first:pt-0 last:pb-0" key={item.title}>
                <ItemIcon name="check" compact />
                <div>
                  <ItemCopy item={item} />
                </div>
              </li>
            ))}
          </ul>
        </div>
      </div>
    </section>
  );
}
