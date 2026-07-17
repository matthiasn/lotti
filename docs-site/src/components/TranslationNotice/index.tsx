import React from 'react';
import Link from '@docusaurus/Link';
import Translate from '@docusaurus/Translate';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';

import styles from './styles.module.css';

const pullRequestsUrl = 'https://github.com/matthiasn/lotti/pulls';
const newIssueUrl =
  'https://github.com/matthiasn/lotti/issues/new?labels=documentation&title=Manual%20translation%3A%20';

export default function TranslationNotice(): React.JSX.Element | null {
  const {
    i18n: {currentLocale, defaultLocale},
  } = useDocusaurusContext();

  if (currentLocale === defaultLocale) return null;

  return (
    <aside
      className={styles.notice}
      data-translation-notice={currentLocale}
      role="note">
      <span className={styles.icon} aria-hidden="true">
        ✦
      </span>
      <div>
        <strong className={styles.title}>
          <Translate id="manual.translationNotice.title">
            Machine translation — review welcome
          </Translate>
        </strong>
        <p className={styles.copy}>
          <Translate id="manual.translationNotice.disclosure">
            This translation was created with GPT 5.6 Sol xHigh and has not
            been proofread yet.
          </Translate>{' '}
          <Translate id="manual.translationNotice.invitation">
            Corrections and improvements are very welcome as a
          </Translate>{' '}
          <Link to={pullRequestsUrl}>
            <Translate id="manual.translationNotice.pullRequest">
              pull request
            </Translate>
          </Link>{' '}
          <Translate id="manual.translationNotice.or">or</Translate>{' '}
          <Link to={newIssueUrl}>
            <Translate id="manual.translationNotice.issue">
              GitHub issue
            </Translate>
          </Link>
          .
        </p>
      </div>
    </aside>
  );
}
