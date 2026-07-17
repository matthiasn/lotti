import React, {useMemo, useRef, useSyncExternalStore} from 'react';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import {useColorMode} from '@docusaurus/theme-common';

import styles from './styles.module.css';
import {
  screenshotViewportStore,
  type ScreenshotViewport,
} from './viewportPreference.mjs';

type Theme = 'light' | 'dark';

type Props = {
  alt: string;
  caseId: string;
  caption?: string;
  mediaVersion?: string;
};

export default function ManualScreenshot({
  alt,
  caseId,
  caption,
  mediaVersion,
}: Props): React.JSX.Element {
  const {siteConfig} = useDocusaurusContext();
  const {colorMode} = useColorMode();
  const dialogRef = useRef<HTMLDialogElement>(null);
  const viewport = useSyncExternalStore(
    screenshotViewportStore.subscribe,
    screenshotViewportStore.getSnapshot,
    screenshotViewportStore.getServerSnapshot,
  );

  const theme: Theme = colorMode === 'dark' ? 'dark' : 'light';
  const version =
    mediaVersion ?? String(siteConfig.customFields?.manualVersion ?? 'development');
  const mediaBaseUrl = String(
    siteConfig.customFields?.manualMediaBaseUrl ?? '',
  ).replace(/\/$/, '');

  const source = useMemo(
    () => `${mediaBaseUrl}/${version}/${caseId}/${viewport}-${theme}.webp`,
    [caseId, mediaBaseUrl, theme, version, viewport],
  );

  function selectViewport(nextViewport: ScreenshotViewport): void {
    screenshotViewportStore.setViewport(nextViewport);
  }

  function openViewer(): void {
    const dialog = dialogRef.current;
    if (dialog && !dialog.open) dialog.showModal();
  }

  function closeViewer(): void {
    const dialog = dialogRef.current;
    if (!dialog) return;
    if (document.fullscreenElement === dialog) {
      void document.exitFullscreen().finally(() => dialog.close());
      return;
    }
    dialog.close();
  }

  function enterFullscreen(): void {
    const dialog = dialogRef.current;
    if (!dialog?.requestFullscreen) return;
    void dialog.requestFullscreen().catch(() => undefined);
  }

  return (
    <figure className={styles.figure} data-case-id={caseId}>
      <div className={styles.toolbar} aria-label="Screenshot layout for all images">
        <span className={styles.label}>All screenshots</span>
        <div className={styles.toolbarActions}>
          <div className={styles.segmentedControl} role="group">
            {(['mobile', 'desktop'] as const).map((option) => (
              <button
                aria-pressed={viewport === option}
                className={styles.segment}
                key={option}
                onClick={() => selectViewport(option)}
                type="button"
              >
                {option === 'mobile' ? 'Mobile' : 'Desktop'}
              </button>
            ))}
          </div>
          <button className={styles.expandButton} onClick={openViewer} type="button">
            Expand
          </button>
        </div>
      </div>
      <div className={styles.imageStage} data-viewport={viewport}>
        <button
          aria-label="Open screenshot viewer"
          className={styles.imageButton}
          onClick={openViewer}
          type="button"
        >
          <img
            alt={alt}
            className={styles.image}
            decoding="async"
            key={source}
            loading="lazy"
            src={source}
          />
        </button>
      </div>
      {caption ? <figcaption className={styles.caption}>{caption}</figcaption> : null}
      <dialog
        aria-label="Expanded screenshot viewer"
        className={styles.dialog}
        onClick={(event) => {
          if (event.target === event.currentTarget) closeViewer();
        }}
        ref={dialogRef}
      >
        <div className={styles.viewer} data-viewport={viewport}>
          <div className={styles.viewerToolbar}>
            <div>
              <strong>Screenshot</strong>
              <span>{viewport === 'mobile' ? 'Mobile view' : 'Desktop view'}</span>
            </div>
            <div className={styles.viewerActions}>
              <button onClick={enterFullscreen} type="button">
                Fullscreen
              </button>
              <button onClick={closeViewer} type="button">
                Close
              </button>
            </div>
          </div>
          <div className={styles.viewerStage}>
            <img alt={alt} className={styles.viewerImage} src={source} />
          </div>
        </div>
      </dialog>
    </figure>
  );
}
