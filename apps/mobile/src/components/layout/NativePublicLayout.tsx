import { Link, usePathname } from 'expo-router';
import { SymbolView } from 'expo-symbols';
import type { ComponentRef, ReactNode, Ref } from 'react';
import { KeyboardAvoidingView, Platform, Pressable, ScrollView, Text, useColorScheme, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { getHomeAction } from '@/features/home/actions';

const navigation = [
  { href: '/', label: 'Home' },
  { href: '/login', label: 'Log In' },
  { href: '/register-hospital', label: 'Register Hospital' },
] as const;

export function NativePublicLayout({ children, scrollRef }: { children: ReactNode; scrollRef?: Ref<ComponentRef<typeof ScrollView>> }) {
  const pathname = usePathname();
  const colorScheme = useColorScheme();

  return (
    <SafeAreaView edges={pathname === '/' ? ['top', 'left', 'right'] : undefined} className="flex-1 bg-[#f6f8f7] dark:bg-[#0b1110]">
      <View className="border-b border-[#dce5df] bg-white px-5 dark:border-[#30443a] dark:bg-[#121c19]">
        <View className="min-h-14 flex-row items-center gap-2.5">
          <View className="size-9 items-center justify-center rounded-lg bg-emerald-700 dark:bg-emerald-400">
            <SymbolView
              name={{ ios: 'waveform.path.ecg', android: 'monitor_heart' }}
              size={22}
              tintColor={colorScheme === 'dark' ? '#022c22' : '#ffffff'}
            />
          </View>
          <Text className="text-xl font-bold tracking-tight text-[#13231d] dark:text-[#edf5f1]">MediShield AI</Text>
        </View>
        <View className="flex-row flex-wrap items-center gap-x-4">
          {navigation.map(({ href, label }) => (
            <Link key={href} href={href} asChild>
              <Pressable accessibilityRole="link" aria-current={pathname === href ? 'page' : undefined} className="min-h-11 justify-center active:opacity-80">
                <Text className="font-semibold text-emerald-800 dark:text-emerald-300">{label}</Text>
              </Pressable>
            </Link>
          ))}
        </View>
      </View>
      <KeyboardAvoidingView className="flex-1" behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
        <ScrollView ref={scrollRef} className="flex-1" keyboardShouldPersistTaps="handled" contentInsetAdjustmentBehavior="never" contentContainerStyle={{ flexGrow: 1 }}>
          <View className="flex-1">{children}</View>
          <View className="border-t border-[#dce5df] bg-white px-5 py-6 dark:border-[#30443a] dark:bg-[#121c19]">
            <View className="mx-auto w-full max-w-[720px] gap-2">
              <Text className="text-base font-semibold text-[#13231d] dark:text-[#edf5f1]">MediShield AI</Text>
              <Text className="text-sm leading-5 text-[#42554c] dark:text-[#b9cbc2]">{getHomeAction('disclaimer').description}</Text>
            </View>
          </View>
        </ScrollView>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}
