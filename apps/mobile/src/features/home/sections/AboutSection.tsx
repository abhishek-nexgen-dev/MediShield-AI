import { Image } from 'expo-image';
import { StyleSheet } from 'react-native';

import { about } from '../content';
import { aboutPhoto } from '../photos';
import { container } from '../styles';
import { ItemIcon, SectionHeading } from './section-content';
import { itemTitle, sectionSpacing } from './section-layout';

const principles = [
  { label: 'Our mission', description: about.mission, icon: 'heart' },
  { label: 'Our vision', description: about.vision, icon: 'layers' },
] as const;

export function AboutSection() {
  return (
    <section id="about" className={`${sectionSpacing} border-t border-border bg-surface`} aria-labelledby="about-title">
      <div className={`${container} grid min-w-0 items-center gap-8 md:grid-cols-[minmax(0,0.9fr)_minmax(0,1.1fr)] lg:gap-16`}>
        <div className="relative order-2 aspect-[4/3] min-w-0 overflow-hidden rounded-2xl border border-border bg-subtle md:order-1">
          <Image
            source={aboutPhoto.source}
            accessibilityLabel={aboutPhoto.alt}
            contentFit="cover"
            contentPosition={{ left: '66%', top: '40%' }}
            style={StyleSheet.absoluteFill}
          />
        </div>

        <div className="order-1 min-w-0 md:order-2">
          <SectionHeading
            id="about-title"
            label="About MediShield AI"
            title={about.title}
            description={about.description}
          />
          <dl className="mt-7 divide-y divide-border border-y border-border">
            {principles.map(({ label, description, icon }) => (
              <div className="grid grid-cols-[2.5rem_minmax(0,1fr)] items-start gap-x-3 gap-y-1 py-4" key={label}>
                <dt className={`col-span-2 grid grid-cols-subgrid items-center ${itemTitle}`}>
                  <ItemIcon name={icon} />
                  <span>{label}</span>
                </dt>
                <dd className="col-start-2 m-0 text-base leading-relaxed text-secondary">{description}</dd>
              </div>
            ))}
          </dl>
        </div>
      </div>
    </section>
  );
}
