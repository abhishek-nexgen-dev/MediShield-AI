import { PublicLink } from '@/components/layout/PublicLink';

import type { HomeAction } from '../actions';
import { container, primaryButton, secondaryButton } from '../styles';
import { sectionTitle } from './section-layout';

type ActionProps = {
  onAction: (action: HomeAction) => void;
};

export function CTASection({ onAction }: ActionProps) {
  return (
    <section id="contact" className="pb-[clamp(3rem,6vw,5.5rem)] pt-[clamp(2rem,5vw,4rem)]" aria-labelledby="contact-title">
      <div className={container}>
        <div className="grid items-center gap-4 rounded-2xl bg-emerald-950 p-[clamp(1.75rem,5vw,4rem)] text-emerald-50 lg:grid-cols-[minmax(0,1fr)_auto] lg:gap-x-[clamp(1.5rem,5vw,4rem)]">
          <h2 id="contact-title" className={`${sectionTitle} max-w-[34rem]`}>
            Be Part of a More Connected Healthcare Future
          </h2>
          <p className="m-0 max-w-[37rem] text-base leading-[1.65] text-emerald-100">
            Discover how MediShield AI is designed to help healthcare teams work together, prioritize
            patient safety and maintain continuity of care.
          </p>
          <div className="mt-2 flex flex-wrap gap-3 max-[479px]:[&>*]:w-full lg:col-start-2 lg:row-span-2 lg:row-start-1 lg:mt-0">
            <PublicLink href="/register-hospital" className={`${primaryButton} !border-emerald-400 !bg-emerald-400 !text-emerald-950 hover:!border-emerald-300 hover:!bg-emerald-300 focus-visible:!outline-emerald-300`}>
              Register Your Hospital
            </PublicLink>
            <button
              type="button"
              className={`${secondaryButton} !border-emerald-300 !bg-emerald-950 !text-emerald-50 hover:!bg-emerald-900 focus-visible:!outline-emerald-300`}
              onClick={() => onAction('contact')}>
              Contact Us
            </button>
          </div>
        </div>
      </div>
    </section>
  );
}
