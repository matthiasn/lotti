/// Conformance checker for the Open Knowledge Format (OKF) v0.2 bundle that
/// lives in `knowledge/`.
///
/// The spec is at
/// https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md.
/// This validator enforces the three normative conformance rules of §11 as
/// [Severity.error], and — because this repository treats the metadata that
/// makes drift detectable as mandatory rather than advisory — raises the
/// SHOULD-level guidance of §4, §5 and §7 to an error too. See [_houseRule] for
/// what that covers and [Severity.warning] for the narrow set left advisory.
///
/// The validator is deliberately dependency-light and filesystem-agnostic:
/// [validateBundle] takes an in-memory map of relative path to file contents so
/// it can be exercised from unit tests without touching disk. The CLI wrapper
/// in `tool/okf/validate.dart` reads the tree and hands it over.
library;

import 'dart:convert';

import 'package:yaml/yaml.dart';

/// How badly a [OkfIssue] breaks the spec.
enum Severity {
  /// Violates a normative MUST in §11, or a house rule this repo requires.
  /// The bundle is not conformant and CI fails.
  error,

  /// Advisory, and deliberately narrow: OKF is permissive here. A link to
  /// knowledge that has not been written yet is legitimate (§6.1), an index
  /// without headings is untidy rather than wrong, and `Attested Computation`
  /// fields matter only to a type nothing in this bundle uses.
  warning,
}

/// Severity for metadata this repository requires but OKF only recommends.
///
/// The spec grades a missing `description`, freshness date or source list as a
/// SHOULD. This bundle fails the build on them, because a concept without them
/// is exactly the one whose drift nobody can detect: no description to show in
/// an index, no date to reason about, and nothing for the anti-drift check to
/// resolve. Treating them as warnings meant the rules that keep the map honest
/// were the only ones CI did not enforce.
const Severity _houseRule = Severity.error;

/// A single problem found in a bundle.
class OkfIssue {
  /// Creates an issue at [path], optionally anchored to a 1-based [line].
  const OkfIssue({
    required this.severity,
    required this.path,
    required this.message,
    this.line,
  });

  /// Whether this breaks conformance or only guidance.
  final Severity severity;

  /// Bundle-relative path of the offending file, e.g. `features/sync.md`.
  final String path;

  /// Human-readable description of what is wrong.
  final String message;

  /// 1-based line number within [path], when the issue can be located.
  final int? line;

  /// Whether this issue makes the bundle non-conformant.
  bool get isError => severity == Severity.error;

  @override
  String toString() {
    final where = line == null ? path : '$path:$line';
    final label = severity == Severity.error ? 'error' : 'warning';
    return '$label: $where: $message';
  }
}

/// The outcome of validating a whole bundle.
class OkfValidationResult {
  /// Wraps [issues] found across [conceptCount] concept documents.
  const OkfValidationResult({
    required this.issues,
    required this.conceptCount,
  });

  /// Every problem found, in discovery order.
  final List<OkfIssue> issues;

  /// How many non-reserved `.md` files were checked as concepts.
  final int conceptCount;

  /// Issues that break §11 conformance.
  List<OkfIssue> get errors => issues.where((i) => i.isError).toList();

  /// Issues that only break SHOULD-level guidance.
  List<OkfIssue> get warnings => issues.where((i) => !i.isError).toList();

  /// Whether the bundle satisfies every normative rule.
  bool get isConformant => errors.isEmpty;
}

/// Filenames reserved by §3.1, which are structural rather than concepts.
const reservedFilenames = {'index.md', 'log.md'};

/// The OKF version this validator understands.
const okfVersion = '0.2';

/// Frontmatter keys every concept must carry.
///
/// `type` is the spec's only hard requirement (§4.1); the rest are `SHOULD`s
/// that this repo raises to a [_houseRule] error, so agents always find a
/// description to show, a freshness date to reason about, and the code the
/// concept was derived from. `stale_after` and `sources` are in here rather than
/// only validated when present, because a concept that omits them is exactly the
/// one whose drift nobody can detect.
///
/// `resource` and `tags` joined the set once the convention that documents them
/// as mandatory turned out not to be enforced: two architecture concepts had no
/// `resource` at all and validated clean, which is exactly the gap between
/// documented and checked that this bundle exists to close. A concept whose
/// subject is the repository itself says so — `resource: ../..` — rather than
/// omitting the key.
const _requiredHouseKeys = {
  'title',
  'description',
  'resource',
  'tags',
  'status',
  'generated',
  'stale_after',
  'sources',
};

/// Lifecycle values allowed by §5.4.
const _statusValues = {'draft', 'stable', 'deprecated'};

final _frontmatterPattern = RegExp(
  r'^---\r?\n(.*?)\r?\n---\s*?(\r?\n|$)',
  dotAll: true,
);
final _isoDatePattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
final _isoDateTimePattern = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(\.\d+)?(Z|[+-]\d{2}:\d{2})$',
);

