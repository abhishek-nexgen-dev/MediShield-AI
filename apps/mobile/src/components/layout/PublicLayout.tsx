import Head from 'expo-router/head';
import { type ReactNode, useState } from 'react';

import { ActionDialog } from '@/features/home/ActionDialog';
import type { HomeAction } from '@/features/home/actions';
import { Navbar } from '@/features/home/Navbar';
import { Footer } from '@/features/home/sections/Footer';
import { homepageClasses, primaryButton } from '@/features/home/styles';
import { useHomeTheme } from '@/features/home/theme';

type PublicLayoutProps = {
  title: string;
  description: string;
  home?: boolean;
  children: ReactNode | ((openAction: (action: HomeAction) => void) => ReactNode);
};

export function PublicLayout({ title, description, home = false, children }: PublicLayoutProps) {
  const [theme, setTheme] = useHomeTheme();
  const [action, setAction] = useState<HomeAction | null>(null);
  const sectionBase = home ? '' : '/';

  return (
    <div className={homepageClasses(theme)} data-theme={theme}>
      <Head>
        <title>{title}</title>
        <meta name="description" content={description} />
      </Head>
      <a className={`${primaryButton} fixed left-4 top-2 z-[5] -translate-y-[150%] focus:translate-y-0`} href="#main-content">
        Skip to content
      </a>
      <div className="flex min-h-full flex-col">
        <Navbar theme={theme} onThemeChange={setTheme} sectionBase={sectionBase} />
        <main id="main-content" tabIndex={-1} className="flex flex-1 flex-col">
          {typeof children === 'function' ? children(setAction) : children}
        </main>
        <Footer onAction={setAction} sectionBase={sectionBase} />
      </div>
      {action && <ActionDialog action={action} onClose={() => setAction(null)} />}
    </div>
  );
}
