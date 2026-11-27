import { Stack } from 'expo-router';

import { NativePublicLayout } from '@/components/layout/NativePublicLayout';

import { AccountContent } from './AccountContent';
import { accountPages, type AccountMode } from './AccountForm';

export function AccountPage({ mode }: { mode: AccountMode }) {
  return (
    <NativePublicLayout>
      <Stack.Screen options={{ title: accountPages[mode].title }} />
      <AccountContent mode={mode} />
    </NativePublicLayout>
  );
}
