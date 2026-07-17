/** Build the immutable media URL for one manual screenshot variant. */
export function manualScreenshotSource({
  caseId,
  defaultLocale,
  locale,
  mediaBaseUrl,
  theme,
  version,
  viewport,
}) {
  const base = String(mediaBaseUrl).replace(/\/$/, '');
  const localeSegment = locale === defaultLocale ? '' : `/${locale}`;
  return (
    `${base}/${version}${localeSegment}/${caseId}/` +
    `${viewport}-${theme}.webp`
  );
}
