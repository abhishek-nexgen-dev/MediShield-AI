import { Image } from 'expo-image';
import { StyleSheet } from 'react-native';

import { heroPhoto } from '../photos';
import { DashboardPreview } from './DashboardPreview';

export function HeroVisual() {
  return (
    <div className="relative min-w-0">
      <div className="relative aspect-[4/3] overflow-hidden rounded-2xl border border-border bg-subtle">
        <Image
          source={heroPhoto.source}
          accessibilityLabel={heroPhoto.alt}
          contentFit="cover"
          contentPosition={{ left: '54%', top: '48%' }}
          priority="high"
          style={StyleSheet.absoluteFill}
        />
      </div>
      <div className="mt-3 sm:absolute sm:bottom-5 sm:left-5 sm:mt-0">
        <DashboardPreview />
      </div>
    </div>
  );
}
