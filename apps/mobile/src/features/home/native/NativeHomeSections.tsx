import { Image } from 'expo-image';
import type { ReactNode } from 'react';
import { useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { about, questions, type SectionItem } from '../content';
import { aboutPhoto } from '../photos';

const title = 'text-lg font-semibold text-[#13231d] dark:text-[#edf5f1]';
const description = 'text-base leading-6 text-[#42554c] dark:text-[#b9cbc2]';
const card = 'rounded-xl border border-[#dce5df] bg-white p-4 dark:border-[#30443a] dark:bg-[#121c19]';

type SectionProps = {
  label: string;
  title: string;
  children: ReactNode;
};

export function NativeSection({ label, title, children }: SectionProps) {
  return (
    <View className="gap-4">
      <Text className="text-xs font-semibold uppercase tracking-wider text-emerald-800 dark:text-emerald-300">
        {label}
      </Text>
      <Text accessibilityRole="header" className="text-2xl font-semibold tracking-tight text-[#13231d] dark:text-[#edf5f1]">
        {title}
      </Text>
      {children}
    </View>
  );
}

export function SectionCards({ items, numbered = false }: { items: readonly SectionItem[]; numbered?: boolean }) {
  return (
    <View className="gap-3">
      {items.map((item, index) => (
        <View key={item.title} className={card}>
          <Text className={title}>{numbered ? `${index + 1}. ` : ''}{item.title}</Text>
          <Text className={`mt-1 ${description}`}>{item.description}</Text>
        </View>
      ))}
    </View>
  );
}

export function NativeAboutSection() {
  return (
    <NativeSection label="About MediShield AI" title={about.title}>
      <Text className={description}>{about.description}</Text>
      <View className="relative aspect-[4/3] overflow-hidden rounded-2xl bg-emerald-950">
        <Image
          source={aboutPhoto.source}
          accessibilityLabel={aboutPhoto.alt}
          contentFit="cover"
          contentPosition={{ left: '66%', top: '40%' }}
          style={StyleSheet.absoluteFill}
        />
      </View>
      <View className="gap-4 border-y border-[#dce5df] py-4 dark:border-[#30443a]">
        <View>
          <Text className={title}>Our mission</Text>
          <Text className={`mt-1 ${description}`}>{about.mission}</Text>
        </View>
        <View className="border-t border-[#dce5df] pt-4 dark:border-[#30443a]">
          <Text className={title}>Our vision</Text>
          <Text className={`mt-1 ${description}`}>{about.vision}</Text>
        </View>
      </View>
    </NativeSection>
  );
}

export function NativeFAQSection() {
  const [openQuestion, setOpenQuestion] = useState<string | null>(null);

  return (
    <NativeSection label="FAQ" title="Frequently Asked Questions">
      <View className="gap-2">
        {questions.map((question) => {
          const expanded = openQuestion === question.title;
          return (
            <View key={question.title} className={card}>
              <Pressable
                accessibilityRole="button"
                accessibilityState={{ expanded }}
                className="min-h-11 flex-row items-center gap-3"
                onPress={() => setOpenQuestion(expanded ? null : question.title)}>
                <Text className={`flex-1 ${title}`}>{question.title}</Text>
                <Text accessible={false} className="text-xl font-semibold text-emerald-800 dark:text-emerald-300">
                  {expanded ? '−' : '+'}
                </Text>
              </Pressable>
              {expanded && <Text className={`mt-2 ${description}`}>{question.description}</Text>}
            </View>
          );
        })}
      </View>
    </NativeSection>
  );
}
