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
