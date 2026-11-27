import type { HomeAction } from '../actions';
import { Brand } from '../Brand';
import { container } from '../styles';

const footerLink =
  'inline-flex min-h-11 items-center bg-transparent py-1 text-left text-[0.9375rem] leading-[1.4] text-secondary hover:text-primary hover:underline hover:underline-offset-[0.2em] sm:min-h-9';

type ActionProps = {
  sectionBase: '' | '/';
  onAction: (action: HomeAction) => void;
};

type FooterLink =
  | { label: string; href: string }
  | { label: string; action: HomeAction };

const footerGroups: { title: string; links: FooterLink[] }[] = [
  {
    title: 'Product',
    links: [
      { label: 'Features', href: '#features' },
      { label: 'How It Works', href: '#how-it-works' },
      { label: 'For Hospitals', href: '#hospitals' },
      { label: 'Patient Portal', href: '/patient/dashboard' },
    ],
  },
  {
    title: 'Company',
    links: [
      { label: 'About Us', href: '#about' },
      { label: 'Our Team', action: 'team' },
      { label: 'Contact Us', action: 'contact' },
    ],
  },
  {
    title: 'Resources',
    links: [
      { label: 'FAQ', href: '#faq' },
      {
        label: 'Documentation',
        href: 'https://github.com/abhishek-nexgen-dev/MediShield-AI#readme',
      },
      { label: 'Support', action: 'support' },
    ],
  },
  {
    title: 'Legal',
    links: [
      { label: 'Privacy Policy', action: 'privacy' },
      { label: 'Terms of Use', action: 'terms' },
      { label: 'Clinical Disclaimer', action: 'disclaimer' },
    ],
  },
];

export function Footer({ sectionBase, onAction }: ActionProps) {
  return (
    <footer className="border-t border-border bg-surface pb-6 pt-[clamp(2.5rem,5vw,4rem)]">
      <div className={container}>
        <div className="grid gap-[clamp(2rem,5vw,4rem)] md:grid-cols-[minmax(10rem,1fr)_minmax(0,2.7fr)]">
          <div>
            <Brand href={sectionBase || '#home'} />
            <p className="mt-4 max-w-64 text-base leading-[1.6] text-secondary">
              Clinical safety, intelligent monitoring and connected patient care.
            </p>
          </div>
          <nav aria-label="Footer" className="grid grid-cols-2 gap-x-4 gap-y-6 sm:grid-cols-4">
            {footerGroups.map((group) => (
              <div key={group.title}>
                <p className="mb-2 font-[650] text-ink">{group.title}</p>
                <ul className="m-0 list-none p-0">
                  {group.links.map((link) => (
                    <li key={link.label}>
                      {'href' in link ? (
                        <a className={footerLink} href={link.href.startsWith('#') ? sectionBase + link.href : link.href}>{link.label}</a>
                      ) : (
                        <button className={footerLink} type="button" onClick={() => onAction(link.action)}>
                          {link.label}
                        </button>
                      )}
                    </li>
                  ))}
                </ul>
              </div>
            ))}
          </nav>
        </div>
        <div className="mt-10 flex flex-col items-start justify-between gap-x-8 gap-y-4 border-t border-border pt-5 leading-[1.55] text-muted sm:flex-row sm:items-baseline">
          <small className="text-[0.8125rem]">© 2026 MediShield AI.</small>
          <small className="max-w-[41rem] text-[0.8125rem]">
            MediShield AI is a research and prototype platform. Its AI and monitoring features require
            validation and professional oversight. Seek qualified medical advice and use local
            emergency services in an emergency.
          </small>
        </div>
      </div>
    </footer>
  );
}
