import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflict_detail_shared.dart';
import 'package:lotti/features/sync/ui/widgets/conflicts/title_diff.dart';
import 'package:meta/meta.dart';

/// Stable identity of a comparable field on a [JournalEntity]. The widget
/// layer maps each value to a localized label; this file stays free of
/// l10n so the diff can be unit-tested as pure logic.
///
/// [EntryField.other] is a catch-all: it is emitted when the entities differ
/// in a field that is not individually modelled here (e.g. a task's status,
/// a measurement's value). It guarantees the diff never silently hides a
/// change — the resolution UI can always tell the user "there is more here".
enum EntryField {
  title,
  body,
  category,
  dateFrom,
  dateTo,
  starred,
  private,
  flag,
  audioDuration,
  other,
}

/// Whether a differing field is present on both sides (and changed), or
/// only on one side (added on one, absent on the other).
enum FieldDiffKind {
  /// Present on both sides with different values.
  changed,

  /// Present on the local side only (remote is null/empty).
  onlyLocal,

  /// Present on the remote side only (local is null/empty).
  onlyRemote,
}

/// The overall relationship between the two conflicting versions. Drives
/// which resolution affordance the UI shows: a normal field picker for
/// [edited], a safe binary for the delete-vs-edit cases, etc.
enum ConflictShape {
  /// No user-meaningful field differs. The picker can auto-resolve.
  identical,

  /// Both sides are live and at least one field differs.
  edited,

  /// The local side was soft-deleted while the remote side was edited.
  deletedOnLocal,

  /// The remote side was soft-deleted while the local side was edited.
  deletedOnRemote,

  /// The two versions are different entity types (should be rare; same id
  /// reused for a different kind). Surfaced as a binary choice.
  typeChanged,
}

/// A single field that differs between the two versions.
@immutable
class FieldDiff {
  const FieldDiff({
    required this.field,
    required this.kind,
    this.localValue,
    this.remoteValue,
    this.wordDiff,
  });

  final EntryField field;
  final FieldDiffKind kind;

  /// Canonical/display string for the local side (`null` when absent). For
  /// free-text fields this is the raw text and [wordDiff] carries the
  /// token-level highlighting; for enum/scalar fields the UI may localize it.
  final String? localValue;
  final String? remoteValue;

  /// Word-level diff, present only for text fields ([EntryField.title],
  /// [EntryField.body]) when both sides are present and differ.
  final TitleDiff? wordDiff;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FieldDiff &&
          other.field == field &&
          other.kind == kind &&
          other.localValue == localValue &&
          other.remoteValue == remoteValue &&
          _wordDiffEquals(other.wordDiff, wordDiff);

  @override
  int get hashCode => Object.hash(field, kind, localValue, remoteValue);

  @override
  String toString() =>
      'FieldDiff(${field.name}, ${kind.name}, local: $localValue, '
      'remote: $remoteValue)';
}

/// The full result of comparing two conflicting versions of an entry.
@immutable
class EntryDiff {
  const EntryDiff({
    required this.shape,
    required this.fields,
    required this.identicalFieldCount,
  });

  final ConflictShape shape;

  /// Differing fields in stable display order ([EntryField.other] last).
  final List<FieldDiff> fields;

  /// How many modelled fields are present and equal on both sides. Powers
  /// the "N fields identical" affordance that lets the user collapse the
  /// noise and focus on what actually diverged.
  final int identicalFieldCount;

  bool get isIdentical => shape == ConflictShape.identical;

  /// True when the entities differ in a field not individually modelled.
  bool get hasOtherDifferences =>
      fields.any((f) => f.field == EntryField.other);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EntryDiff &&
          other.shape == shape &&
          other.identicalFieldCount == identicalFieldCount &&
          const ListEquality<FieldDiff>().equals(other.fields, fields);

  @override
  int get hashCode =>
      Object.hash(shape, identicalFieldCount, Object.hashAll(fields));
}

/// Computes a field-by-field diff between two conflicting versions of the
/// same entry. The result is pure data; the resolution UI renders it.
///
/// Guarantees:
/// * Every modelled field that differs becomes a [FieldDiff].
/// * Any *unmodelled* difference (after stripping sync noise) surfaces as a
///   single [EntryField.other] entry, so a change can never be hidden.
/// * Soft-delete-vs-edit collisions are classified via [ConflictShape]
///   rather than as a confusing diff against a tombstone.
EntryDiff computeEntryDiff(JournalEntity local, JournalEntity remote) {
  if (local.runtimeType != remote.runtimeType) {
    return const EntryDiff(
      shape: ConflictShape.typeChanged,
      fields: <FieldDiff>[],
      identicalFieldCount: 0,
    );
  }

  final fields = <FieldDiff>[];
  var identical = 0;
  for (final spec in _specs) {
    final l = spec.extract(local);
    final r = spec.extract(remote);
    if (l == r) {
      if (_present(l) || _present(r)) identical++;
      continue;
    }
    fields.add(_buildFieldDiff(spec, l, r));
  }

  if (_hasOtherDifferences(local, remote)) {
    fields.add(
      const FieldDiff(field: EntryField.other, kind: FieldDiffKind.changed),
    );
  }

  return EntryDiff(
    shape: _shapeOf(local, remote, fields),
    fields: fields,
    identicalFieldCount: identical,
  );
}

