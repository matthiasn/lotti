/** Build the tutorial-video URL for one scenario in the current doc locale. */
export function tutorialVideoSource({scenario, locale, videoBaseUrl}) {
  const base = String(videoBaseUrl).replace(/\/$/, '');
  return `${base}/${scenario}_${locale}.mp4`;
}

/** Build the matching WebVTT captions URL for one scenario/locale. */
export function tutorialCaptionsSource({scenario, locale, videoBaseUrl}) {
  const base = String(videoBaseUrl).replace(/\/$/, '');
  return `${base}/${scenario}_${locale}.vtt`;
}
