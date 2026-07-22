function scenarioLocale({scenario, locale, viewport}) {
  const suffix = viewport === 'mobile' ? '_mobile' : '';
  return `${scenario}_${locale}${suffix}`;
}

/** Build the tutorial-video URL for one scenario in the current doc locale. */
export function tutorialVideoSource({scenario, locale, videoBaseUrl, viewport}) {
  const base = String(videoBaseUrl).replace(/\/$/, '');
  return `${base}/${scenarioLocale({scenario, locale, viewport})}.mp4`;
}

/** Build the matching WebVTT captions URL for one scenario/locale. */
export function tutorialCaptionsSource({scenario, locale, videoBaseUrl, viewport}) {
  const base = String(videoBaseUrl).replace(/\/$/, '');
  return `${base}/${scenarioLocale({scenario, locale, viewport})}.vtt`;
}
