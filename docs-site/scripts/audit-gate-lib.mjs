// Pure evaluation logic for the production-advisory gate, kept apart from the
// CLI so it can be tested against fixture reports instead of the live registry.

export const SEVERITY_ORDER = ['info', 'low', 'moderate', 'high', 'critical'];

export function atLeastSeverity(severity, threshold) {
  return (
    SEVERITY_ORDER.indexOf(severity) >= SEVERITY_ORDER.indexOf(threshold)
  );
}

/// The root advisories a package is flagged for, as id -> severity, following
/// npm's `via` chain.
///
/// npm reports the package that actually carries an advisory with an advisory
/// object, and every dependent of it with a bare package *name*; it also rolls
/// a dependent's severity up to the worst anywhere beneath it. So a parent
/// shows as `high` even when its only high-severity root is several levels
/// down and its other roots are moderate.
///
/// Resolving to roots keeps two things honest: one root advisory stops looking
/// like eighteen unrelated findings, and the threshold gets applied to each
/// root's real severity rather than to a rolled-up parent.
export function advisoryRoots(report, name, seen = new Set()) {
  if (seen.has(name)) return new Map();
  seen.add(name);

  const roots = new Map();
  for (const via of report.vulnerabilities?.[name]?.via ?? []) {
    if (typeof via === 'string') {
      for (const [id, severity] of advisoryRoots(report, via, seen)) {
        roots.set(id, severity);
      }
    } else if (via?.url) {
      const match = /GHSA-[\w-]+/.exec(via.url);
      if (match) roots.set(match[0], via.severity ?? 'high');
    }
  }
  return roots;
}

/// Entries whose justification has run out. An exception that outlives its
/// expiry fails the build rather than quietly becoming permanent.
export function expiredEntries(allowlist, now = new Date()) {
  return (allowlist.allow ?? []).filter(
    (entry) => new Date(entry.expires) < now,
  );
}

/// Splits packages into waived and blocking, judging each advisory root on its
/// own severity. Returns `{ waived, blocking }` of display strings.
export function evaluate(report, allowlist, threshold = 'high') {
  const allowed = new Set((allowlist.allow ?? []).map((entry) => entry.id));
  const waived = [];
  const blocking = [];

  for (const [name, advisory] of Object.entries(report.vulnerabilities ?? {})) {
    if (!atLeastSeverity(advisory.severity, threshold)) continue;

    const roots = advisoryRoots(report, name);
    const atThreshold = [...roots]
      .filter(([, severity]) => atLeastSeverity(severity, threshold))
      .map(([id]) => id);

    // Rolled up from something below the threshold; not this gate's business.
    if (atThreshold.length === 0) continue;

    const unwaived = atThreshold.filter((id) => !allowed.has(id));
    if (unwaived.length === 0) {
      waived.push(`${name} (${atThreshold.join(', ')})`);
    } else {
      blocking.push(`${name} [${advisory.severity}] ${unwaived.join(', ')}`);
    }
  }

  return { waived, blocking };
}
