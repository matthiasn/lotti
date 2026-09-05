// Enforces the private-visibility gate described in
// knowledge/architecture/persistence.md ("Private visibility is gated three
// different ways"): every read of journal rows either applies the gate or is
// listed here with the reason it deliberately does not.
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const _driftFile = 'lib/database/database.drift';
const _concept =
    'knowledge/architecture/persistence.md, "Private visibility is gated '
    'three different ways"';

/// Named queries in `database.drift` that read journal rows, apply no
/// private predicate, and are called from at least one place that does not
/// dispatch on the flag — each with the reason that is deliberate.
///
/// An entry that stops being needed fails the build too, so this list can
/// only ever describe the current exceptions.
const _ungatedNamedQueries = <String, String>{
  // Resolving ids the caller already holds: the flag changes what browsing
  // surfaces, not what an identifier resolves to.
  'entriesForIds':
      'ids the caller holds, tombstones included (task blockers, checklist '
      'updates)',
  'journalEntitiesByIdsUnorderedAllPrivate':
      'ids the caller holds (editor drafts, checklist items, coalesced by-id '
      'reads, outbox bundles)',
  'ratingForTimeEntry': 'the rating attached to an entry the caller holds',
  // Sync: every device holds every row, private or not.
  'orderedJournalInterval': 'historical re-sync walks every row for peers',
  // No rows at all.
  'emptyJournalSelection': 'WHERE 1 = 0: the placeholder for an empty filter',
  // Numbers, not rows.
  'countJournalEntries': 'a count for maintenance progress',
  'countImportFlagEntries': 'a count for the import badge',
  // Not gated today. Listed here rather than silently so; whether they
  // should gate is the product decision tracked in lotti3-0qaz.
  'sortedCalenderEntriesInRange': 'not gated today: the calendar range read',
  'measurementsByType': 'not gated today: dashboard measurement series',
  'habitCompletionsByHabitId': 'not gated today: habit completion series',
  'quantitativeByType': 'not gated today: health quantitative series',
  'latestQuantByType': 'not gated today: latest health quantitative value',
  'workouts': 'not gated today: workout series',
  'findLatestWorkout': 'not gated today: latest workout',
  'workoutsByType': 'not gated today: workout series by type',
  'workoutTypes': 'not gated today: distinct workout types',
  'surveysByType': 'not gated today: survey completion series',
};

/// Dart declarations (`lib/…/file.dart:name`) that read journal rows —
/// through their own SQL or Drift query, or by calling a builder whose
/// private predicate is optional without supplying it — with no gate, each
/// with the reason.
const _ungatedDeclarations = <String, String>{
  // Resolving ids the caller already holds.
  'lib/database/database_journal_queries.dart:entityById':
      'the single-entity read behind every detail page',
  'lib/database/database_journal_queries.dart:'
          'getJournalEntitiesForIdsIncludingDeleted':
      'ids the caller holds, tombstones included (demo reseed inventory)',
  'lib/database/database_task_queries.dart:getTaskEstimatesByIds':
      'estimates for task ids the caller holds',
  'lib/database/database_project_queries.dart:getTaskIdsForProjects':
      'id-to-id resolution for project ids the caller holds; no row content',
  'lib/database/database_project_queries.dart:getExistingProjectIds':
      'existence check on project ids the caller holds; no row content',
  'lib/database/database_project_queries.dart:getProjectIdsForTaskIds':
      'id-to-id resolution for task ids the caller holds; no row content',
  'lib/database/database_project_queries.dart:getProjectIdMapForTasks':
      'id-to-id resolution for task ids the caller holds; no row content',
  // Sync and maintenance: every device holds every row, and nothing these
  // select is shown to a user.
  'lib/database/database_journal_queries.dart:'
          'journalEntityMapForIdsIncludingDeleted':
      'outbound sync payloads, tombstones included',
  'lib/database/database_journal_queries.dart:streamEntriesWithVectorClock':
      'sequence-log population walks every row for sync',
  'lib/database/database_journal_queries.dart:allNonDeletedJournalEntityIds':
      'ids only, for the demo reseed guard',
  'lib/database/database_entity_ops.dart:purgeDeletedFiles':
      'the purge walk over deleted rows',
  'lib/database/maintenance.dart:recreateFts5':
      'reindexes every row; search hits resolve through the gated id-batch '
      'read',
  'lib/database/database_relationship_queries.dart:'
          'getAllCheckInsForRelationship':
      "the delete cascade's view of a person's check-ins, private ones "
      'included, so a deletion cannot strand them (ADR 0037 §5)',
  'lib/logic/create/create_entry.dart:_softDeleteFailedProjectTask':
      'verifies by id that the task it just wrote is tombstoned; no row '
      'content is shown',
  // Numbers, not rows.
  'lib/database/database_journal_queries.dart:countAllJournalEntries':
      'a count for progress reporting, deleted rows included',
  // Not gated today (lotti3-0qaz).
  'lib/database/database_journal_queries.dart:getDayAudioEntries':
      'not gated today: the Daily OS audio entries of a day',
};

