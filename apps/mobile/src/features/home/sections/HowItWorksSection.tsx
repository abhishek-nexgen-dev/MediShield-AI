import { workflow } from '../content';
import { ItemCopy, SectionHeading } from './section-content';
import { container } from '../styles';
import { sectionBand, sectionGridSpacing } from './section-layout';

export function HowItWorksSection() {
  return (
    <section
      id="how-it-works"
      className={sectionBand}
      aria-labelledby="workflow-title">
      <div className={container}>
        <SectionHeading
          id="workflow-title"
          label="How it works"
          title="From Admission to Follow-Up, Keep Care Connected"
        />
        <ol className={`${sectionGridSpacing} grid list-none gap-6 p-0 min-[480px]:grid-cols-2 lg:grid-cols-4`}>
          {workflow.map((item, index) => (
            <li
              className="relative min-w-0 pt-0.5 before:absolute before:-right-4 before:left-12 before:top-[1.375rem] before:hidden before:border-t before:border-dashed before:border-control before:content-[''] md:[&:not(:last-child):nth-child(odd)]:before:block lg:[&:not(:last-child)]:before:block"
              key={item.title}>
              <span className="mb-4 flex size-10 items-center justify-center rounded-full border border-border bg-accent font-[650] leading-none text-on-accent" aria-hidden="true">
                {index + 1}
              </span>
              <ItemCopy item={item} />
            </li>
          ))}
        </ol>
      </div>
    </section>
  );
}
