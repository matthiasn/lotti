import React, {useMemo, useRef, useSyncExternalStore} from 'react';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import {translate} from '@docusaurus/Translate';
import {useColorMode} from '@docusaurus/theme-common';

import styles from './styles.module.css';
import {
  screenshotViewportStore,
  type ScreenshotViewport,
} from './viewportPreference.mjs';
import {manualScreenshotSource} from './screenshotSource.mjs';

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
  const {
    i18n: {currentLocale, defaultLocale},
    siteConfig,
  } = useDocusaurusContext();
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
    () =>
      manualScreenshotSource({
        caseId,
        defaultLocale,
        locale: currentLocale,
        mediaBaseUrl,
        theme,
        version,
        viewport,
      }),
    [
      caseId,
      currentLocale,
      defaultLocale,
      mediaBaseUrl,
      theme,
      version,
      viewport,
    ],
  );

  const labels = {
    allScreenshots: translate({
      id: 'manual.screenshot.allScreenshots',
      message: 'All screenshots',
      description: 'Label for the global screenshot viewport preference',
    }),
    close: translate({id: 'manual.screenshot.close', message: 'Close'}),
    desktop: translate({id: 'manual.screenshot.desktop', message: 'Desktop'}),
    desktopView: translate({
      id: 'manual.screenshot.desktopView',
      message: 'Desktop view',
    }),
    expand: translate({id: 'manual.screenshot.expand', message: 'Expand'}),
    expandedViewer: translate({
      id: 'manual.screenshot.expandedViewer',
      message: 'Expanded screenshot viewer',
    }),
    fullscreen: translate({
      id: 'manual.screenshot.fullscreen',
      message: 'Fullscreen',
    }),
    layoutLabel: translate({
      id: 'manual.screenshot.layoutLabel',
      message: 'Screenshot layout for all images',
    }),
    mobile: translate({id: 'manual.screenshot.mobile', message: 'Mobile'}),
    mobileView: translate({
      id: 'manual.screenshot.mobileView',
      message: 'Mobile view',
    }),
    openViewer: translate({
      id: 'manual.screenshot.openViewer',
      message: 'Open screenshot viewer',
    }),
    screenshot: translate({
      id: 'manual.screenshot.screenshot',
      message: 'Screenshot',
    }),
  };

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
      <div className={styles.toolbar} aria-label={labels.layoutLabel}>
        <span className={styles.label}>{labels.allScreenshots}</span>
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
                {option === 'mobile' ? labels.mobile : labels.desktop}
              </button>
            ))}
          </div>
          <button className={styles.expandButton} onClick={openViewer} type="button">
            {labels.expand}
          </button>
        </div>
      </div>
      <div className={styles.imageStage} data-viewport={viewport}>
        <button
          aria-label={labels.openViewer}
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
        aria-label={labels.expandedViewer}
        className={styles.dialog}
        onClick={(event) => {
          if (event.target === event.currentTarget) closeViewer();
        }}
        ref={dialogRef}
      >
        <div className={styles.viewer} data-viewport={viewport}>
          <div className={styles.viewerToolbar}>
            <div>
              <strong>{labels.screenshot}</strong>
              <span>
                {viewport === 'mobile' ? labels.mobileView : labels.desktopView}
              </span>
            </div>
            <div className={styles.viewerActions}>
              <button onClick={enterFullscreen} type="button">
                {labels.fullscreen}
              </button>
              <button onClick={closeViewer} type="button">
                {labels.close}
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
