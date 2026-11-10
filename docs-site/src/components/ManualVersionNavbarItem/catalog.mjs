/**
 * Live release-catalog loading for the manual version dropdown.
 *
 * Every Pages deploy writes `manual/releases.json` next to the version
 * directories. The dropdown prefers that live catalog — an immutable release
 * snapshot's baked list would otherwise never mention versions published
 * after it — and keeps the baked catalog when the live one is unreachable
 * or malformed (local dev server, offline, truncated upload).
 */

/** A structurally valid release catalog: an object with a versions array
 * whose entries each carry a version string. */
export function isReleaseCatalog(value) {
  return (
    typeof value === 'object' &&
    value !== null &&
    Array.isArray(value.versions) &&
    value.versions.every(
      (release) =>
        typeof release === 'object' &&
        release !== null &&
        typeof release.version === 'string',
    )
  );
}

/**
 * Fetch the live catalog from `url`. Resolves to the parsed catalog, or to
 * `null` on a non-OK response, malformed payload, or network failure —
 * callers keep their baked fallback in every failure mode.
 */
export async function fetchLiveCatalog(url, fetchImpl = globalThis.fetch) {
  try {
    const response = await fetchImpl(url);
    if (!response.ok) return null;
    const parsed = await response.json();
    return isReleaseCatalog(parsed) ? parsed : null;
  } catch {
    return null;
  }
}

const escapeHtml = (text) =>
  String(text)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/**
 * One entry of the version dropdown. Another version is another site, so the
 * link must be a plain page load in the same tab, with no baseUrl of its own:
 *
 * - `pathname://` keeps it out of the client router (which knows only this
 *   build's pages) and out of the build's broken-link check;
 * - `autoAddBaseUrl: false` stops `Link` prefixing this build's baseUrl — a
 *   release build would otherwise link `/manual/<release>/manual/development/`;
 * - `target: '_self'` undoes the new tab `Link` gives non-routed links, and
 *   `html` (not `label`) leaves out the external-link icon a `label` gets.
 */
export function versionMenuItem({label, version, manualRootPath, localeSuffix}) {
  return {
    html: escapeHtml(label),
    href: `pathname://${manualRootPath}/${version}${localeSuffix}/`,
    autoAddBaseUrl: false,
    target: '_self',
  };
}
