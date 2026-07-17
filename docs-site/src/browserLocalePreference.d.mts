export const manualLocaleStorageKey: string;

export function preferredSupportedLocale(
  browserLanguages: readonly string[],
  supportedLocales: readonly string[],
  defaultLocale: string,
): string;

export function shouldRedirectToPreferredLocale(options: {
  baseUrl: string;
  currentLocale: string;
  defaultLocale: string;
  pathname: string;
  preferredLocale: string;
  storedLocale: string | null;
}): boolean;

export function localeRootUrl(
  baseUrl: string,
  locale: string,
  defaultLocale: string,
): string;

export function installLocalePreferenceTracking(options: {
  document: Document;
  localeConfigs: Record<string, {htmlLang: string}>;
  storage: Storage;
}): () => void;