/// Files whose journal SQL is not a read path at all.
const _filesOutsideTheReadPath = <String, String>{
  'lib/database/database_migration_recent.dart':
      'the migration ladder rewrites rows; nothing it selects reaches a user',
};

/// SQL that reads the journal table: a `FROM` or `JOIN` on it, in a named
/// query or in a Dart string. `\b` keeps `journal_fts` and the like out.
final RegExp _readsJournalSql = RegExp(
  r'\b(from|join)\s+journal\b',
  caseSensitive: false,
);

/// A Drift Dart-API read of the table, bare (`select(journal)` inside the
/// database) or qualified (`db.select(db.journal)` from a repository).
/// `into`/`update`/`delete` are writes.
final RegExp _readsJournalApi = RegExp(
  r'\b(select|selectOnly)\(\s*(?:[\w$]+\.)*journal\s*\)',
);

/// An approved filtering predicate on the column in SQL: `private IN …`
/// (bound statuses, a placeholder list, or the `config_flags` subquery), or
/// the insights CTE's `COALESCE(<alias>.private, FALSE) IN (FALSE, …)`.
/// A query that merely selects or orders by the column does not match.
final RegExp _sqlPredicate = RegExp(
  r'(?:\bprivate\b|coalesce\(\s*[\w.]*\bprivate\b\s*,\s*false\s*\))\s+in\b',
  caseSensitive: false,
);

/// The same predicate written through the Drift Dart API, and the IN-clause
/// helper the broad task builder writes its `private IN (…)` with.
final RegExp _dartPredicate = RegExp(
  r"\.private\.isIn\(|addInClause<bool>\(\s*'private'",
);

/// A dispatch on the flag: the helper that picks the all-private variant
/// only when every private state is visible, or the check it is built on.
final RegExp _dispatch = RegExp(
  r'_queryWithPrivateFilter\(|_matchesAllPrivateStates\(',
);

/// A declaration whose private predicate is optional: its callers, not it,
/// decide whether rows are filtered.
final RegExp _optionalStatuses = RegExp(r'List<bool>\?\s+privateStatuses');

typedef _NamedQuery = ({String name, String sql});

/// Every named query in [_driftFile] with its SQL, comments removed.
List<_NamedQuery> _namedQueries() {
  final source = File(_driftFile).readAsStringSync();
  final header = RegExp(r'^([A-Za-z0-9_]+):\s*$', multiLine: true);
  final matches = header.allMatches(source).toList();
  return [
    for (var i = 0; i < matches.length; i++)
      (
        name: matches[i].group(1)!,
        sql: source
            .substring(
              matches[i].end,
              i + 1 < matches.length ? matches[i + 1].start : source.length,
            )
            .replaceAll(RegExp('--.*'), ''),
      ),
  ];
}

