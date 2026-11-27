import { Link, type Href } from 'expo-router';
import type { ComponentProps } from 'react';

type AnchorProps = ComponentProps<'a'> & { onPress?: unknown };

function Anchor({ onPress: _onPress, ...props }: AnchorProps) {
  // Expo Router supplies a browser onClick alongside its native onPress handler.
  return <a {...props} />;
}

export function PublicLink({ href, ...props }: Omit<AnchorProps, 'href' | 'onPress'> & { href: Href }) {
  return (
    <Link href={href} asChild>
      <Anchor {...props} />
    </Link>
  );
}
