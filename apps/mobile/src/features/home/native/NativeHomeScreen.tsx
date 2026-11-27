import { useRouter } from 'expo-router';
import { type ComponentRef, useRef } from 'react';
import { Alert, Linking, ScrollView, Text, View } from 'react-native';

import { NativePublicLayout } from '@/components/layout/NativePublicLayout';

import { getHomeAction, type HomeAction } from '../actions';
import { audiences, benefits, capabilities, challenges, workflow } from '../content';
import { HomeButton, NativeHeroSection } from './NativeHeroSection';
import { NativeAboutSection, NativeFAQSection, NativeSection, SectionCards } from './NativeHomeSections';

function showHomeAction(action: HomeAction) {
  const { title, description, link } = getHomeAction(action);
  const buttons = [{ text: 'Close', style: 'cancel' as const }];

  if (link?.href.startsWith('https://')) {
    Alert.alert(title, description, [
      ...buttons,
      {
        text: link.label,
        onPress: async () => {
          try {
            await Linking.openURL(link.href);
          } catch {
            Alert.alert('Unable to open the project link', 'Please try again when your browser is available.');
          }
        },
      },
    ]);
  } else {
    Alert.alert(title, description, buttons);
  }
}

export function NativeHomeScreen() {
  const router = useRouter();
  const scroll = useRef<ComponentRef<typeof ScrollView>>(null);
  const featuresOffset = useRef(0);

  return (
    <NativePublicLayout scrollRef={scroll}>
      <View className="mx-auto w-full max-w-[720px] gap-10 px-5 pb-10">
        <NativeHeroSection
          onRegister={() => router.push('/register-hospital')}
          onExplore={() => scroll.current?.scrollTo({ y: Math.max(0, featuresOffset.current - 16), animated: true })}
        />

        <NativeAboutSection />

        <NativeSection label="The problem" title="Every Gap in Care Matters">
          <SectionCards items={challenges} />
        </NativeSection>

        <View onLayout={(event) => { featuresOffset.current = event.nativeEvent.layout.y; }}>
          <NativeSection label="Core features" title="One Platform. Connected Healthcare Workflows.">
            <SectionCards items={capabilities} />
          </NativeSection>
        </View>

        <NativeSection label="How it works" title="From Admission to Follow-Up, Keep Care Connected">
          <SectionCards items={workflow} numbered />
        </NativeSection>

        <NativeSection label="Who it is for" title="Designed for Everyone Involved in Patient Care">
          <SectionCards items={audiences} />
        </NativeSection>

        <NativeSection label="Why MediShield AI" title="Technology That Supports Better Care Coordination">
          <SectionCards items={benefits} />
        </NativeSection>

        <NativeFAQSection />

        <View className="gap-4 rounded-2xl bg-emerald-950 p-5">
          <Text accessibilityRole="header" className="text-2xl font-semibold tracking-tight text-white">
            Be Part of a More Connected Healthcare Future
          </Text>
          <Text className="text-base leading-6 text-emerald-100">
            Discover how MediShield AI is designed to help healthcare teams work together, prioritize patient safety and maintain continuity of care.
          </Text>
          <HomeButton label="Register Your Hospital" onPress={() => router.push('/register-hospital')} />
          <HomeButton label="Contact Us" onPress={() => showHomeAction('contact')} secondary />
        </View>
      </View>
    </NativePublicLayout>
  );
}
