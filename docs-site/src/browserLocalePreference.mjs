export const manualLocaleStorageKey = 'lotti-manual-locale';

function normalizeBaseUrl(value) {
  return `/${String(value).split('/').filter(Boolean).join('/')}/`;
}

function normalizeLanguage(value) {
  return String(value).trim().toLowerCase().split('-')[0];
}

/** Select the first browser language supported by the manual. */
export function preferredSupportedLocale(
  browserLanguages,
  supportedLocales,
  defaultLocale,
) {
  const supported = new Set(supportedLocales.map(normalizeLanguage));
  for (const language of browserLanguages ?? []) {
    const normalized = normalizeLanguage(language);
    if (supported.has(normalized)) return normalized;
  }
  return defaultLocale;
}

/** Keep automatic detection conservative: only the unqualified manual root. */
export function shouldRedirectToPreferredLocale({
  baseUrl,
  currentLocale,
  defaultLocale,
  pathname,
  preferredLocale,
  storedLocale,
}) {
  return (
    storedLocale === null &&
    currentLocale === defaultLocale &&
    preferredLocale !== defaultLocale &&
    normalizeBaseUrl(pathname) === normalizeBaseUrl(baseUrl)
  );
}

/** Build the root route for a locale while preserving default-locale URLs. */
export function localeRootUrl(baseUrl, locale, defaultLocale) {
  const base = normalizeBaseUrl(baseUrl);
  return locale === defaultLocale ? base : `${base}${locale}/`;
}

/** Persist explicit choices made through Docusaurus' locale dropdown. */
export function installLocalePreferenceTracking({
  document,
  localeConfigs,
  storage,
}) {
  const localeByHtmlLanguage = new Map(
    Object.entries(localeConfigs).map(([locale, config]) => [
      normalizeLanguage(config.htmlLang),
      locale,
    ]),
  );
  const listener = (event) => {
    const link = event.target?.closest?.('a[lang]');
    if (!link) return;
    const locale = localeByHtmlLanguage.get(normalizeLanguage(link.lang));
    if (locale) storage.setItem(manualLocaleStorageKey, locale);
  };
  document.addEventListener('click', listener, {capture: true});
  return () => document.removeEventListener('click', listener, {capture: true});
}
