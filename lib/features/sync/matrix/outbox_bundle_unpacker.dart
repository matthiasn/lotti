import 'dart:async';
import 'dart:io';

import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/matrix.dart';

/// Carrier for a fully-resolved [SyncOutboxBundle]: each child has been
/// recursively run through the parent processor's prepare phase so apply
/// can reuse the existing per-type pipeline by iterating [children].
class PreparedOutboxSyncBundle {
  PreparedOutboxSyncBundle({required this.children});

  final List<PreparedSyncEvent> children;
}

/// One reconstructed child of a [SyncOutboxBundle]: the typed envelope
/// paired with the raw JSON it was decoded from. The raw side preserves
/// wire-level field presence that is lost when older payloads are
/// deserialized with new nullable fields; carrying the pair as one value
/// makes it impossible to attach one child's presence data to another.
class OutboxBundleChildEnvelope {
  OutboxBundleChildEnvelope({
    required this.syncMessage,
    required this.rawJson,
  });

  final SyncMessage syncMessage;

  /// Raw wire envelope for [syncMessage]. Null only when the defensive
  /// fallback fired — the source carried no usable JSON for this child.
  final Map<String, dynamic>? rawJson;
}

/// A resolved sidecar manifest: every child envelope paired with its raw
/// JSON, plus the manifest's own [jsonPath].
class ResolvedOutboxSyncBundle {
  ResolvedOutboxSyncBundle({
    required this.children,
    required this.jsonPath,
  });

  final List<OutboxBundleChildEnvelope> children;
  final String? jsonPath;

  /// The reconstructed wire envelope, derived from [children] so the typed
  /// list can never drift out of step with the raw envelopes.
  SyncOutboxBundle get bundle => SyncOutboxBundle(
    children: [for (final child in children) child.syncMessage],
    jsonPath: jsonPath,
  );
}

/// Resolves the bundle's manifest payload (when [jsonPath] points at one)
/// and returns the rehydrated children, each typed envelope paired with its
/// raw JSON.
///
/// The resolver is responsible for any side effects required so the per-
/// child prepare path can run unchanged — most importantly, materializing
/// each `SyncJournalEntity` child's JSON to its on-disk cache before
/// dispatch. The unpacker itself is filesystem-agnostic.
typedef OutboxBundleSidecarResolver =
    Future<ResolvedOutboxSyncBundle?> Function({
      required String? jsonPath,
      String? attachmentEventId,
    });

/// Runs the parent processor's per-type prepare on a single child of an
/// outbox bundle. Returns the resolved [PreparedSyncEvent] for that child.
typedef OutboxBundleChildPreparer =
    Future<PreparedSyncEvent> Function(
      Event event,
      SyncMessage syncMessage,
      Map<String, dynamic>? rawMessageJson,
    );

/// Runs the parent processor's per-type apply on a single child.
typedef OutboxBundleChildApplier =
    Future<void> Function(PreparedSyncEvent prepared);

/// Trace hook reused from the parent processor so unpacker logs land in
/// the same `processor.*` subdomain stream.
typedef OutboxBundleTrace = void Function(String message, {String? subDomain});

/// Receiver-side unpacker for [SyncOutboxBundle]: pure prepare/apply logic
/// extracted from `SyncEventProcessor` so it can be unit-tested in isolation
/// without dragging in the entire processor harness.
///
/// The class is intentionally stateless aside from a logging seam — every
/// per-child interaction with the host processor flows through the
/// callbacks passed to [prepare] and [apply].
class OutboxBundleUnpacker {
  OutboxBundleUnpacker({
    required this.loggingService,
    required this.trace,
  });

  final DomainLogger loggingService;
  final OutboxBundleTrace trace;

