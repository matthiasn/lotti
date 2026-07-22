import React, {useMemo, useSyncExternalStore} from 'react';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';

import styles from './styles.module.css';
import {screenshotViewportStore} from '../ManualScreenshot/viewportPreference.mjs';
import {tutorialCaptionsSource, tutorialVideoSource} from './videoSource.mjs';

type Props = {
  title: string;
  scenario: string;
  caption?: string;
};

export default function TutorialVideo({
  caption,
  scenario,
  title,
}: Props): React.JSX.Element {
  const {
    i18n: {currentLocale},
    siteConfig,
  } = useDocusaurusContext();
  const viewport = useSyncExternalStore(
    screenshotViewportStore.subscribe,
    screenshotViewportStore.getSnapshot,
    screenshotViewportStore.getServerSnapshot,
  );

  const videoBaseUrl = String(siteConfig.customFields?.tutorialVideoBaseUrl ?? '');

  const src = useMemo(
    () =>
      tutorialVideoSource({scenario, locale: currentLocale, videoBaseUrl, viewport}),
    [scenario, currentLocale, videoBaseUrl, viewport],
  );
  const captionsSrc = useMemo(
    () =>
      tutorialCaptionsSource({scenario, locale: currentLocale, videoBaseUrl, viewport}),
    [scenario, currentLocale, videoBaseUrl, viewport],
  );

  return (
    <figure className={styles.figure} data-scenario={scenario}>
      <video
        aria-label={title}
        className={styles.video}
        controls
        key={src}
        preload="metadata"
        src={src}
      >
        <track
          default
          kind="captions"
          label={title}
          src={captionsSrc}
          srcLang={currentLocale}
        />
        {title}
      </video>
      {caption ? <figcaption className={styles.caption}>{caption}</figcaption> : null}
    </figure>
  );
}
