import { Icon } from './Icon';

export function Brand({ href = '#home' }: { href?: string }) {
  return (
    <a className="inline-flex shrink-0 items-center gap-2 whitespace-nowrap text-lg font-bold tracking-[-.055em] text-inherit no-underline sm:text-xl" href={href} aria-label="MediShield AI home">
      <span className="inline-flex h-8 w-[1.85rem] items-center justify-center rounded-t-lg rounded-b-xl bg-primary text-on-primary sm:h-[2.15rem] sm:w-8"><Icon name="activity" size={20} /></span>
      <span>MediShield <span className="text-primary">AI</span></span>
    </a>
  );
}
