import 'dart:math' as math;

import 'package:meta/meta.dart';

/// How a segment of the diff should render. Maps 1:1 to the
/// `tokens.colors.diff.*` token group at the widget layer; this file
/// stays widget-free so the unit tests can run pure-Dart.
enum TitleDiffKind {
  /// Token present in both versions, plain styling.
  common,

  /// Token present only on the local side. Rendered on the local card
  /// with the `added` tone; not present on the remote card.
  added,

  /// Token present in local but missing from remote. Rendered only on
  /// the remote card with `removed` tone (line-through) so the user
  /// sees what the remote side dropped.
  removed,

  /// Token present only on the remote side. Rendered on the remote
  /// card with the `replaced` tone; not present on the local card.
  replaced,
}

/// One contiguous run of tokens with the same diff kind. Adjacent
/// tokens of the same kind are merged so the renderer emits one span
/// instead of one per word.
@immutable
class TitleDiffSegment {
  const TitleDiffSegment({required this.text, required this.kind});

  final String text;
  final TitleDiffKind kind;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TitleDiffSegment && other.text == text && other.kind == kind;

  @override
  int get hashCode => Object.hash(text, kind);

  @override
  String toString() => 'TitleDiffSegment(${kind.name}: "$text")';
}

/// The two-sided diff output. Each side carries its own ordered list of
/// segments — a `common` segment in `local` corresponds to the matching
/// `common` segment in `remote` at the same logical position.
class TitleDiff {
  const TitleDiff({required this.local, required this.remote});

  final List<TitleDiffSegment> local;
  final List<TitleDiffSegment> remote;

  /// Both sides reduce to a single `common` segment with identical
  /// text. When this is true the auto-resolve path can short-circuit
  /// and the picker UI does not need to render at all.
  bool get isIdentical {
    if (local.length != 1 || remote.length != 1) return false;
    if (local.first.kind != TitleDiffKind.common) return false;
    if (remote.first.kind != TitleDiffKind.common) return false;
    return local.first.text == remote.first.text;
  }
}

/// Word-level LCS diff between two title strings. Tokenization splits
/// on whitespace; inter-token spacing is restored at render time as a
/// single space, which is what the picker title widgets want anyway
/// (titles are single-line and we render them with `Wrap`).
TitleDiff computeTitleDiff(String localTitle, String remoteTitle) {
  final localTokens = _tokenize(localTitle);
  final remoteTokens = _tokenize(remoteTitle);
  final ops = _diffTokens(localTokens, remoteTokens);
  return TitleDiff(
    local: _mergeAdjacent(_buildLocal(ops)),
    remote: _mergeAdjacent(_buildRemote(ops)),
  );
}

List<String> _tokenize(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return const <String>[];
  return trimmed.split(RegExp(r'\s+'));
}

enum _OpKind { equal, deleted, inserted }

class _Op {
  const _Op(this.kind, this.token);
  final _OpKind kind;
  final String token;
}

/// Standard LCS backtrack that produces a forward edit script:
/// `equal` for tokens common to both, `deleted` for tokens only in
/// local, `inserted` for tokens only in remote.
List<_Op> _diffTokens(List<String> a, List<String> b) {
  final m = a.length;
  final n = b.length;
  final dp = List<List<int>>.generate(
    m + 1,
    (_) => List<int>.filled(n + 1, 0),
  );
  for (var i = 1; i <= m; i++) {
    for (var j = 1; j <= n; j++) {
      if (a[i - 1] == b[j - 1]) {
        dp[i][j] = dp[i - 1][j - 1] + 1;
      } else {
        dp[i][j] = math.max(dp[i - 1][j], dp[i][j - 1]);
      }
    }
  }
  final ops = <_Op>[];
  var i = m;
  var j = n;
  while (i > 0 || j > 0) {
    if (i > 0 && j > 0 && a[i - 1] == b[j - 1]) {
      ops.add(_Op(_OpKind.equal, a[i - 1]));
      i--;
      j--;
    } else if (j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j])) {
      ops.add(_Op(_OpKind.inserted, b[j - 1]));
      j--;
    } else {
      ops.add(_Op(_OpKind.deleted, a[i - 1]));
      i--;
    }
  }
  return ops.reversed.toList();
}

/// Local card sees common + added (local-only) tokens; never the
/// remote-only insertions. Empty-string segments are filtered so a
/// trailing space doesn't produce a blank token.
List<TitleDiffSegment> _buildLocal(List<_Op> ops) {
  final out = <TitleDiffSegment>[];
  for (final op in ops) {
    switch (op.kind) {
      case _OpKind.equal:
        out.add(
          TitleDiffSegment(text: op.token, kind: TitleDiffKind.common),
        );
      case _OpKind.deleted:
        out.add(TitleDiffSegment(text: op.token, kind: TitleDiffKind.added));
      case _OpKind.inserted:
        // Remote-only — never shown on the local card.
        break;
    }
  }
  return out;
}

/// Remote card sees common tokens, plus what the remote dropped (rendered
/// `removed`/struck-through) and what it introduced (`replaced`).
List<TitleDiffSegment> _buildRemote(List<_Op> ops) {
  final out = <TitleDiffSegment>[];
  for (final op in ops) {
    switch (op.kind) {
      case _OpKind.equal:
        out.add(
          TitleDiffSegment(text: op.token, kind: TitleDiffKind.common),
        );
      case _OpKind.deleted:
        out.add(
          TitleDiffSegment(text: op.token, kind: TitleDiffKind.removed),
        );
      case _OpKind.inserted:
        out.add(
          TitleDiffSegment(text: op.token, kind: TitleDiffKind.replaced),
        );
    }
  }
  return out;
}

/// Collapse runs of same-kind segments into one segment per run. The
/// renderer styles per segment, so merging avoids paint-time span
/// fragmentation and keeps line-break behavior natural.
List<TitleDiffSegment> _mergeAdjacent(List<TitleDiffSegment> segments) {
  if (segments.isEmpty) return segments;
  final out = <TitleDiffSegment>[];
  var current = segments.first;
  for (var i = 1; i < segments.length; i++) {
    final next = segments[i];
    if (next.kind == current.kind) {
      current = TitleDiffSegment(
        text: '${current.text} ${next.text}',
        kind: current.kind,
      );
    } else {
      out.add(current);
      current = next;
    }
  }
  out.add(current);
  return out;
}