/// Whether [value] is a real `YYYY-MM-DD` calendar day.
///
/// The shape regex alone is not enough: `DateTime.tryParse` **rolls over** out
/// of range components rather than rejecting them (`2026-99-99` parses as
/// 2034-06-07, `2026-02-30` as 2026-03-02), so an impossible date would sail
/// through as valid metadata. Round-tripping the parsed components against what
/// was written is what actually rejects it.
bool _isRealIsoDate(String value) {
  final match = _isoDatePattern.firstMatch(value);
  if (match == null) return false;
  return _isRealCalendarDay(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
}

/// Whether [value] is a real ISO 8601 datetime, rejecting both out-of-range
/// components and impossible calendar days.
bool _isRealIsoDateTime(String value) {
  final match = _isoDateTimePattern.firstMatch(value);
  if (match == null) return false;
  final hour = int.parse(match.group(4)!);
  final minute = int.parse(match.group(5)!);
  final second = int.parse(match.group(6)!);
  // Range-check before any construction. `DateTime` rolls out-of-range
  // components over — 99:99:99 becomes a valid instant four days later — so a
  // round-trip comparison alone would accept it.
  if (hour > 23 || minute > 59 || second > 59) return false;
  final offset = match.group(8)!;
  if (offset != 'Z') {
    if (int.parse(offset.substring(1, 3)) > 23) return false;
    if (int.parse(offset.substring(4, 6)) > 59) return false;
  }
  return _isRealCalendarDay(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
}

/// Whether `year-month-day` names a day that exists.
///
/// Range-checks the components first, then round-trips through `DateTime` to
/// reject a day that is out of range *for its month* — February 30 and April 31
/// pass a naive `day <= 31` check but roll over into the next month.
bool _isRealCalendarDay(int year, int month, int day) {
  if (month < 1 || month > 12) return false;
  if (day < 1 || day > 31) return false;
  final constructed = DateTime.utc(year, month, day);
  return constructed.year == year &&
      constructed.month == month &&
      constructed.day == day;
}

// §7 names `human:`, `process:` and `<producer>/<version>`; §5.1's own example
// additionally uses a `team:` prefix for `sources[].author`, so it is accepted.
final _actorPattern = RegExp(
  r'^(human:[\w.-]+|process:[\w.-]+|team:[\w.-]+|[\w.-]+/[\w.-]+)$',
);
// §9: every `##` heading in a log.md groups entries by date, so the whole
// heading text is the candidate date — matching only a single token would let
// `## May 22, 2026` slip through as "not a date heading at all".
final _logDateHeadingPattern = RegExp(r'^##\s+(.+?)\s*$');
// Two destination forms: bare (`(path)`) and angle-bracketed (`(<path with
// space>)`). The bracketed form exists precisely to carry whitespace, so a
// whitespace-free character class silently misses it — and with it any dangling
// pointer written that way.
// The title is optional and CommonMark allows three quotings — `"t"`, `'t'` and
// `(t)`. Accepting only the double-quoted form left `[impl](../../lib/gone.dart
// 'source')` matching nothing at all, so the dangling pointer inside it was
// never even offered for checking.
final _markdownLinkPattern = RegExp(
  r'\[[^\]]*\]\(\s*(?:<([^>]*)>|([^)\s]+))'
  r'''(?:\s+(?:"[^"]*"|'[^']*'|\([^)]*\)))?\s*\)''',
);
// Reference-style link definitions: `[label]: target "optional title"`. A
// reference link (`[text][label]`) carries no target of its own, so scanning
// only inline links would let `[impl]: ../../lib/gone.dart` pass while the
// rendered document points at a missing file. Footnote definitions
// (`[^label]: prose`) are excluded — §5.1 keys those to `sources[].id` and
// their body is prose, not a path.
final _referenceDefinitionPattern = RegExp(
  '^ {0,3}'
  r'\[([^^\]][^\]]*)\]:[ \t]*(?:<([^>]*)>|([^\s]+))'
  r'''[ \t]*(?:"[^"]*"|'[^']*'|\([^)]*\))?[ \t]*$''',
  multiLine: true,
);

/// A markdown file split into its raw YAML frontmatter and its body.
///
/// [frontmatterYaml] is `null` when the file has no frontmatter block at all,
/// which callers report differently from a block that fails to parse.
class OkfDocument {
  /// Creates a parsed view of a concept file.
  const OkfDocument({required this.frontmatterYaml, required this.body});

  /// The text between the opening and closing `---`, or `null` when absent.
  final String? frontmatterYaml;

  /// Everything after the frontmatter block.
  final String body;
}

final _fencedBlockPattern = RegExp(
  r'^(```|~~~).*?^\1',
  multiLine: true,
  dotAll: true,
);
final _inlineCodePattern = RegExp(r'`[^`\n]*`');

/// Reports a fenced code block that never closes on a line of its own.
///
/// CommonMark accepts a closing fence only when the line carries nothing but the
/// delimiter, so ```` ``` and then prose ```` does **not** close the block: every
/// remaining line of the concept renders as code. That shipped once — a mermaid
/// diagram whose closing fence had a sentence welded to it swallowed the rest of
/// the page — and nothing caught it, because [stripCodeSpans] is deliberately
/// looser about where a block ends and treated the same line as a close.
///
/// Line numbers are relative to the whole file, so callers pass the raw content
/// rather than [OkfDocument.body].
List<OkfIssue> validateFencedBlocks(String path, String content) {
  final lines = content.split('\n');
  String? opener;
  var openedAt = 0;
  for (var i = 0; i < lines.length; i++) {
    final trimmed = lines[i].trimLeft().trimRight();
    if (opener == null) {
      final match = _fenceOpenPattern.firstMatch(trimmed);
      if (match != null) {
        opener = match.group(1);
        openedAt = i + 1;
      }
      continue;
    }
    if (_closesFence(trimmed, opener)) opener = null;
  }
  if (opener == null) return const [];
  return [
    OkfIssue(
      severity: _houseRule,
      path: path,
      line: openedAt,
      message:
          'fenced block opened with `$opener` is never closed by a line '
          'containing only the delimiter, so the rest of the file renders as '
          'code',
    ),
  ];
}

final _fenceOpenPattern = RegExp('^(`{3,}|~{3,})');

/// Whether [trimmed] is a valid closing fence for a block opened by [opener]:
/// the same delimiter character, at least as long, and nothing else on the line.
bool _closesFence(String trimmed, String opener) {
  if (trimmed.length < opener.length) return false;
  final char = opener[0];
  for (var i = 0; i < trimmed.length; i++) {
    if (trimmed[i] != char) return false;
  }
  return true;
}

/// Blanks out fenced blocks and inline code so link scanning never treats a
/// documented link *form* — `` `[Title](/tasks/<taskId>)` `` — as a real link
/// the bundle must resolve. Replacing rather than deleting keeps byte offsets
/// stable for any future line reporting.
String stripCodeSpans(String markdown) {
  final withoutFences = markdown.replaceAllMapped(
    _fencedBlockPattern,
    (m) => ' ' * m.group(0)!.length,
  );
  return _stripIndentedBlocks(withoutFences).replaceAllMapped(
    _inlineCodePattern,
    (m) => ' ' * m.group(0)!.length,
  );
}

/// Blanks four-space (or tab) indented code blocks.
///
/// Markdown renders these as code, so a link form documented inside one is not a
/// live pointer. Missing them produced the one failure mode worse than a missed
/// dangling link: `make okf_check` failing on a link that never rendered, which
/// blocks a correct change.
///
/// An indented block only starts after a blank line — otherwise the indentation
/// is a list-item or paragraph continuation, where links *are* live.
String _stripIndentedBlocks(String markdown) {
  final lines = markdown.split('\n');
  var previousBlank = true;
  var inBlock = false;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final blank = line.trim().isEmpty;
    final indented = line.startsWith('    ') || line.startsWith('\t');
    if (!inBlock && indented && previousBlank) {
      inBlock = true;
    } else if (inBlock && !indented && !blank) {
      inBlock = false;
    }
    if (inBlock && !blank) {
      lines[i] = ' ' * line.length;
    }
    previousBlank = blank;
  }
  return lines.join('\n');
}

/// Every link target in [body]: inline `[a](b)` plus reference definitions.
///
/// Code spans are stripped first so a documented link *form* is not treated as
/// a link the bundle must resolve.
Iterable<String> linkTargets(String body) {
  final stripped = stripCodeSpans(body);
  return [
    for (final m in _markdownLinkPattern.allMatches(stripped))
      (m.group(1) ?? m.group(2))!.trim(),
    for (final m in _referenceDefinitionPattern.allMatches(stripped))
      (m.group(2) ?? m.group(3))!.trim(),
  ];
}

/// Extracts the frontmatter block and body from a markdown [content] string.
OkfDocument splitDocument(String content) {
  final match = _frontmatterPattern.firstMatch(content);
  if (match == null) {
    return OkfDocument(frontmatterYaml: null, body: content);
  }
  return OkfDocument(
    frontmatterYaml: match.group(1),
    body: content.substring(match.end),
  );
}

/// Validates a whole bundle.
///
/// [files] maps bundle-relative POSIX paths (`features/sync.md`) to file
/// contents. Only `.md` files are inspected; other paths are still used to
/// resolve links, so pass the full file listing when link checking matters.
///
/// [today] is the day expiry is measured against: a concept whose `stale_after`
/// has passed is reported as a warning. It is a parameter rather than a
/// `DateTime.now()` call so the check is deterministic under test; when omitted,
/// expiry is not checked at all.
OkfValidationResult validateBundle(
  Map<String, String> files, {
  DateTime? today,
}) {
  final issues = <OkfIssue>[];
  final markdownPaths = files.keys.where((p) => p.endsWith('.md')).toList()
    ..sort();
  final knownPaths = files.keys.toSet();
  var conceptCount = 0;

  if (!knownPaths.contains('index.md')) {
    issues.add(
      const OkfIssue(
        severity: Severity.warning,
        path: 'index.md',
        message:
            'bundle root has no index.md, so consumers cannot browse the '
            'bundle without walking the tree (§8)',
      ),
    );
  }

  for (final path in markdownPaths) {
    final content = files[path]!;
    final filename = path.split('/').last;

    if (filename == 'index.md') {
      issues.addAll(_validateIndex(path, content, knownPaths));
      continue;
    }
    if (filename == 'log.md') {
      issues.addAll(_validateLog(path, content, knownPaths));
      continue;
    }

    conceptCount++;
    issues.addAll(_validateConcept(path, content, knownPaths, today));
  }

  return OkfValidationResult(issues: issues, conceptCount: conceptCount);
}

List<OkfIssue> _validateConcept(
  String path,
  String content,
  Set<String> knownPaths,
  DateTime? today,
) {
  final issues = <OkfIssue>[];
  final document = splitDocument(content);

  if (document.frontmatterYaml == null) {
    // §11.1: every non-reserved .md file must carry parseable frontmatter.
    return [
      OkfIssue(
        severity: Severity.error,
        path: path,
        line: 1,
        message:
            'no YAML frontmatter block; a concept must open with `---` '
            'and close with `---` on their own lines (§4.1)',
      ),
    ];
  }

  final YamlMap frontmatter;
  try {
    final parsed = loadYaml(document.frontmatterYaml!);
    if (parsed is! YamlMap) {
      return [
        OkfIssue(
          severity: Severity.error,
          path: path,
          line: 2,
          message: 'frontmatter is not a YAML mapping (§4.1)',
        ),
      ];
    }
    frontmatter = parsed;
  } on YamlException catch (e) {
    return [
      OkfIssue(
        severity: Severity.error,
        path: path,
        line: 2,
        message: 'frontmatter is not parseable YAML: ${e.message} (§11.1)',
      ),
    ];
  }

  // §11.2: a non-empty `type` is the one always-required key.
  final type = frontmatter['type'];
  if (type == null) {
    issues.add(
      OkfIssue(
        severity: Severity.error,
        path: path,
        message: 'frontmatter is missing the required `type` field (§4.1)',
      ),
    );
  } else if (type is! String || type.trim().isEmpty) {
    issues.add(
      OkfIssue(
        severity: Severity.error,
        path: path,
        message: '`type` must be a non-empty string, got `$type` (§4.1)',
      ),
    );
  }

  for (final key in _requiredHouseKeys) {
    if (!frontmatter.containsKey(key)) {
      issues.add(
        OkfIssue(
          severity: _houseRule,
          path: path,
          message:
              'frontmatter is missing `$key`, which this bundle asks every '
              'concept to carry',
        ),
      );
      continue;
    }
    // Presence alone was the whole test, so `generated:` with nothing after the
    // colon — YAML null — satisfied it. The per-field validators below then
    // treat a null the same as an absent key and stay silent, so an empty
    // housekeeping field passed clean while carrying no information at all.
    if (frontmatter[key] == null) {
      issues.add(
        OkfIssue(
          severity: _houseRule,
          path: path,
          message:
              '`$key` is empty; this bundle asks every concept to carry a '
              'value for it',
        ),
      );
    }
  }

  // `resource` is in here, not just in the presence check: `resource: ""`
  // satisfied containsKey, is not null, and is then skipped by both reference
  // checks — so a concept could declare no subject at all and validate clean
  // while the convention promised that an empty value fails the build.
  for (final key in const ['title', 'description', 'resource']) {
    final value = frontmatter[key];
    if (value == null) continue; // absent or empty: reported above
    if (value is! String || value.trim().isEmpty) {
      issues.add(
        OkfIssue(
          severity: _houseRule,
          path: path,
          message: '`$key` must be a non-empty string, got `$value`',
        ),
      );
    }
  }

  // `tags: []` passed for the same reason. Values stay unchecked — they are
  // free-form search keys — but an empty list carries none of them.
  final tags = frontmatter['tags'];
  if (tags != null && (tags is! YamlList || tags.isEmpty)) {
    issues.add(
      OkfIssue(
        severity: _houseRule,
        path: path,
        message: '`tags` must be a non-empty list, got `$tags`',
      ),
    );
  }

  issues
    ..addAll(_validateStatus(path, frontmatter))
    ..addAll(_validateGenerated(path, frontmatter))
    ..addAll(_validateVerified(path, frontmatter))
    ..addAll(_validateStaleAfter(path, frontmatter, today))
    ..addAll(_validateSources(path, frontmatter))
    ..addAll(_validateAttestedComputation(path, frontmatter, document.body))
    ..addAll(_validateBundleLinks(path, document.body, knownPaths))
    ..addAll(validateFencedBlocks(path, content))
    ..addAll(
      _validateBundleResources(path, document.frontmatterYaml, knownPaths),
    )
    ..addAll(_validateProvenanceLeavesBundle(path, document.frontmatterYaml));

  return issues;
}

/// Warns when nothing in `sources` points outside the bundle.
///
/// The house rule is that `sources` names *what the concept was derived from*,
/// and the anti-drift check only bites on references that leave the bundle: a
/// pointer at `../../lib/...` fails when the code moves, a pointer at a sibling
/// concept never does. So a concept whose only source is another concept is
/// grounded in nothing checkable — the exact shape whose drift is undetectable,
/// which is why `sources` is a required key in the first place.
///
/// Deliberately permissive about *what* counts as outside: a repo path, an
/// external URL and a §5.1 scope descriptor all qualify. The narrow thing this
/// rejects is a source set that is *entirely* bundle-internal.
List<OkfIssue> _validateProvenanceLeavesBundle(
  String path,
  String? frontmatterYaml,
) {
  if (frontmatterYaml == null) return const [];
  final Object? parsed;
  try {
    parsed = loadYaml(frontmatterYaml);
  } on YamlException {
    return const []; // reported separately
  }
  if (parsed is! YamlMap) return const [];
  final sources = parsed['sources'];
  if (sources == null) return const []; // absence reported separately

  final resources = <String>[
    if (sources is YamlList)
      for (final entry in sources)
        if (entry is YamlMap && entry['resource'] is String)
          entry['resource'] as String
        else if (entry is String)
          entry,
    if (sources is YamlMap && sources['resource'] is String)
      sources['resource'] as String,
    if (sources is String) sources,
  ];
  if (resources.isEmpty) return const [];

  final dir = path.contains('/')
      ? path.substring(0, path.lastIndexOf('/'))
      : '';
  final leavesBundle = resources.any((resource) {
    if (!_looksLikePath(resource)) return true; // scope descriptor (§5.1)
    final trimmed = resource.trim();
    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('mailto:')) {
      return true;
    }
    if (trimmed.startsWith('/')) return false; // bundle-absolute (§6.2)
    return _normalizeRelative(dir, trimmed.split('#').first).startsWith('..');
  });
  if (leavesBundle) return const [];

  return [
    OkfIssue(
      severity: _houseRule,
      path: path,
      message:
          'every `sources[].resource` stays inside the bundle, so the concept '
          'is grounded in nothing the drift check can verify; cite the code, a '
          'URL or a scope descriptor it was derived from',
    ),
  ];
}

