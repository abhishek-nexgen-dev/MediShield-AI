import { challenges } from '../content';
import { ItemCopy, ItemIcon, SectionHeading } from './section-content';
import { container } from '../styles';
import { sectionBand, sectionCard, sectionSplit } from './section-layout';

export function ProblemSection() {
  return (
    <section className={sectionBand} aria-labelledby="problem-title">
      <div className={`${container} ${sectionSplit}`}>
        <SectionHeading
          id="problem-title"
          label="The problem"
          title="Every Gap in Care Matters"
          description="Healthcare teams face challenges that can affect patient safety and continuity of care."
        />
        <ul className="m-0 grid list-none gap-4 p-0 sm:grid-cols-2">
          {challenges.map((item) => (
            <li className={`${sectionCard} [&>h3]:mt-4`} key={item.title}>
              <ItemIcon name={item.icon} />
              <ItemCopy item={item} />
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}