typedef _Declaration = ({
  String file,
  String name,
  String source,
  AstNode node,
});

/// Hand-written Dart sources under `lib/`.
final List<File> _libSources = Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where(
      (f) =>
          f.path.endsWith('.dart') &&
          !f.path.endsWith('.g.dart') &&
          !f.path.endsWith('.freezed.dart'),
    )
    .toList();

String _relative(File file) => p.split(p.relative(file.path)).join('/');

final Map<String, List<_Declaration>> _parsed = {};

/// Every method, function, field and top-level variable in [file], each
/// with the source text of its own declaration (comments excluded). The
/// parser, not a pattern, decides where one declaration ends and the next
/// begins, so an SQL string is always attributed to the code that runs it.
List<_Declaration> _declarations(File file) {
  final path = _relative(file);
  return _parsed[path] ??= () {
    final result = parseString(
      content: file.readAsStringSync(),
      path: path,
      throwIfDiagnostics: false,
    );
    if (result.errors.isNotEmpty) {
      fail(
        '$path does not parse, so nothing in it was audited.\n'
        '${result.errors.join('\n')}',
      );
    }

    final declarations = <_Declaration>[];
    void add(String name, AstNode node) => declarations.add((
      file: path,
      name: name,
      source: node.toSource(),
      node: node,
    ));
    void addMembers(Iterable<ClassMember> members) {
      for (final member in members) {
        switch (member) {
          case MethodDeclaration():
            add(member.name.lexeme, member);
          case FieldDeclaration():
            for (final variable in member.fields.variables) {
              add(variable.name.lexeme, variable);
            }
          case ConstructorDeclaration():
            add(member.name?.lexeme ?? 'new', member);
          case PrimaryConstructorBody():
            break;
        }
      }
    }

    Iterable<ClassMember> membersOf(ClassBody body) => switch (body) {
      BlockClassBody() => body.members,
      EmptyClassBody() => const [],
    };

    for (final declaration in result.unit.declarations) {
      switch (declaration) {
        case ClassDeclaration():
          addMembers(membersOf(declaration.body));
        case MixinDeclaration():
          addMembers(membersOf(declaration.body));
        case ExtensionDeclaration():
          addMembers(membersOf(declaration.body));
        case EnumDeclaration():
          addMembers(declaration.body.members);
        case FunctionDeclaration():
          add(declaration.name.lexeme, declaration);
        case TopLevelVariableDeclaration():
          for (final variable in declaration.variables.variables) {
            add(variable.name.lexeme, variable);
          }
        default:
          break;
      }
    }
    return declarations;
  }();
}

/// Declarations in every `lib/` file whose text mentions [needle]. Files
/// that cannot contain a match are not parsed, which keeps the audit cheap
/// on a tree of this size.
List<_Declaration> _declarationsMentioning(String needle) => [
  for (final file in _libSources)
    if (file.readAsStringSync().contains(needle)) ..._declarations(file),
];

/// Declarations anywhere in `lib/` that invoke [name].
List<_Declaration> _callersOf(String name) => _declarationsMentioning(
  name,
).where((d) => RegExp('\\b$name\\(').hasMatch(d.source)).toList();

String _key(_Declaration d) => '${d.file}:${d.name}';

/// Whether [d] takes an optional `privateStatuses` in its own parameter
/// list — a nested closure's parameters do not count, because only the
/// declaration itself can be called from elsewhere.
bool _isBuilder(_Declaration d) {
  final parameters = switch (d.node) {
    MethodDeclaration(:final parameters) => parameters,
    FunctionDeclaration(:final functionExpression) =>
      functionExpression.parameters,
    _ => null,
  };
  return parameters != null &&
      _optionalStatuses.hasMatch(parameters.toSource());
}

