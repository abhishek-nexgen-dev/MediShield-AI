import { PublicLink } from '@/components/layout/PublicLink';

import { hero } from '../content';
import { Icon } from '../Icon';
import { container, primaryButton, secondaryButton } from '../styles';
import { HeroVisual } from './HeroVisual';

export function HeroSection() {
  return (
    <section id="home" className="bg-canvas" aria-labelledby="home-title">
      <div
        className={`${container} grid items-center gap-10 py-[clamp(2.75rem,5.5vw,5.5rem)] min-[1061px]:grid-cols-[minmax(0,1fr)_minmax(0,1.05fr)] min-[1061px]:gap-[clamp(2rem,4vw,4.5rem)]`}>
        <div className="min-w-0">
          <p className="mb-5 inline-flex items-center gap-2 text-[0.8125rem] font-semibold leading-[1.4] text-on-accent [&>:first-child]:shrink-0">
            <Icon name="shield" size={15} />
            {hero.eyebrow}
          </p>
          <h1
            id="home-title"
            className="max-w-[40rem] text-[clamp(2.5rem,5.8vw,3.5rem)] font-semibold leading-[1.04] tracking-[-0.052em] text-ink [text-wrap:balance] max-[450px]:text-[clamp(2rem,9.2vw,2.5rem)] min-[1061px]:text-[clamp(2.5rem,3.8vw,3.65rem)]">
            <span className="block">{hero.headline[0]}</span>{' '}
            <span className="block">{hero.headline[1]}</span>{' '}
            <span className="block text-primary">{hero.headline[2]}</span>
          </h1>
          <p className="mt-6 max-w-lg text-[1.0625rem] leading-[1.65] text-secondary">
            {hero.description}
          </p>
          <div className="mt-7 flex flex-wrap gap-3 max-[450px]:[&>*]:flex-[1_1_11rem]">
            <PublicLink href="/register-hospital" className={primaryButton}>Register Your Hospital</PublicLink>
            <a className={secondaryButton} href="#features">
              Explore Features
            </a>
          </div>
        </div>
        <HeroVisual />
      </div>
    </section>
  );
}
