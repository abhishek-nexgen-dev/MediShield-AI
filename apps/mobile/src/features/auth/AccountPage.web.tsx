import { PublicLayout } from '@/components/layout/PublicLayout';

import { accountPages, type AccountMode } from './AccountForm';
import { AccountContent } from './AccountContent';

export function AccountPage({ mode }: { mode: AccountMode }) {
  const page = accountPages[mode];

  return (
    <PublicLayout title={`${page.title} | MediShield AI`} description={page.description}>
      <AccountContent mode={mode} />
    </PublicLayout>
  );
}
