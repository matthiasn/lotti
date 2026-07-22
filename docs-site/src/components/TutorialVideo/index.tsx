import React, {useMemo} from 'react';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';

import styles from './styles.module.css';
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

  const videoBaseUrl = String(siteConfig.customFields?.tutorialVideoBaseUrl ?? '');

  const src = useMemo(
    () => tutorialVideoSource({scenario, locale: currentLocale, videoBaseUrl}),
    [scenario, currentLocale, videoBaseUrl],
  );
  const captionsSrc = useMemo(
    () => tutorialCaptionsSource({scenario, locale: currentLocale, videoBaseUrl}),
    [scenario, currentLocale, videoBaseUrl],
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