  /// Reconstructs the children of [msg] (downloading the sidecar attachment
  /// when the inline list was stripped at send time) and recursively prepares
  /// each child via [prepareChild]. [rawChildren] retains field-presence data
  /// for inline children — it is the JSON list `msg.children` was decoded
  /// from, so the two are paired by position here, once, and travel together
  /// as [OutboxBundleChildEnvelope]s from then on; sidecar resolution
  /// supplies its children already paired. Returns null when the bundle's
  /// payload is unresolvable — callers should treat this as a terminal skip.
  ///
  /// Per-child fault isolation:
  /// - Any [IOException] (including [FileSystemException], [SocketException],
  ///   [HttpException], [TlsException], [WebSocketException]) is rethrown so
  ///   the pipeline can retry the whole bundle later — partial application
  ///   would leave gaps in the sequence log.
  /// - All other exceptions on a single child are logged and the child is
  ///   skipped; the remaining children still apply.
  Future<PreparedOutboxSyncBundle?> prepare({
    required Event event,
    required SyncOutboxBundle msg,
    required OutboxBundleSidecarResolver resolveSidecar,
    required OutboxBundleChildPreparer prepareChild,
    List<Map<String, dynamic>?> rawChildren = const [],
  }) async {
    final List<OutboxBundleChildEnvelope> children;
    if (msg.children.isEmpty) {
      final resolved = await resolveSidecar(
        jsonPath: msg.jsonPath,
        attachmentEventId: msg.attachmentEventId,
      );
      if (resolved == null) return null;
      children = resolved.children;
    } else {
      children = [
        for (var index = 0; index < msg.children.length; index++)
          OutboxBundleChildEnvelope(
            syncMessage: msg.children[index],
            rawJson: index < rawChildren.length ? rawChildren[index] : null,
          ),
      ];
    }

    final prepared = <PreparedSyncEvent>[];
    for (final child in children) {
      final syncMessage = child.syncMessage;
      // Defensive: guard against a malformed payload where a bundle is
      // nested inside another bundle. The sender enforces this invariant
      // at construction time, so reaching this branch means the wire
      // payload was tampered with or generated by a buggy older client.
      if (syncMessage is SyncOutboxBundle) {
        trace(
          'outboxBundle.child.skip nested bundles are not supported',
          subDomain: 'processor.resolve.outboxBundle',
        );
        continue;
      }
      try {
        final childPrepared = await prepareChild(
          event,
          syncMessage,
          child.rawJson,
        );
        prepared.add(childPrepared);
      } on IOException {
        // Catches FileSystemException, SocketException, HttpException,
        // TlsException, WebSocketException — every retriable I/O surface
        // that the parent pipeline already knows how to back off on.
        rethrow;
      } catch (error, stackTrace) {
        loggingService.error(
          LogDomain.sync,
          error,
          stackTrace: stackTrace,
          subDomain: 'processor.resolve.outboxBundle.child',
        );
      }
    }

    return PreparedOutboxSyncBundle(children: prepared);
  }

  /// Iterates the bundle's children and dispatches each through [applyChild]
  /// in order.
  ///
  /// Per-child fault isolation mirrors [prepare]:
  /// - Any [IOException] is rethrown so the parent pipeline can retry the
  ///   whole bundle. Already-applied children are idempotent under
  ///   vector-clock dedup, so a redelivery is safe.
  /// - All other exceptions on a single child are logged and skipped; the
  ///   bundle's net effect is the union of successfully-applied children.
  Future<void> apply({
    required PreparedOutboxSyncBundle bundle,
    required OutboxBundleChildApplier applyChild,
  }) async {
    for (final child in bundle.children) {
      try {
        await applyChild(child);
      } on IOException {
        // Retriable: bubble up so the pipeline schedules a retry. Earlier
        // applied children stay applied; the receiver's per-type apply
        // path is idempotent on (id, vectorClock).
        rethrow;
      } catch (error, stackTrace) {
        loggingService.error(
          LogDomain.sync,
          error,
          stackTrace: stackTrace,
          subDomain: 'processor.apply.outboxBundle.child',
        );
      }
    }
  }
}
