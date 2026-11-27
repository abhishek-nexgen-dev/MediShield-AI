import { Text, View } from 'react-native';

import { AccountForm, accountPages, type AccountMode } from './AccountForm';

export function AccountContent({ mode }: { mode: AccountMode }) {
  const page = accountPages[mode];
  return (
    <View className="mx-auto w-full max-w-[1120px] flex-1 justify-center px-5 py-8 web:lg:px-10">
      <View className="overflow-hidden rounded-3xl border border-[#dce5df] bg-white dark:border-[#30443a] dark:bg-[#121c19] web:!border-border web:!bg-surface web:lg:flex-row">
        <View className="hidden w-[40%] justify-center gap-8 bg-[#062e24] p-10 web:lg:flex">
          <Text className="text-xl font-bold text-white">MediShield AI</Text>
          <View className="gap-4">
            <View className="h-1 w-12 rounded-full bg-emerald-400" />
            <Text className="text-4xl font-bold tracking-tight text-white">{page.sidebarTitle}</Text>
            <Text className="text-base leading-6 text-emerald-100">{page.sidebarText}</Text>
          </View>
        </View>
        <View className="flex-1 items-center justify-center px-5 py-8 web:sm:px-10 web:lg:py-12">
          <View className="w-full max-w-[420px] gap-5">
            <View className="gap-2">
              <Text accessibilityRole="header" className="text-3xl font-bold tracking-tight text-[#13231d] dark:text-[#edf5f1] web:!text-ink">{page.title}</Text>
              <Text className="text-base leading-6 text-[#42554c] dark:text-[#b9cbc2] web:!text-secondary">{page.description}</Text>
            </View>
            <AccountForm key={mode} mode={mode} />
          </View>
        </View>
      </View>
    </View>
  );
}