List<OkfIssue> _validateStatus(String path, YamlMap frontmatter) {
  final status = frontmatter['status'];
  if (status == null) return const [];
  if (status is! String || !_statusValues.contains(status)) {
    return [
      OkfIssue(
        severity: _houseRule,
        path: path,
        message:
            '`status` must be one of ${_statusValues.join(', ')}, '
            'got `$status` (§5.4)',
      ),
    ];
  }
  return const [];
}

List<OkfIssue> _validateGenerated(String path, YamlMap frontmatter) {
  final generated = frontmatter['generated'];
  if (generated == null) return const [];
  if (generated is! YamlMap) {
    return [
      OkfIssue(
        severity: _houseRule,
        path: path,
        message: '`generated` must be a mapping with `by` and `at` (§5.2)',
      ),
    ];
  }

  final issues = <OkfIssue>[];
  final by = generated['by'];
  if (by == null) {
    issues.add(
      OkfIssue(
        severity: _houseRule,
        path: path,
        message: '`generated.by` is required within `generated` (§5.2)',
      ),
    );
  } else {
    issues.addAll(_validateActor(path, by, '`generated.by`'));
  }
  issues.addAll(_validateDateTime(path, generated['at'], '`generated.at`'));
  return issues;
}

List<OkfIssue> _validateVerified(String path, YamlMap frontmatter) {
  final verified = frontmatter['verified'];
  if (verified == null) return const [];

  // §5.2/§11: a bare mapping is a one-element list.
  final entries = verified is YamlList ? verified.toList() : [verified];
  final issues = <OkfIssue>[];
  for (final entry in entries) {
    if (entry is! YamlMap) {
      issues.add(
        OkfIssue(
          severity: _houseRule,
          path: path,
          message:
              'each `verified` entry must be a `{ by, at }` mapping (§5.2)',
        ),
      );
      continue;
    }
    final by = entry['by'];
    if (by == null) {
      issues.add(
        OkfIssue(
          severity: _houseRule,
          path: path,
          message: 'a `verified` entry is missing `by` (§5.2)',
        ),
      );
    } else {
      issues.addAll(_validateActor(path, by, '`verified[].by`'));
    }
    issues.addAll(_validateDateTime(path, entry['at'], '`verified[].at`'));
  }
  return issues;
}

