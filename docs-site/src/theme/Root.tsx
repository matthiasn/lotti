import React, {useEffect} from 'react';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';

import {
  installLocalePreferenceTracking,
  localeRootUrl,
  manualLocaleStorageKey,
  preferredSupportedLocale,
  shouldRedirectToPreferredLocale,
} from '@site/src/browserLocalePreference.mjs';

type Props = {children: React.ReactNode};

export default function Root({children}: Props): React.JSX.Element {
  const {
    i18n: {currentLocale, defaultLocale, localeConfigs, locales},
    siteConfig,
  } = useDocusaurusContext();

  useEffect(() => {
    const removePreferenceTracking = installLocalePreferenceTracking({
      document,
      localeConfigs,
      storage: window.localStorage,
    });
    const storedLocale = window.localStorage.getItem(manualLocaleStorageKey);
    const preferredLocale = preferredSupportedLocale(
      window.navigator.languages,
      locales,
      defaultLocale,
    );
    if (
      shouldRedirectToPreferredLocale({
        baseUrl: siteConfig.baseUrl,
        currentLocale,
        defaultLocale,
        pathname: window.location.pathname,
        preferredLocale,
        storedLocale,
      })
    ) {
      window.location.replace(
        localeRootUrl(siteConfig.baseUrl, preferredLocale, defaultLocale),
      );
    }
    return removePreferenceTracking;
  }, [currentLocale, defaultLocale, localeConfigs, locales, siteConfig.baseUrl]);

  return <>{children}</>;
}
