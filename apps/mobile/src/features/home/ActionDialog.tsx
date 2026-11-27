import { useEffect, useRef } from 'react';

import { getHomeAction, type HomeAction } from './actions';
import { Icon } from './Icon';
import { primaryButton } from './styles';

export function ActionDialog({ action, onClose }: { action: HomeAction; onClose: () => void }) {
  const dialogRef = useRef<HTMLDialogElement>(null);
  const { title, description, link } = getHomeAction(action);

  useEffect(() => {
    const dialog = dialogRef.current;
    if (dialog && !dialog.open) dialog.showModal();
    return () => {
      if (dialog?.open) dialog.close();
    };
  }, []);

  return (
    <dialog className="w-[calc(100%-2rem)] max-w-[29rem] rounded-2xl border border-border bg-surface p-6 text-ink shadow-xl backdrop:bg-emerald-950/60" ref={dialogRef} aria-labelledby="home-dialog-title" onClose={(event) => { if (!event.currentTarget.open) onClose(); }}>
      <div className="flex items-start justify-between gap-4">
        <h2 id="home-dialog-title" className="text-[1.4rem] font-semibold leading-tight">{title}</h2>
        <button className="-mt-1 inline-flex size-11 shrink-0 cursor-pointer items-center justify-center rounded-lg border border-border bg-surface text-ink hover:bg-subtle" type="button" aria-label="Close dialog" onClick={() => dialogRef.current?.close()}>
          <Icon name="close" />
        </button>
      </div>
      <p className="mb-5 mt-3 text-secondary">{description}</p>
      {link && (
        <a className={primaryButton} href={link.href} onClick={() => dialogRef.current?.close()}>
          {link.label}
        </a>
      )}
    </dialog>
  );
}