/// Days before `stale_after` at which a concept starts warning.
///
/// Expiry is an error, so without this the first signal would be a red push on
/// the morning a date arrived — for a whole subsystem at once, since the dates
/// are batched. Two weeks is enough to schedule the re-read deliberately.
const staleWarningWindowDays = 14;

/// Checks `stale_after` for shape, and — when [today] is given — for expiry.
///
/// Expiry is an error, so `make okf_check` and CI both stop on it. The date is a
/// commitment to re-read by, and a reminder nothing ever fails on is not a
/// reminder. The cost is real and accepted: when a subsystem's date arrives,
/// clearing it means re-reading those concepts against the code, or deciding
/// deliberately to move the date. [staleWarningWindowDays] before that, the same
/// check warns, so the deadline is never a surprise.
List<OkfIssue> _validateStaleAfter(
  String path,
  YamlMap frontmatter,
  DateTime? today,
) {
  final staleAfter = frontmatter['stale_after'];
  if (staleAfter == null) return const [];
  if (!_isIsoDate(staleAfter)) {
    return [
      OkfIssue(
        severity: _houseRule,
        path: path,
        message:
            '`stale_after` must be an absolute `YYYY-MM-DD` date, '
            'got `$staleAfter` (§5.5)',
      ),
    ];
  }
  if (today == null) return const [];
  final deadline = _parseIsoDate(staleAfter);
  if (deadline == null) return const [];
  final day = DateTime.utc(today.year, today.month, today.day);
  if (day.isAfter(deadline)) {
    return [
      OkfIssue(
        severity: _houseRule,
        path: path,
        message:
            '`stale_after` passed on $staleAfter; re-read this concept against '
            'the code and either confirm it or rewrite it (§5.5)',
      ),
    ];
  }
  final daysLeft = deadline.difference(day).inDays;
  if (daysLeft > staleWarningWindowDays) return const [];
  return [
    OkfIssue(
      severity: Severity.warning,
      path: path,
      message:
          '`stale_after` is $staleAfter — $daysLeft day(s) away; schedule the '
          're-read before it becomes an error (§5.5)',
    ),
  ];
}

