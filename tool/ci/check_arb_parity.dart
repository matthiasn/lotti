import 'dart:convert';
import 'dart:io';

/// The template every other catalog is held against.
const templateCatalog = 'app_en.arb';

/// How a catalog key drifts from the template.
enum ArbDrift {
  /// The template has the key and the catalog does not.
  missing,

  /// The catalog has a key the template no longer has.
  orphaned,
}

/// One key of one catalog that drifts from the template.
typedef ArbParityProblem = ({String catalog, String key, ArbDrift drift});

final _catalogName = RegExp(r'^app_(\w+)\.arb$');

/// The message keys of an ARB catalog: every top-level key except the `@`
/// entries, which are metadata (`@@locale`, a message's `@key` description).
Set<String> arbMessageKeys(String source) {
  final decoded = jsonDecode(source) as Map<String, dynamic>;
  return {
    for (final key in decoded.keys)
      if (!key.startsWith('@')) key,
  };
}

/// Every key in [catalogs] (file name to message keys) that drifts from
/// [templateCatalog], sorted by catalog, then missing before orphaned, then
/// key.
///
/// A missing key does not fail `flutter gen-l10n`: it is listed in
/// `missing_translations.txt` and the user silently sees the English text, so
/// a whole feature can ship untranslated without anyone noticing. A full
/// catalog must therefore hold every template key. A regional catalog
/// (`app_en_GB.arb` next to `app_en.arb`) holds only the messages that differ
/// from its base language and inherits the rest, so it may be partial. No
/// catalog may hold a key the template lacks: that is a message whose source
/// was renamed or removed, and it is never shown.
List<ArbParityProblem> arbParityProblems(Map<String, Set<String>> catalogs) {
  final template = catalogs[templateCatalog];
  if (template == null) {
    throw ArgumentError.value(
      catalogs.keys.toList(),
      'catalogs',
      'has no $templateCatalog',
    );
  }
  bool isRegional(String catalog) {
    final locale = _catalogName.firstMatch(catalog)?.group(1);
    if (locale == null || !locale.contains('_')) return false;
    return catalogs.containsKey('app_${locale.split('_').first}.arb');
  }

  List<String> sorted(Set<String> keys) => keys.toList()..sort();

  return [
    for (final catalog in sorted(catalogs.keys.toSet()))
      if (catalog != templateCatalog) ...[
        if (!isRegional(catalog))
          for (final key in sorted(template.difference(catalogs[catalog]!)))
            (catalog: catalog, key: key, drift: ArbDrift.missing),
        for (final key in sorted(catalogs[catalog]!.difference(template)))
          (catalog: catalog, key: key, drift: ArbDrift.orphaned),
      ],
  ];
}

void main() {
  final catalogs = {
    for (final file in Directory('lib/l10n').listSync().whereType<File>().where(
      (file) => _catalogName.hasMatch(file.uri.pathSegments.last),
    ))
      file.uri.pathSegments.last: arbMessageKeys(file.readAsStringSync()),
  };
  final problems = arbParityProblems(catalogs);
  for (final (:catalog, :key, :drift) in problems) {
    stderr.writeln(switch (drift) {
      ArbDrift.missing =>
        'lib/l10n/$catalog: missing "$key" — translate it '
            '(every catalog holds every key of $templateCatalog)',
      ArbDrift.orphaned =>
        'lib/l10n/$catalog: "$key" is not in $templateCatalog — remove it',
    });
  }
  if (problems.isNotEmpty) exitCode = 1;
}
