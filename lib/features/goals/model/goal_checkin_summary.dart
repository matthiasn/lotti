import 'package:flutter/foundation.dart';

/// The compacted form of one check-in — what the agent sees instead of a raw
/// transcript.
///
/// Structured rather than free prose, because the slots are what later layers
/// and surfaces actually need: [committedTo] is the one the whole feature
/// exists for, since it is what the next check-in and the next banner are
/// measured against.
///
/// Capped at roughly 500 tokens. A daily check-in is ~150 words; feeding raw
/// transcripts into every wake would cost ~100k tokens a year against a goal
/// wake budgeted at 8k (ADR 0057).
@immutable
class GoalCheckInSummary {
  const GoalCheckInSummary({
    required this.id,
    required this.sourceEntryId,
    required this.recordedAt,
    required this.whatHappened,
    this.committedTo,
    this.blockers,
    this.mood,
    this.asks,
    this.sourceDigest,
  });

  final String id;

  /// The journal entry this was distilled from. Keeps the summary traceable
  /// back to the user's own words, which are never deleted.
  final String sourceEntryId;

  /// When the user recorded it — not when it was summarised. The agent quotes
  /// dates back ("you said on Tuesday"), so this has to be the moment that
  /// actually happened.
  final DateTime recordedAt;

  final String whatHappened;

  /// What the user said they would do. The slot the coaching turns on.
  final String? committedTo;

  final String? blockers;
  final String? mood;

  /// Anything the user asked of the agent.
  final String? asks;

  /// Fingerprint of the words this was distilled from.
  ///
  /// A transcript is not final when it first lands: it can be re-transcribed
  /// with a better model, or the user can edit it. Without this the first
  /// summary stood forever and the agent coached from words that had since
  /// changed. Null on summaries written before the field existed, which are
  /// recompacted once and then carry it.
  final String? sourceDigest;

  Map<String, Object?> toContent() => <String, Object?>{
    'sourceEntryId': sourceEntryId,
    'recordedAt': recordedAt.toIso8601String(),
    'whatHappened': whatHappened,
    'committedTo': committedTo,
    'blockers': blockers,
    'mood': mood,
    'asks': asks,
    'sourceDigest': sourceDigest,
  };

  static GoalCheckInSummary? fromContent(
    String id,
    Map<String, Object?> content,
  ) {
    final source = content['sourceEntryId'];
    final happened = content['whatHappened'];
    final recordedAt = DateTime.tryParse(
      content['recordedAt'] as String? ?? '',
    );
    if (source is! String || happened is! String || recordedAt == null) {
      return null;
    }
    return GoalCheckInSummary(
      id: id,
      sourceEntryId: source,
      recordedAt: recordedAt,
      whatHappened: happened,
      committedTo: _slot(content['committedTo']),
      blockers: _slot(content['blockers']),
      mood: _slot(content['mood']),
      asks: _slot(content['asks']),
      sourceDigest: _slot(content['sourceDigest']),
    );
  }
}

/// Reads an optional slot, tolerating a value that is not a string.
///
/// These arrive over sync from a peer that may be running a different build. A
/// direct cast threw on one malformed field, and because the workflow reads
/// every summary in one pass that single bad value cost the wake ALL of its
/// user voice — and abandoned pending compaction with it. A slot that cannot
/// be read is simply absent.
String? _slot(Object? value) => value is String ? value : null;
