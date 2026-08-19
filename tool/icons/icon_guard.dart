/// Checks that icons in `lib/` go through the design system's semantic token
/// layer rather than being picked glyph-by-glyph at the call site.
///
/// Two rules, and a ratchet.
///
/// **Rule 1 — no raw icon families in feature code.** `Icons.*` (Material) and
/// `MdiIcons.*` (Material Design Icons) are the vocabulary the app is migrating
/// off. Every occurrence is debt.
///
/// **Rule 2 — Lucide is bound in exactly one place.** `LucideIcons.*` belongs in
/// `icon_tokens.dart`, plus the small set of enum-to-glyph maps that carry
/// domain pictograms (a category's icon, an entry type). Anywhere else it is
/// just the old call-site-picks-a-glyph problem wearing a new font.
///
/// **The ratchet.** The migration is phased across many pull requests, so a flat
/// ban would fail `main` for as long as the rollout takes — and a check that is
/// expected to fail teaches everyone to ignore it. Instead the baseline records
/// the debt each file still carries. A file may shrink or disappear; it may
/// never grow, and a file absent from the baseline may not introduce any. That
/// keeps the count monotonically decreasing without ever blocking the tree.
library;

import 'dart:convert';
import 'dart:io';

/// `Icons.` but not `LucideIcons.` / `MdiIcons.` / `CupertinoIcons.` — the
/// lookbehind is what keeps the other families from being counted as Material.
final RegExp _material = RegExp(r'(?<![A-Za-z0-9_$])Icons\.');
final RegExp _mdi = RegExp(r'(?<![A-Za-z0-9_$])MdiIcons\.');
final RegExp _lucide = RegExp(r'(?<![A-Za-z0-9_$])LucideIcons\.');

/// Generated sources restate whatever the hand-written source said, so counting
/// them would double-report a single call site and make the baseline drift on
/// every `build_runner` run.
bool isGenerated(String path) =>
    path.endsWith('.g.dart') ||
    path.endsWith('.freezed.dart') ||
    path.endsWith('.gr.dart');

/// The one file allowed to bind a semantic token to a Lucide glyph.
const tokenFile = 'lib/features/design_system/theme/icon_tokens.dart';

/// Files allowed to reference Lucide directly because they map a *domain value*
/// the user chose — a category, an entry type — onto a pictogram. These are not
/// UI vocabulary and would make [tokenFile] unsearchable if folded into it.
///
/// Additions need a reason of that shape. "It was convenient" is not one.
const domainGlyphAllowlist = <String>{
  'lib/features/categories/domain/category_icon_data.dart',
};

/// One file's outstanding debt.
class FileDebt {
  const FileDebt(this.path, this.count);

  final String path;
  final int count;
}

/// A single rule violation, phrased as something the reader can act on.
class IconViolation {
  const IconViolation(this.path, this.message);

  final String path;
  final String message;

  @override
  String toString() => '$path: $message';
}

/// The result of a scan: what each file still owes, and what broke the rules.
class GuardResult {
  const GuardResult(this.debt, this.violations);

  final Map<String, int> debt;
  final List<IconViolation> violations;

  int get totalDebt => debt.values.fold(0, (a, b) => a + b);
}

/// Counts legacy icon references and checks Lucide containment across [root].
///
/// [baseline] maps a repo-relative path to the number of legacy references it
/// was last known to carry. Pass an empty map to scan without ratcheting, which
/// is what `--update-baseline` does.
GuardResult scan({
  required Directory root,
  required Map<String, int> baseline,
  required String repoRoot,
}) {
  final debt = <String, int>{};
  final violations = <IconViolation>[];

  final files =
      root
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final rel = _relative(file.path, repoRoot);
    if (isGenerated(rel)) continue;

    final source = file.readAsStringSync();
    final legacy =
        _material.allMatches(source).length + _mdi.allMatches(source).length;

    if (legacy > 0) {
      debt[rel] = legacy;
      final allowed = baseline[rel] ?? 0;
      if (legacy > allowed) {
        violations.add(
          IconViolation(
            rel,
            allowed == 0
                ? 'introduces $legacy raw `Icons.`/`MdiIcons.` reference'
                      '${legacy == 1 ? '' : 's'}. Use a token from '
                      '`LottiIcons` instead, and add one there if none fits.'
                : 'raw icon references grew from $allowed to $legacy. This file '
                      'is mid-migration; it may shrink, not grow.',
          ),
        );
      }
    }

    if (_lucide.hasMatch(source) &&
        rel != tokenFile &&
        !domainGlyphAllowlist.contains(rel)) {
      violations.add(
        IconViolation(
          rel,
          'references `LucideIcons` directly. Feature code names the intent '
          '(`LottiIcons.confirm`), not the glyph — see `$tokenFile`.',
        ),
      );
    }
  }

  return GuardResult(debt, violations);
}

String _relative(String path, String repoRoot) {
  final normalizedRoot = repoRoot.endsWith('/') ? repoRoot : '$repoRoot/';
  return path.startsWith(normalizedRoot)
      ? path.substring(normalizedRoot.length)
      : path;
}

/// Reads a baseline file, treating a missing one as "no debt is tolerated".
Map<String, int> readBaseline(File file) {
  if (!file.existsSync()) return const {};
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map) return const {};
  final files = decoded['files'];
  if (files is! Map) return const {};
  return {
    for (final entry in files.entries)
      entry.key as String: (entry.value as num).toInt(),
  };
}

/// Serialises a baseline deterministically, so a re-run produces no diff.
String encodeBaseline(Map<String, int> debt) {
  final keys = debt.keys.toList()..sort();
  final buffer = StringBuffer()
    ..writeln('{')
    ..writeln(
      '  "_comment": "Legacy Material/MDI icon references still to be '
      'migrated to LottiIcons. Regenerate with: dart run '
      'tool/icons/validate.dart --update-baseline. This number only ever '
      'goes down.",',
    )
    ..writeln('  "_total": ${debt.values.fold(0, (a, b) => a + b)},')
    ..writeln('  "files": {');
  for (var i = 0; i < keys.length; i++) {
    final comma = i == keys.length - 1 ? '' : ',';
    buffer.writeln('    ${jsonEncode(keys[i])}: ${debt[keys[i]]}$comma');
  }
  buffer
    ..writeln('  }')
    ..writeln('}');
  return buffer.toString();
}
