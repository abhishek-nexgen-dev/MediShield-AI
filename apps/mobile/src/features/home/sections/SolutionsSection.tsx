import { audiences } from '../content';
import { ItemCopy, ItemIcon, SectionHeading } from './section-content';
import { container } from '../styles';
import { sectionCard, sectionGridSpacing, sectionSpacing } from './section-layout';

export function SolutionsSection() {
  return (
    <section id="hospitals" className={sectionSpacing} aria-labelledby="solutions-title">
      <div className={container}>
        <SectionHeading
          id="solutions-title"
          label="Who it is for"
          title="Designed for Everyone Involved in Patient Care"
          align="center"
        />
        <ul className={`${sectionGridSpacing} grid list-none gap-4 p-0 sm:grid-cols-2`}>
          {audiences.map((item) => (
            <li className={`${sectionCard} flex items-start gap-3 sm:gap-4`} key={item.title}>
              <ItemIcon name={item.icon} />
              <div>
                <ItemCopy item={item} />
              </div>
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}
