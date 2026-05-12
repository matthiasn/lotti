part of 'sync_event_processor.dart';

/// Resolves [SyncOutboxBundle] manifest payloads into the per-child
/// envelopes consumed by the prepare-phase dispatcher.
extension _OutboxBundleHandler on SyncEventProcessor {
  /// Resolves a [SyncOutboxBundle]'s manifest payload, materializes each
  /// child's `JournalEntity` JSON to the cache on disk, and returns the
  /// reconstructed bundle for the unpacker to walk through prepareChild.
  ///
  /// The manifest is the single artifact on the wire: it carries every
  /// child's envelope plus, for `SyncJournalEntity`, the full entity body
  /// (the database is the system of record on both ends, so the receiver
  /// does not also need a per-child file event). Inline-payload families
  /// (`SyncEntryLink`, `SyncAiConfig`, `SyncAiConfigDelete`,
  /// `SyncEntityDefinition`, `SyncThemingSelection`, `SyncBackfillRequest`,
  /// `SyncBackfillResponse`) ship their data inside the freezed envelope
  /// and need no separate `payload` field. Agent envelopes
  /// (`SyncAgentEntity`, `SyncAgentLink`) likewise carry their data inline.
  ///
  /// Vector-clock dominance is checked against the database in **one** bulk
  /// query (no N+1) before any disk write: when the local copy already
  /// covers the incoming envelope's clock, the on-disk JSON cache is left
  /// untouched so the apply pipeline reads the canonical local entity
  /// instead of an older bundled payload. The envelope is still surfaced to
  /// the unpacker so duplicate detection and sequence-log accounting run as
  /// they do for individually-delivered entities.
  Future<SyncOutboxBundle?> _resolveOutboxBundleManifest(
    String? jsonPath,
  ) async {
    // Phase-by-phase timing so a single grep on
    // `processor.resolve.outboxBundle.timing` answers "where is the time
    // going" without guesswork. Numbers in milliseconds, comparable
    // across runs and across hosts. Captured into one log line per
    // bundle so the typical observation is one row per drain — easy to
    // tail or pull into a spreadsheet.
    final totalSw = Stopwatch()..start();
    var fetchMs = 0;
    var diskFallbackMs = 0;
    var decodeMs = 0;
    var dbLookupMs = 0;
    var writeMs = 0;
    var manifestBytes = 0;
    var entryCount = 0;
    var writeCount = 0;
    var fromDescriptor = false;

    final jp = jsonPath;
    if (jp == null) {
      _trace(
        'outboxBundle.skipped no jsonPath',
        subDomain: 'processor.resolve.outboxBundle',
      );
      return null;
    }

    final File targetFile;
    try {
      targetFile = resolveJsonCandidateFile(jp);
    } on FileSystemException catch (e, st) {
      _loggingService.captureException(
        e,
        domain: 'MATRIX_SERVICE',
        subDomain: 'processor.resolve.outboxBundle.invalidPath',
        stackTrace: st,
      );
      return null;
    }

    // Reuse the existing descriptor pipeline: the encoding header on the
    // upload tells `decodeAttachmentBytes` to gunzip the manifest bytes
    // transparently, so what comes back is the plain manifest JSON string.
    String? manifestJson;
    final fetchSw = Stopwatch()..start();
    manifestJson = await _fetchFromDescriptor(
      jsonPath: jp,
      targetFile: targetFile,
      typeName: 'outboxBundle',
    );
    fetchMs = fetchSw.elapsedMilliseconds;
    fromDescriptor = manifestJson != null;

    if (manifestJson == null) {
      // Fall back to disk if the descriptor is not yet registered (text
      // event arrived before the file event made it through catch-up).
      final diskSw = Stopwatch()..start();
      try {
        manifestJson = await targetFile.readAsString();
      } on FileSystemException {
        rethrow;
      } catch (e, st) {
        _loggingService.captureException(
          e,
          domain: 'MATRIX_SERVICE',
          subDomain: 'processor.resolve.outboxBundle.diskRead',
          stackTrace: st,
        );
        return null;
      }
      diskFallbackMs = diskSw.elapsedMilliseconds;
    }
    manifestBytes = manifestJson.length;

    final Map<String, dynamic> manifest;
    final decodeSw = Stopwatch()..start();
    try {
      // Offload large manifests to a worker isolate; small ones (test
      // fixtures, near-empty bundles) parse inline so the threshold-aware
      // helper saves the isolate spin-up cost when the saved time is
      // smaller than the round-trip overhead.
      final decoded = await decodeJsonStringMaybeIsolate(manifestJson);
      manifest = decoded! as Map<String, dynamic>;
    } catch (e, st) {
      _loggingService.captureException(
        e,
        domain: 'MATRIX_SERVICE',
        subDomain: 'processor.resolve.outboxBundle.parse',
        stackTrace: st,
      );
      return null;
    }
    decodeMs = decodeSw.elapsedMilliseconds;

    final version = manifest['version'];
    if (version != SyncTuning.outboxBundleManifestVersion) {
      _loggingService.captureException(
        'outboxBundle manifest version=$version unsupported '
        '(expected ${SyncTuning.outboxBundleManifestVersion}) — skipping',
        domain: 'MATRIX_SERVICE',
        subDomain: 'processor.resolve.outboxBundle.unknownVersion',
      );
      return null;
    }

    final rawEntries = manifest['entries'];
    if (rawEntries is! List) {
      _loggingService.captureException(
        'outboxBundle manifest missing entries array',
        domain: 'MATRIX_SERVICE',
        subDomain: 'processor.resolve.outboxBundle.malformed',
      );
      return null;
    }

    // First pass: parse envelopes and collect every SyncJournalEntity id we
    // will need a local copy of, so the bulk DB fetch below stays a single
    // round-trip even at the [SyncTuning.outboxBundleMaxSize] cap.
    final parsedEntries = <_OutboxBundleManifestEntry>[];
    final journalEntityIds = <String>{};
    for (final raw in rawEntries) {
      if (raw is! Map<String, dynamic>) continue;
      final envelopeJson = raw['envelope'];
      if (envelopeJson is! Map<String, dynamic>) continue;
      final SyncMessage envelope;
      try {
        envelope = SyncMessage.fromJson(envelopeJson);
      } catch (e, st) {
        _loggingService.captureException(
          e,
          domain: 'MATRIX_SERVICE',
          subDomain: 'processor.resolve.outboxBundle.envelopeParse',
          stackTrace: st,
        );
        continue;
      }
      if (envelope is SyncOutboxBundle) {
        // Defence in depth: nested bundles are rejected by the unpacker
        // too, but skipping here saves work and avoids a bogus DB lookup.
        _trace(
          'outboxBundle.entry.skipNested',
          subDomain: 'processor.resolve.outboxBundle',
        );
        continue;
      }
      parsedEntries.add(
        _OutboxBundleManifestEntry(envelope: envelope, payload: raw['payload']),
      );
      if (envelope is SyncJournalEntity) {
        journalEntityIds.add(envelope.id);
      }
    }

    entryCount = parsedEntries.length;

    // VC-dominance check uses the database as system of record. If no
    // JournalDb was injected (legacy test harness), the dominance check is
    // skipped and the incoming JSON is always written — safe but loses the
    // "don't clobber a fresher local cache" optimization.
    final db = _journalDb;
    final dbSw = Stopwatch()..start();
    final localEntities = journalEntityIds.isEmpty || db == null
        ? const <String, JournalEntity>{}
        : await db.journalEntityMapForIds(journalEntityIds);
    dbLookupMs = dbSw.elapsedMilliseconds;

    // Plan every disk write before issuing any of them so we can fail the
    // whole bundle on a malformed manifest (e.g. a SyncJournalEntity with
    // no `payload`) without leaving half the entries on disk. Per-write
    // FileSystemExceptions are surfaced via the rethrow below so the
    // unpacker's IOException-rethrow path triggers a whole-bundle retry —
    // already-applied writes stay (idempotent under VC dominance on the
    // next pass).
    final writePlans = <_OutboxBundleWritePlan>[];
    final children = <SyncMessage>[];
    for (final parsed in parsedEntries) {
      final envelope = parsed.envelope;
      final payload = parsed.payload;

      if (envelope is SyncJournalEntity) {
        final local = localEntities[envelope.id];
        final localVc = local?.meta.vectorClock;
        final incomingVc = envelope.vectorClock;
        var localDominates = false;
        if (local != null && localVc != null && incomingVc != null) {
          final cmp = VectorClock.compare(localVc, incomingVc);
          localDominates =
              cmp == VclockStatus.a_gt_b || cmp == VclockStatus.equal;
        }

        final Map<String, dynamic> payloadToWrite;
        if (localDominates) {
          // Refresh the on-disk cache from the canonical DB version. The
          // cache file may be stale or missing — writing the dominant
          // local entity back guarantees the apply pipeline's
          // SmartJournalEntityLoader reads the right data instead of
          // serving a stale fixture or hitting a descriptor miss.
          // `local` is non-null here because `localDominates` requires it.
          payloadToWrite = local!.toJson();
          _trace(
            'outboxBundle.entry.localDominates id=${envelope.id} '
            'jsonPath=${envelope.jsonPath}',
            subDomain: 'processor.resolve.outboxBundle',
          );
        } else {
          if (payload is! Map<String, dynamic>) {
            // Malformed manifest: a SyncJournalEntity envelope without an
            // inline payload cannot be applied. Skipping this child would
            // ack the bundle while the entity never reaches the local DB
            // (silent loss). Drop the whole bundle instead — peers can
            // recover the entry via the sequence-log backfill path.
            _loggingService.captureException(
              'outboxBundle entry missing payload for SyncJournalEntity '
              'id=${envelope.id} jsonPath=${envelope.jsonPath} — '
              'dropping the whole bundle so missing entries surface via '
              'the sequence-log backfill path instead of being lost',
              domain: 'MATRIX_SERVICE',
              subDomain: 'processor.resolve.outboxBundle.missingPayload',
            );
            return null;
          }
          payloadToWrite = payload;
        }

        final File entityFile;
        try {
          entityFile = resolveJsonCandidateFile(envelope.jsonPath);
        } on FileSystemException catch (e, st) {
          _loggingService.captureException(
            e,
            domain: 'MATRIX_SERVICE',
            subDomain: 'processor.resolve.outboxBundle.invalidEntryPath',
            stackTrace: st,
          );
          return null;
        }

        writePlans.add(
          _OutboxBundleWritePlan(
            envelopeId: envelope.id,
            jsonPath: envelope.jsonPath,
            filePath: entityFile.path,
            payload: payloadToWrite,
          ),
        );
      }

      children.add(envelope);
    }

    // Issue per-child writes serially. The earlier parallel `Future.wait`
    // multiplied the prepare phase's per-batch fan-out by up to
    // [outboxBundleMaxSize], which on phone filesystems made the inbound
    // worker stall under heavy backfill — too many concurrent atomic
    // writes (each one is parent-create + temp + rename) ran into FD caps
    // and journal backpressure, and the resulting FileSystemException
    // pushed the bundle straight back into a tight retry loop with no
    // forward progress. Sequential writes within a bundle keep the worst-
    // case write fan-out bounded by the queue's batch concurrency
    // (`SyncTuning.queueBatchSize`) rather than batch × per-bundle.
    final writeSw = Stopwatch()..start();
    for (final plan in writePlans) {
      await saveJson(plan.filePath, json.encode(plan.payload));
      _trace(
        'outboxBundle.entry.materialized id=${plan.envelopeId} '
        'jsonPath=${plan.jsonPath}',
        subDomain: 'processor.resolve.outboxBundle',
      );
    }
    writeMs = writeSw.elapsedMilliseconds;
    writeCount = writePlans.length;

    _trace(
      'totalMs=${totalSw.elapsedMilliseconds} '
      'fetchMs=$fetchMs '
      'fromDescriptor=$fromDescriptor '
      'diskFallbackMs=$diskFallbackMs '
      'manifestBytes=$manifestBytes '
      'decodeMs=$decodeMs '
      'entries=$entryCount '
      'dbLookupMs=$dbLookupMs '
      'dbHits=${localEntities.length}/${journalEntityIds.length} '
      'writeMs=$writeMs '
      'writes=$writeCount',
      subDomain: 'processor.resolve.outboxBundle.timing',
    );

    return SyncOutboxBundle(
      children: children,
      jsonPath: jp,
    );
  }
}

/// One parsed entry from a [SyncOutboxBundle]'s manifest: the deserialized
/// envelope plus its inline payload (only present for [SyncJournalEntity]
/// children — agent and inline-only families carry their data inside the
/// envelope itself).
class _OutboxBundleManifestEntry {
  _OutboxBundleManifestEntry({required this.envelope, required this.payload});

  final SyncMessage envelope;
  final Object? payload;
}

/// One pending on-disk JSON cache write planned by the outbox bundle
/// resolver. The resolver builds a list of plans up-front (rejecting the
/// whole bundle on malformed entries) and dispatches them via
/// `Future.wait` so 50 atomic writes overlap instead of running serially.
class _OutboxBundleWritePlan {
  _OutboxBundleWritePlan({
    required this.envelopeId,
    required this.jsonPath,
    required this.filePath,
    required this.payload,
  });

  final String envelopeId;
  final String jsonPath;
  final String filePath;
  final Map<String, dynamic> payload;
}
