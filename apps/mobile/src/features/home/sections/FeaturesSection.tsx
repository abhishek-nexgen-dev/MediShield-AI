import { capabilities } from '../content';
import { ItemCopy, ItemIcon, SectionHeading } from './section-content';
import { container } from '../styles';
import { sectionCard, sectionGridSpacing, sectionSpacing } from './section-layout';

export function FeaturesSection() {
  return (
    <section id="features" className={sectionSpacing} aria-labelledby="features-title">
      <div className={container}>
        <SectionHeading
          id="features-title"
          label="Core features"
          title="One Platform. Connected Healthcare Workflows."
          description="Explore the capabilities MediShield AI is designed to bring together."
          align="center"
        />
        <ul className={`${sectionGridSpacing} grid list-none gap-4 p-0 sm:grid-cols-2 lg:grid-cols-4`}>
          {capabilities.map((item) => (
            <li className={`${sectionCard} lg:min-h-[12.5rem] [&>h3]:mt-4`} key={item.title}>
              <ItemIcon name={item.icon} />
              <ItemCopy item={item} />
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}
