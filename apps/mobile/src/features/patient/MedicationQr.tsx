import { Link, type Href } from 'expo-router';
import { toDataURL } from 'qrcode';
import { useEffect, useState } from 'react';

import { QrCode } from './icons';
import { Section } from './ui';

type QrState = { url: string; image?: string };

export function MedicationQr({ href }: { href: Href }) {
  const path = Link.resolveHref(href);
  const [qr, setQr] = useState<QrState>();

  useEffect(() => {
    let cancelled = false;
    const url = new URL(path, window.location.origin).href;

    toDataURL(url, { errorCorrectionLevel: 'M', margin: 4, width: 200 }).then((image) => {
      if (!cancelled) setQr({ url, image });
    }).catch(() => {
      if (!cancelled) setQr({ url });
    });

    return () => { cancelled = true; };
  }, [path]);

  return (
    <Section title="View QR code" action={<QrCode size={18} className="text-primary" aria-hidden />}>
      {qr ? (
        <div className="flex flex-col items-start gap-3">
          {qr.image ? (
            <img src={qr.image} width={200} height={200} alt="QR code for this medication view" className="max-w-full rounded-lg border border-border bg-white" />
          ) : <p role="status" className="text-sm text-secondary">The QR code could not be generated.</p>}
          <p className="text-sm leading-6 text-secondary">Scan to open this demo view on another device. The link requires a demo session.</p>
          <a href={qr.url} className="text-sm font-semibold text-primary">Open demo link</a>
        </div>
      ) : <p role="status" className="text-sm text-secondary">Generating QR code…</p>}
    </Section>
  );
}