ConflictShape _shapeOf(
  JournalEntity local,
  JournalEntity remote,
  List<FieldDiff> fields,
) {
  final localDeleted = local.meta.deletedAt != null;
  final remoteDeleted = remote.meta.deletedAt != null;
  if (localDeleted != remoteDeleted) {
    return localDeleted
        ? ConflictShape.deletedOnLocal
        : ConflictShape.deletedOnRemote;
  }
  return fields.isEmpty ? ConflictShape.identical : ConflictShape.edited;
}

FieldDiff _buildFieldDiff(_FieldSpec spec, String? l, String? r) {
  final kind = !_present(l)
      ? FieldDiffKind.onlyRemote
      : !_present(r)
      ? FieldDiffKind.onlyLocal
      : FieldDiffKind.changed;
  final wordDiff = spec.isText && kind == FieldDiffKind.changed
      ? computeTitleDiff(l!, r!)
      : null;
  return FieldDiff(
    field: spec.field,
    kind: kind,
    localValue: l,
    remoteValue: r,
    wordDiff: wordDiff,
  );
}

bool _present(String? value) => value != null && value.isNotEmpty;

bool _wordDiffEquals(TitleDiff? a, TitleDiff? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  const eq = ListEquality<TitleDiffSegment>();
  return eq.equals(a.local, b.local) && eq.equals(a.remote, b.remote);
}

// --- Field registry --------------------------------------------------------

class _FieldSpec {
  const _FieldSpec(this.field, this.extract, {this.isText = false});

  final EntryField field;
  final String? Function(JournalEntity) extract;
  final bool isText;
}

final List<_FieldSpec> _specs = <_FieldSpec>[
  const _FieldSpec(EntryField.title, _titleOf, isText: true),
  const _FieldSpec(EntryField.body, _bodyOf, isText: true),
  _FieldSpec(EntryField.category, (e) => e.meta.categoryId),
  _FieldSpec(EntryField.dateFrom, (e) => e.meta.dateFrom.toIso8601String()),
  _FieldSpec(EntryField.dateTo, (e) => e.meta.dateTo.toIso8601String()),
  _FieldSpec(EntryField.starred, (e) => e.meta.starred?.toString()),
  _FieldSpec(EntryField.private, (e) => e.meta.private?.toString()),
  _FieldSpec(EntryField.flag, (e) => e.meta.flag?.name),
  _FieldSpec(EntryField.audioDuration, (e) {
    final d = audioDuration(e);
    return d == null ? null : formatDuration(d);
  }),
];

/// The headline title for entities that carry a structured title. Text
/// entities (journal entries, audio, images) have no separate title — their
/// first line lives in [EntryField.body], so this returns null for them and
/// the body diff carries the change.
String? _titleOf(JournalEntity e) => switch (e) {
  Task(:final data) => data.title,
  JournalEvent(:final data) => data.title,
  ProjectEntry(:final data) => data.title,
  Checklist(:final data) => data.title,
  ChecklistItem(:final data) => data.title,
  _ => null,
};

String? _bodyOf(JournalEntity e) {
  final text = e.entryText?.plainText;
  if (text == null || text.trim().isEmpty) return null;
  return text;
}

// --- Completeness guard ----------------------------------------------------

/// Paths removed before the catch-all comparison. The first group is pure
/// sync noise that always differs in a conflict; the rest are the fields the
/// registry above already reports individually, so they must not also trip
/// the generic "other differences" signal.
const Set<String> _coveredPaths = <String>{
  // Sync noise — never user-meaningful for a diff.
  'meta.vectorClock',
  'meta.updatedAt',
  // Delete-vs-edit is classified via ConflictShape, not as a field.
  'meta.deletedAt',
  // Modelled meta fields.
  'meta.categoryId',
  'meta.starred',
  'meta.private',
  'meta.flag',
  'meta.dateFrom',
  'meta.dateTo',
  // Body (and the text entities' title) live in entryText.
  'entryText',
  // Structured-title bearers + audio duration are modelled.
  'data.title',
  'data.duration',
};

/// True when the two entities differ in a field the registry does not model,
/// once sync noise and already-covered fields are stripped. This is the
/// safety net behind "never a blind choice": even an unmodelled field
/// change (task status, measurement value, …) is surfaced rather than lost.
bool _hasOtherDifferences(JournalEntity local, JournalEntity remote) {
  final l = _strip(local.toJson(), _coveredPaths);
  final r = _strip(remote.toJson(), _coveredPaths);
  return !const DeepCollectionEquality().equals(l, r);
}

Map<String, dynamic> _strip(Map<String, dynamic> json, Set<String> paths) {
  final copy = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
  for (final path in paths) {
    final dot = path.indexOf('.');
    if (dot < 0) {
      copy.remove(path);
    } else {
      final parent = copy[path.substring(0, dot)];
      if (parent is Map) parent.remove(path.substring(dot + 1));
    }
  }
  return copy;
}
