import { Image } from 'expo-image';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { hero, wardRooms } from '../content';
import { heroPhoto } from '../photos';

type HomeButtonProps = {
  label: string;
  onPress: () => void;
  secondary?: boolean;
};

export function HomeButton({ label, onPress, secondary = false }: HomeButtonProps) {
  const surface = secondary
    ? 'border border-emerald-700 bg-white dark:border-emerald-400 dark:bg-emerald-950'
    : 'bg-emerald-700 dark:bg-emerald-400';
  const color = secondary ? 'text-emerald-800 dark:text-emerald-100' : 'text-white dark:text-emerald-950';

  return (
    <Pressable
      accessibilityRole="button"
      className={`min-h-12 items-center justify-center rounded-lg px-4 py-3 active:opacity-80 ${surface}`}
      onPress={onPress}>
      <Text className={`text-center text-base font-semibold ${color}`}>{label}</Text>
    </Pressable>
  );
}

type HeroProps = {
  onRegister: () => void;
  onExplore: () => void;
};

export function NativeHeroSection({ onRegister, onExplore }: HeroProps) {
  return (
    <View className="gap-5 pt-6">
      <Text className="text-sm font-semibold text-emerald-800 dark:text-emerald-300">{hero.eyebrow}</Text>
      <Text accessibilityRole="header" className="text-[36px] font-semibold leading-[42px] tracking-tight text-[#13231d] dark:text-[#edf5f1]">
        {hero.headline[0]}{'\n'}{hero.headline[1]}{'\n'}
        <Text className="text-emerald-700 dark:text-emerald-300">{hero.headline[2]}</Text>
      </Text>
      <Text className="text-base leading-6 text-[#42554c] dark:text-[#b9cbc2]">{hero.description}</Text>
      <View className="gap-3">
        <HomeButton label="Register Your Hospital" onPress={onRegister} />
        <HomeButton label="Explore Features" onPress={onExplore} secondary />
      </View>
      <View className="relative aspect-[4/3] overflow-hidden rounded-2xl bg-emerald-950">
        <Image
          source={heroPhoto.source}
          accessibilityLabel={heroPhoto.alt}
          contentFit="cover"
          contentPosition={{ left: '54%', top: '48%' }}
          style={StyleSheet.absoluteFill}
        />
      </View>
      <View className="gap-3 rounded-2xl bg-emerald-950 p-4">
        <View className="flex-row flex-wrap items-center justify-between gap-2">
          <View>
            <Text className="text-sm text-emerald-200">Hospital dashboard</Text>
            <Text className="text-xl font-semibold text-white">Ward overview</Text>
          </View>
          <Text className="rounded-md border border-emerald-400 px-2 py-1 text-xs font-semibold text-emerald-100">
            Demo data
          </Text>
        </View>
        <View className="gap-3 rounded-xl bg-emerald-900 p-3">
          {wardRooms.map(({ room, pulse, status }) => (
            <View key={room} className="flex-row flex-wrap items-center justify-between gap-2">
              <Text className="font-semibold text-white">Room {room}</Text>
              <Text className="text-emerald-50">{pulse}</Text>
              <Text className="text-sm text-emerald-100">{status}</Text>
            </View>
          ))}
        </View>
      </View>
    </View>
  );
}