/// Parses an already shape-checked `YYYY-MM-DD` value into a UTC day.
DateTime? _parseIsoDate(Object? value) {
  if (value is DateTime) {
    return DateTime.utc(value.year, value.month, value.day);
  }
  final match = _isoDatePattern.firstMatch(value.toString());
  if (match == null) return null;
  return DateTime.utc(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
}

List<OkfIssue> _validateSources(String path, YamlMap frontmatter) {
  final sources = frontmatter['sources'];
  // `sources: null` satisfies the containsKey house check and `sources: []`
  // satisfies the list check with nothing to validate — either would let a
  // concept carry no code provenance while the checker called it clean.
  if (sources == null) {
    return frontmatter.containsKey('sources')
        ? [
            OkfIssue(
              severity: _houseRule,
              path: path,
              message:
                  '`sources` is present but null; a concept needs at '
                  'least one source to be attributable (§5.1)',
            ),
          ]
        : const [];
  }
  if (sources is! YamlList) {
    return [
      OkfIssue(
        severity: _houseRule,
        path: path,
        message: '`sources` must be a list of entries (§5.1)',
      ),
    ];
  }
  if (sources.isEmpty) {
    return [
      OkfIssue(
        severity: _houseRule,
        path: path,
        message:
            '`sources` is empty; a concept needs at least one source to '
            'be attributable (§5.1)',
      ),
    ];
  }

  final issues = <OkfIssue>[];
  final seenIds = <String>{};
  for (final entry in sources) {
    if (entry is! YamlMap) {
      issues.add(
        OkfIssue(
          severity: _houseRule,
          path: path,
          message: 'each `sources` entry must be a mapping (§5.1)',
        ),
      );
      continue;
    }
    // Must be a non-empty *string*: `resource: 123` would otherwise pass here
    // and then be skipped by `_resourceTargets`, which only yields strings —
    // leaving a present entry with no usable code attribution.
    final resource = entry['resource'];
    if (resource is! String || resource.trim().isEmpty) {
      issues.add(
        OkfIssue(
          severity: _houseRule,
          path: path,
          message: resource == null
              ? '`resource` is required within a `sources` entry (§5.1)'
              : '`sources[].resource` must be a non-empty string, '
                    'got `$resource` (§5.1)',
        ),
      );
    }
    final id = entry['id'];
    if (id is String && !seenIds.add(id)) {
      issues.add(
        OkfIssue(
          severity: _houseRule,
          path: path,
          message:
              'duplicate `sources[].id` `$id`; footnote attribution joins '
              'on this key so it must be unique (§5.1)',
        ),
      );
    }
    final lastModified = entry['last_modified'];
    if (lastModified != null && !_isIsoDate(lastModified)) {
      issues.add(
        OkfIssue(
          severity: _houseRule,
          path: path,
          message:
              '`sources[].last_modified` must be `YYYY-MM-DD`, '
              'got `$lastModified` (§5.1)',
        ),
      );
    }
    final author = entry['author'];
    if (author != null) {
      issues.addAll(_validateActor(path, author, '`sources[].author`'));
    }
  }
  return issues;
}

List<OkfIssue> _validateAttestedComputation(
  String path,
  YamlMap frontmatter,
  String body,
) {
  if (frontmatter['type'] != 'Attested Computation') return const [];

  final issues = <OkfIssue>[];
  if (frontmatter['runtime'] == null) {
    issues.add(
      OkfIssue(
        severity: Severity.warning,
        path: path,
        message: '`runtime` is required for an Attested Computation (§10.2)',
      ),
    );
  }

  // §10.3 wants a *path* here. A mere non-null test let `computation: false`,
  // `computation: []` and `computation: ""` satisfy the file form, so a concept
  // could claim an attested computation while pointing at nothing followable.
  final computation = frontmatter['computation'];
  final hasComputationFile =
      computation is String && _looksLikePath(computation);
  if (computation != null && !hasComputationFile) {
    issues.add(
      OkfIssue(
        severity: Severity.warning,
        path: path,
        message:
            '`computation` must be a path to the computation definition, got '
            '`$computation` (§10.3)',
      ),
    );
  }
  final hasComputationHeading = body.contains(
    RegExp(r'^#+\s+Computation\s*$', multiLine: true),
  );
  if (!hasComputationFile && !hasComputationHeading) {
    issues.add(
      OkfIssue(
        severity: Severity.warning,
        path: path,
        message:
            'an Attested Computation needs either a `computation` path or a '
            '`# Computation` body section (§10.3)',
      ),
    );
  }
  return issues;
}

List<OkfIssue> _validateActor(String path, Object? actor, String label) {
  if (actor is! String || !_actorPattern.hasMatch(actor)) {
    return [
      OkfIssue(
        severity: _houseRule,
        path: path,
        message:
            '$label `$actor` does not follow the actor convention '
            '`<producer>/<version>`, `human:<id>` or `process:<id>` (§7)',
      ),
    ];
  }
  return const [];
}

List<OkfIssue> _validateDateTime(String path, Object? value, String label) {
  if (value == null) {
    return [
      OkfIssue(
        severity: _houseRule,
        path: path,
        message:
            '$label is missing; consumers use it to tell a recent edit '
            'from a stale fact (§5.2)',
      ),
    ];
  }
  if (value is DateTime) return const [];
  if (value is String && _isRealIsoDateTime(value)) return const [];
  return [
    OkfIssue(
      severity: _houseRule,
      path: path,
      message:
          '$label must be an ISO 8601 datetime such as '
          '`2026-07-26T09:00:00Z`, got `$value` (§5.2)',
    ),
  ];
}

List<OkfIssue> _validateIndex(
  String path,
  String content,
  Set<String> knownPaths,
) {
  final issues = <OkfIssue>[];
  final document = splitDocument(content);

  // §8/§12: only a bundle-root index.md may carry frontmatter, and then only
  // to declare okf_version.
  if (document.frontmatterYaml != null) {
    if (path != 'index.md') {
      issues.add(
        OkfIssue(
          severity: Severity.error,
          path: path,
          line: 1,
          message: 'only the bundle-root index.md may carry frontmatter (§8)',
        ),
      );
    } else {
      // Guarded the same way concept frontmatter is: an unguarded loadYaml here
      // would throw past the issue list and take the CLI down with a stack
      // trace instead of reporting a file-scoped diagnostic.
      Object? parsed;
      try {
        parsed = loadYaml(document.frontmatterYaml!);
      } on YamlException catch (e) {
        return [
          OkfIssue(
            severity: Severity.error,
            path: path,
            line: 2,
            message:
                'root index.md frontmatter is not parseable YAML: '
                '${e.message} (§8)',
          ),
        ];
      }
      if (parsed is! YamlMap) {
        issues.add(
          OkfIssue(
            severity: Severity.error,
            path: path,
            line: 2,
            message: 'root index.md frontmatter is not a YAML mapping (§8)',
          ),
        );
      } else {
        final extraKeys = parsed.keys.where((k) => k != 'okf_version').toList();
        if (extraKeys.isNotEmpty) {
          issues.add(
            OkfIssue(
              severity: Severity.error,
              path: path,
              line: 2,
              message:
                  'root index.md frontmatter may only declare '
                  '`okf_version`, found ${extraKeys.join(', ')} (§8)',
            ),
          );
        }
        final declared = parsed['okf_version'];
        if (declared == null) {
          // A frontmatter block that omits the key is as uninformative as no
          // block at all, and the fallback warning below only fires when the
          // whole block is missing.
          issues.add(
            OkfIssue(
              severity: _houseRule,
              path: path,
              message:
                  'root index.md frontmatter declares no `okf_version`, so '
                  'consumers cannot tell which revision to expect (§12)',
            ),
          );
        } else if (declared.toString() != okfVersion) {
          issues.add(
            OkfIssue(
              severity: _houseRule,
              path: path,
              message:
                  'bundle declares okf_version `$declared` but this '
                  'validator implements $okfVersion (§12)',
            ),
          );
        }
      }
    }
  } else if (path == 'index.md') {
    issues.add(
      OkfIssue(
        severity: _houseRule,
        path: path,
        message:
            'root index.md should declare `okf_version: "$okfVersion"` so '
            'consumers know which revision to expect (§12)',
      ),
    );
  }

  if (!content.contains(RegExp(r'^#+\s+\S', multiLine: true))) {
    issues.add(
      OkfIssue(
        severity: Severity.warning,
        path: path,
        message:
            'index.md should group entries under at least one heading (§8)',
      ),
    );
  }

  issues
    ..addAll(_validateBundleLinks(path, document.body, knownPaths))
    ..addAll(validateFencedBlocks(path, content));
  return issues;
}

List<OkfIssue> _validateLog(
  String path,
  String content,
  Set<String> knownPaths,
) {
  final issues = <OkfIssue>[];
  final document = splitDocument(content);
  // A log entry's whole value is the pointer to what changed, and log.md is the
  // one file linking concepts most densely. It was the only .md file whose
  // bundle-internal links nothing checked — the repo pass covers its `../../lib`
  // pointers, but a renamed concept left a dead `[x](features/x/overview.md)`
  // here in silence.
  issues
    ..addAll(_validateBundleLinks(path, document.body, knownPaths))
    ..addAll(validateFencedBlocks(path, content));
  if (document.frontmatterYaml != null) {
    issues.add(
      OkfIssue(
        severity: Severity.error,
        path: path,
        line: 1,
        message: 'log.md must not carry frontmatter (§9)',
      ),
    );
  }

  // Strip fences first, exactly as the link scanner does: a `## example` line
  // inside a fenced Markdown sample is not a log heading.
  final lines = const LineSplitter().convert(stripCodeSpans(content));
  var sawDateHeading = false;
  for (var i = 0; i < lines.length; i++) {
    final match = _logDateHeadingPattern.firstMatch(lines[i]);
    if (match == null) continue;
    sawDateHeading = true;
    final date = match.group(1)!;
    if (!_isRealIsoDate(date)) {
      issues.add(
        OkfIssue(
          severity: Severity.error,
          path: path,
          line: i + 1,
          message:
              'log date heading `$date` must use ISO 8601 `YYYY-MM-DD` '
              'form (§9)',
        ),
      );
    }
  }
  if (!sawDateHeading) {
    issues.add(
      OkfIssue(
        severity: Severity.warning,
        path: path,
        message: 'log.md has no `## YYYY-MM-DD` entries (§9)',
      ),
    );
  }
  return issues;
}

/// Reports bundle-internal markdown links whose target is missing.
///
/// §6.1 says consumers MUST tolerate broken links, so these are warnings, not
/// errors: a dangling link may legitimately point at knowledge nobody has
/// written yet. Links that leave the bundle (`../lib/...`, `https://...`) are
/// resolved by [validateRepoReferences] instead, which needs the repo root and
/// therefore runs only in the CLI.
List<OkfIssue> _validateBundleLinks(
  String path,
  String body,
  Set<String> knownPaths,
) => _validateBundleTargets(path, linkTargets(body), knownPaths, 'link target');

/// Checks bundle-internal `sources[].resource` values.
///
/// A resource may be bundle-absolute (`/domain/task.md`, §6.2) or relative
/// (`./sibling.md`). Both were checked by nothing: [validateRepoReferences]
/// skips `/`-prefixed targets (for a link that means "relative to the bundle")
/// and only reports targets that *escape* the bundle, while the body-link
/// scanner never sees frontmatter at all. Handing every path-shaped resource to
/// [_validateBundleTargets] closes both halves of that gap — it already skips
/// escaping targets, leaving them to the repo pass.
List<OkfIssue> _validateBundleResources(
  String path,
  String? frontmatterYaml,
  Set<String> knownPaths,
) => _validateBundleTargets(
  path,
  _resourceTargets(frontmatterYaml),
  knownPaths,
  '`sources[].resource`',
);

List<OkfIssue> _validateBundleTargets(
  String path,
  Iterable<String> targets,
  Set<String> knownPaths,
  String label,
) {
  final issues = <OkfIssue>[];
  final dir = path.contains('/')
      ? path.substring(0, path.lastIndexOf('/'))
      : '';

  for (final target in targets) {
    if (target.startsWith('http://') ||
        target.startsWith('https://') ||
        target.startsWith('mailto:') ||
        target.startsWith('#')) {
      continue;
    }
    final withoutAnchor = target.split('#').first;
    if (withoutAnchor.isEmpty) continue;

    final String resolved;
    if (withoutAnchor.startsWith('/')) {
      resolved = withoutAnchor.substring(1);
    } else {
      resolved = _normalizeRelative(dir, withoutAnchor);
      // Leaves the bundle; the CLI checks these against the repo instead.
      if (resolved.startsWith('..')) continue;
    }

    // A link to `subdir/` is satisfied by that directory's index.md (§8).
    final candidates = resolved.endsWith('/')
        ? {resolved, '${resolved}index.md'}
        : {resolved};
    if (candidates.any(knownPaths.contains)) continue;

    issues.add(
      OkfIssue(
        severity: Severity.warning,
        path: path,
        message: '$label `$target` does not exist in the bundle (§6.1)',
      ),
    );
  }
  return issues;
}

/// Checks every reference that leaves the bundle and points at a repo file.
///
/// This is the check that keeps the map honest. A concept may say anything
/// about `lib/features/sync`, but if it links or points its `resource` at a
/// path that no longer exists, the knowledge has drifted from the code and the
/// build should fail. Unlike bundle-internal links (§6.1, tolerated), a dangling
/// repo pointer is reported as [Severity.error]: it is a repo-local rule layered
/// on top of OKF, not a claim about what consumers must reject.
///
/// [files] maps bundle-relative paths to contents, [bundleRoot] is the bundle
/// directory relative to the repo root (`knowledge`), and [repoFileExists] is
/// asked about repo-relative paths (`lib/features/sync`).
List<OkfIssue> validateRepoReferences({
  required Map<String, String> files,
  required String bundleRoot,
  required bool Function(String repoRelativePath) repoFileExists,
}) {
  final issues = <OkfIssue>[];
  final rootPrefix = bundleRoot.split('/').where((s) => s.isNotEmpty).join('/');

  for (final path
      in files.keys.where((p) => p.endsWith('.md')).toList()..sort()) {
    final document = splitDocument(files[path]!);
    final dir = path.contains('/')
        ? path.substring(0, path.lastIndexOf('/'))
        : '';

    final targets = <String>[
      ...linkTargets(document.body),
      ..._resourceTargets(document.frontmatterYaml),
    ];

    for (final target in targets) {
      if (target.startsWith('http://') ||
          target.startsWith('https://') ||
          target.startsWith('mailto:') ||
          target.startsWith('#') ||
          target.startsWith('/')) {
        continue;
      }
      final withoutAnchor = target.split('#').first;
      if (withoutAnchor.isEmpty) continue;

      final resolved = _normalizeRelative(dir, withoutAnchor);
      if (!resolved.startsWith('..')) continue; // stays inside the bundle

      // Resolve against the concept's own directory *inside the repo*, so
      // `knowledge/architecture/x.md` + `../../lib/main.dart` = `lib/main.dart`.
      final repoBase = [rootPrefix, dir].where((s) => s.isNotEmpty).join('/');
      // A reference that lands exactly on the repository root normalizes to the
      // empty string, and neither `File('')` nor `Directory('')` exists — so a
      // repo-wide concept declaring `resource: ../..` was reported as a dangling
      // pointer. `.` is the same directory, and it does exist.
      final normalized = _normalizeRelative(repoBase, withoutAnchor);
      final repoPath = normalized.isEmpty ? '.' : normalized;
      if (repoPath.startsWith('..')) {
        issues.add(
          OkfIssue(
            severity: Severity.error,
            path: path,
            message: 'reference `$target` escapes the repository root',
          ),
        );
        continue;
      }
      if (repoFileExists(repoPath)) continue;

      issues.add(
        OkfIssue(
          severity: Severity.error,
          path: path,
          message:
              'reference `$target` points at `$repoPath`, which does not '
              'exist in the repository; the concept has drifted from the code',
        ),
      );
    }
  }
  return issues;
}

/// Rewrites [bundleRoot] as a path relative to [workingDirectory].
///
/// [validateRepoReferences] resolves a concept's `../../lib/...` pointers
/// against the bundle root and then asks the filesystem about the result, so
/// that root has to be relative to where the process runs. Given an absolute
/// `/home/me/lotti/knowledge`, every pointer resolved to
/// `home/me/lotti/lib/...` — read relative to the working directory, therefore
/// nonexistent — so a correct bundle reported hundreds of drift errors purely
/// because of how it was invoked.
///
/// Returns `null` when [bundleRoot] is absolute and lies outside
/// [workingDirectory], where repository references cannot be resolved at all.
/// Relative roots are returned unchanged: `../lotti/knowledge` already resolves
/// correctly against the working directory.
String? repoRelativeBundleRoot(
  String bundleRoot, {
  required String workingDirectory,
}) {
  final normalized = bundleRoot.replaceAll(r'\', '/');
  if (!normalized.startsWith('/')) return normalized;

  final cwd = workingDirectory
      .replaceAll(r'\', '/')
      .replaceFirst(
        RegExp(r'/$'),
        '',
      );
  if (normalized == cwd) return '.';
  if (normalized.startsWith('$cwd/')) {
    return normalized.substring(cwd.length + 1);
  }
  return null;
}

/// Whether a `sources[].resource` should be resolved as a path.
///
/// §5.1 lets a resource be either something a consumer can follow or a scope
/// descriptor it cannot ("all queries in BigQuery project X"). Treating *any*
/// spaced string as a descriptor was too permissive: a typo like
/// `../../lib/missing file.dart` was silently exempted from the anti-drift
/// check, and prose could stand in as a concept's only attribution.
///
/// So the test is path *shape*, not the absence of spaces: anything carrying a
/// separator or a leading `.` is a path — spaces and all — while a bare phrase
/// with neither is a descriptor.
///
/// A bare `missing.dart` has neither, yet is unambiguously a same-directory file
/// rather than prose, so a filename-with-extension shape counts too. The
/// extension bound keeps a sentence ending in a period (`Discussed in the
/// design review.`) on the descriptor side.
bool _looksLikePath(String resource) {
  final trimmed = resource.trim();
  if (trimmed.isEmpty) return false;
  if (trimmed.contains('/') || trimmed.startsWith('.')) return true;
  return _bareFilenamePattern.hasMatch(trimmed);
}

final _bareFilenamePattern = RegExp(r'^[\w][\w-]*\.[A-Za-z0-9]{1,8}$');

/// Collects `resource`-shaped values out of a raw frontmatter block.
Iterable<String> _resourceTargets(String? frontmatterYaml) sync* {
  if (frontmatterYaml == null) return;
  final Object? parsed;
  try {
    parsed = loadYaml(frontmatterYaml);
  } on YamlException {
    return; // reported separately by _validateConcept
  }
  if (parsed is! YamlMap) return;

  final resource = parsed['resource'];
  if (resource is String) yield resource;

  final sources = parsed['sources'];
  if (sources is YamlList) {
    for (final entry in sources) {
      if (entry is! YamlMap) continue;
      final entryResource = entry['resource'];
      if (entryResource is String && _looksLikePath(entryResource)) {
        yield entryResource;
      }
    }
  }

  for (final key in ['computation', 'executor', 'attester']) {
    final value = parsed[key];
    if (value is String) yield value;
    if (value is YamlMap && value['resource'] is String) {
      yield value['resource'] as String;
    }
  }
}

String _normalizeRelative(String dir, String target) {
  final segments = <String>[
    ...dir.split('/').where((s) => s.isNotEmpty),
  ];
  final trailingSlash = target.endsWith('/');
  for (final segment in target.split('/')) {
    if (segment.isEmpty || segment == '.') continue;
    if (segment == '..') {
      if (segments.isNotEmpty && segments.last != '..') {
        segments.removeLast();
      } else {
        segments.add('..');
      }
      continue;
    }
    segments.add(segment);
  }
  final joined = segments.join('/');
  return trailingSlash ? '$joined/' : joined;
}

bool _isIsoDate(Object? value) {
  if (value is DateTime) return true;
  return value is String && _isRealIsoDate(value);
}
