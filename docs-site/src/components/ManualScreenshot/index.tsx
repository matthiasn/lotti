import React, {useMemo, useSyncExternalStore} from 'react';
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

  return (
    <figure className={styles.figure} data-case-id={caseId}>
      <div className={styles.toolbar} aria-label="Screenshot layout for all images">
        <span className={styles.label}>All screenshots</span>
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
      </div>
      <div className={styles.imageStage} data-viewport={viewport}>
        <img
          alt={alt}
          className={styles.image}
          decoding="async"
          key={source}
          loading="lazy"
          src={source}
        />
      </div>
      {caption ? <figcaption className={styles.caption}>{caption}</figcaption> : null}
    </figure>
  );
}
