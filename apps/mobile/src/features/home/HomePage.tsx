import { PublicLayout } from '@/components/layout/PublicLayout';

import { HeroSection } from './hero/HeroSection';
import {
  AboutSection,
  BenefitsSection,
  CTASection,
  FAQSection,
  FeaturesSection,
  HowItWorksSection,
  ProblemSection,
  SolutionsSection,
} from './sections';

export function HomePage() {
  return (
    <PublicLayout
      home
      title="MediShield AI | Safer Care. Connected Healthcare."
      description="Explore MediShield AI, a research prototype for medication safety, patient monitoring, and connected healthcare workflows.">
      {(openAction) => (
        <>
          <HeroSection />
          <AboutSection />
          <ProblemSection />
          <FeaturesSection />
          <HowItWorksSection />
          <SolutionsSection />
          <BenefitsSection />
          <FAQSection />
          <CTASection onAction={openAction} />
        </>
      )}
    </PublicLayout>
  );
}