/// Every invocation of [name] inside a declaration.
class _InvocationsOf extends RecursiveAstVisitor<void> {
  _InvocationsOf(this.name);

  final String name;
  final List<MethodInvocation> found = [];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == name) found.add(node);
    super.visitMethodInvocation(node);
  }
}

/// Whether every call of the builder [name] inside [caller] supplies a
/// non-null `privateStatuses`.
bool _alwaysSuppliesStatuses(_Declaration caller, String name) {
  final visitor = _InvocationsOf(name);
  caller.node.accept(visitor);
  return visitor.found.every(
    (call) => call.argumentList.arguments.whereType<NamedExpression>().any(
      (argument) =>
          argument.name.label.name == 'privateStatuses' &&
          argument.expression is! NullLiteral,
    ),
  );
}

void main() {
  late List<_NamedQuery> queries;
  late List<_Declaration> journalMentions;

  setUpAll(() {
    queries = _namedQueries();
    journalMentions = _declarationsMentioning('journal');
  });

  group('private-visibility gate', () {
    test('every named query reading journal rows filters, is dispatched, or '
        'is listed with a reason', () {
      final ungated = queries.where(
        (q) =>
            _readsJournalSql.hasMatch(q.sql) && !_sqlPredicate.hasMatch(q.sql),
      );
      final offenders = <String>[];
      final stale = <String>[];
      for (final query in ungated) {
        final callers = _callersOf(query.name);
        final undispatched = callers
            .where((d) => !_dispatch.hasMatch(d.source))
            .map(_key)
            .toList();
        final listed = _ungatedNamedQueries.containsKey(query.name);
        if (callers.isEmpty) {
          offenders.add('${query.name}: no caller in lib/ — delete it');
        } else if (undispatched.isNotEmpty && !listed) {
          offenders.add(
            '${query.name}: called without a dispatch on the flag from '
            '${undispatched.join(', ')}',
          );
        } else if (undispatched.isEmpty && listed) {
          stale.add('${query.name}: every caller now dispatches on the flag');
        }
      }
      for (final name in _ungatedNamedQueries.keys) {
        final query = queries.where((q) => q.name == name).firstOrNull;
        if (query == null) {
          stale.add('$name: no such named query');
        } else if (!_readsJournalSql.hasMatch(query.sql)) {
          stale.add('$name: no longer reads journal rows');
        } else if (_sqlPredicate.hasMatch(query.sql)) {
          stale.add('$name: now filters on the private column');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'These named queries read journal rows without the private '
            'gate. Gate them by one of the three mechanisms in $_concept, '
            'or add them to _ungatedNamedQueries with the reason:\n'
            '${offenders.join('\n')}',
      );
      expect(
        stale,
        isEmpty,
        reason:
            'These _ungatedNamedQueries entries no longer describe an '
            'exception; remove them:\n${stale.join('\n')}',
      );
    });

    test('every Dart declaration reading journal rows filters, dispatches, '
        'or is listed with a reason', () {
      final readers = journalMentions.where(
        (d) =>
            !_filesOutsideTheReadPath.containsKey(d.file) &&
            (_readsJournalSql.hasMatch(d.source) ||
                _readsJournalApi.hasMatch(d.source)),
      );
      final offenders = <String>[];
      final stale = <String>[];
      final audited = <String>{};
      // A reader whose predicate is optional is a builder: it is not judged
      // itself, its callers are — each must dispatch on the flag or supply
      // the statuses on every call.
      final queue = <(_Declaration, String?)>[
        for (final reader in readers) (reader, null),
      ];
      final seen = <String>{};
      while (queue.isNotEmpty) {
        final (declaration, builder) = queue.removeLast();
        final key = _key(declaration);
        if (!seen.add('$key via $builder')) continue;
        if (_isBuilder(declaration)) {
          for (final caller in _callersOf(declaration.name)) {
            if (_key(caller) != key) queue.add((caller, declaration.name));
          }
          continue;
        }
        audited.add(key);
        final gated = builder == null
            ? _sqlPredicate.hasMatch(declaration.source) ||
                  _dartPredicate.hasMatch(declaration.source) ||
                  declaration.source.contains('_queryWithPrivateFilter(')
            : _dispatch.hasMatch(declaration.source) ||
                  _alwaysSuppliesStatuses(declaration, builder);
        final listed = _ungatedDeclarations.containsKey(key);
        if (!gated && !listed) {
          offenders.add(
            builder == null
                ? key
                : '$key: calls $builder without privateStatuses',
          );
        }
        if (gated && listed) stale.add('$key: now applies the gate');
      }
      for (final key in _ungatedDeclarations.keys) {
        if (!audited.contains(key)) {
          stale.add('$key: no such declaration reads journal rows');
        }
      }
      for (final file in _filesOutsideTheReadPath.keys) {
        if (!journalMentions.any(
          (d) => d.file == file && _readsJournalSql.hasMatch(d.source),
        )) {
          stale.add('$file: contains no journal SQL');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'These declarations read journal rows without the private '
            'gate. Gate them by one of the three mechanisms in $_concept, '
            'or add them to _ungatedDeclarations with the reason:\n'
            '${offenders.join('\n')}',
      );
      expect(
        stale,
        isEmpty,
        reason:
            'These allowlist entries no longer describe an exception; '
            'remove them:\n${stale.join('\n')}',
      );
    });

    // Guards the guard: a scanner that matched nothing would pass both
    // assertions above while enforcing nothing.
    test('recognises the gate where it is known to be applied', () {
      final filteredJournal = queries.singleWhere(
        (q) => q.name == 'filteredJournal',
      );
      expect(_readsJournalSql.hasMatch(filteredJournal.sql), isTrue);
      expect(_sqlPredicate.hasMatch(filteredJournal.sql), isTrue);

      _Declaration declaration(String file, String name) =>
          journalMentions.singleWhere(
            (d) => d.file == 'lib/database/$file' && d.name == name,
          );

      final habitRecords = declaration(
        'database_data_queries.dart',
        'getHabitCompletionRecordsInRange',
      );
      expect(_readsJournalSql.hasMatch(habitRecords.source), isTrue);
      expect(_sqlPredicate.hasMatch(habitRecords.source), isTrue);

      final dayAudio = declaration(
        'database_journal_queries.dart',
        'getDayAudioEntries',
      );
      expect(_readsJournalApi.hasMatch(dayAudio.source), isTrue);

      // The optional predicate belongs to the builder, not to a method that
      // merely nests a closure with one.
      final checkInRows = declaration(
        'database_relationship_queries.dart',
        '_checkInRows',
      );
      expect(_isBuilder(checkInRows), isTrue);
      expect(_dartPredicate.hasMatch(checkInRows.source), isTrue);
      final latestCheckIns = declaration(
        'database_relationship_queries.dart',
        'latestCheckInTimes',
      );
      expect(_isBuilder(latestCheckIns), isFalse);
      expect(latestCheckIns.source, contains('_queryWithPrivateFilter('));
    });

    test('a column mention is not a predicate', () {
      expect(
        _sqlPredicate.hasMatch('SELECT id, private FROM journal'),
        isFalse,
      );
      expect(
        _sqlPredicate.hasMatch('SELECT * FROM journal ORDER BY private'),
        isFalse,
      );
      expect(
        _sqlPredicate.hasMatch('WHERE private IN :privateStatuses'),
        isTrue,
      );
      expect(
        _sqlPredicate.hasMatch(
          'AND COALESCE(j.private, FALSE) IN (FALSE, pf.visible)',
        ),
        isTrue,
      );
      expect(_readsJournalApi.hasMatch('_db.select(_db.journal)'), isTrue);
      expect(_readsJournalApi.hasMatch('select(journalFts)'), isFalse);
    });
  });
}
