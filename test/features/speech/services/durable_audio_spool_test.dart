import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/speech/services/durable_audio_spool.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('durable_audio_spool_');
  });

  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  DurableAudioSpoolContext contextFor(String sessionId) {
    return DurableAudioSpoolContext(
      recordingSessionId: sessionId,
      activityEntryId: 'activity-$sessionId',
      dayId: 'day-2026-07-18',
      createdAt: DateTime.utc(2026, 7, 18, 7, 30),
      assetRootPath: path.join(root.path, 'assets'),
      metadata: const <String, String>{'intent': 'draft'},
    );
  }

  File destinationFor(String sessionId) =>
      File(path.join(root.path, 'assets', '$sessionId.wav'));

  void writeManifest(
    Directory directory,
    DurableAudioSpoolManifest manifest,
  ) {
    final payload = jsonEncode(manifest.toJson());
    File(
      path.join(
        directory.path,
        'manifest-${manifest.generation.toString().padLeft(8, '0')}.json',
      ),
    ).writeAsStringSync(
      jsonEncode(<String, Object?>{
        'payload': payload,
        'sha256': sha256.convert(utf8.encode(payload)).toString(),
      }),
      flush: true,
    );
  }

  test(
    'publishes identity manifest before accepting the first frame',
    () async {
      final spool = await DurableAudioSpool.start(
        rootDirectory: root,
        context: contextFor('session-initial'),
      );

      final files = spool.sessionDirectory.listSync();
      expect(files.map((file) => path.basename(file.path)), <String>[
        'manifest-00000001.json',
      ]);
      expect(spool.manifest.context.dayId, 'day-2026-07-18');
      expect(spool.manifest.context.metadata, const {'intent': 'draft'});
      expect(spool.manifest.acceptedPcmBytes, 0);
    },
  );

  test('acknowledges a frame only after its local bytes are flushed', () async {
    final spool = await DurableAudioSpool.start(
      rootDirectory: root,
      context: contextFor('session-write-before-send'),
      chunkBytes: 8,
    );
    final pcm = Uint8List.fromList(<int>[1, 2, 3, 4]);

    final result = await spool.append(pcm);

    expect(result, SpoolAppendResult.persisted);
    final active = File(
      path.join(spool.sessionDirectory.path, 'active-00000000.part'),
    );
    expect(active.readAsBytesSync(), pcm);
    expect(spool.manifest.acceptedPcmBytes, pcm.length);
    expect(spool.manifest.activeChunkBytes, pcm.length);
  });

  test('bounds queued PCM and rejects saturation without writing it', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    final spool = await DurableAudioSpool.start(
      rootDirectory: root,
      context: contextFor('session-saturation'),
      chunkBytes: 8,
      maxPendingBytes: 6,
      persistBarrier: () async {
        if (!entered.isCompleted) entered.complete();
        await release.future;
      },
    );
    final first = spool.append(Uint8List.fromList(<int>[1, 2, 3, 4]));
    await entered.future;

    final second = await spool.append(Uint8List.fromList(<int>[5, 6, 7, 8]));
    expect(second, SpoolAppendResult.saturated);
    release.complete();
    expect(await first, SpoolAppendResult.persisted);

    final finalized = await spool.finalize(
      destinationFile: destinationFor('session-saturation'),
    );
    expect(finalized.pcmBytes, 4);
    expect(File(finalized.wavPath).readAsBytesSync().sublist(44), <int>[
      1,
      2,
      3,
      4,
    ]);
  });

  test('splits chunks and finalizes a checksummed canonical WAV', () async {
    final spool = await DurableAudioSpool.start(
      rootDirectory: root,
      context: contextFor('session-finalize'),
      chunkBytes: 4,
    );
    final pcm = Uint8List.fromList(<int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);

    await spool.append(pcm);
    final result = await spool.finalize(
      destinationFile: destinationFor('session-finalize'),
    );

    expect(spool.manifest.chunks.map((chunk) => chunk.byteLength), <int>[
      4,
      4,
      2,
    ]);
    final wav = File(result.wavPath).readAsBytesSync();
    expect(wav, hasLength(44 + pcm.length));
    expect(wav.sublist(44), pcm);
    expect(result.wavSha256, sha256.convert(wav).toString());
    expect(result.duration, const Duration(microseconds: 312));
    expect(spool.manifest.state, DurableAudioSpoolState.published);
  });

  test('recovers bytes flushed after the newest surviving manifest', () async {
    final spool = await DurableAudioSpool.start(
      rootDirectory: root,
      context: contextFor('session-stale-manifest'),
      chunkBytes: 8,
    );
    await spool.append(Uint8List.fromList(<int>[1, 2]));
    await spool.append(Uint8List.fromList(<int>[3, 4]));
    final recovery = await DurableAudioSpool.recover(
      sessionDirectory: spool.sessionDirectory,
    );

    expect(recovery.isQuarantined, isFalse);
    expect(recovery.manifest.state, DurableAudioSpoolState.recoveryRequired);
    expect(recovery.manifest.acceptedPcmBytes, 4);
    final finalized = await recovery.spool!.finalize(
      destinationFile: destinationFor('session-stale-manifest'),
    );
    expect(File(finalized.wavPath).readAsBytesSync().sublist(44), <int>[
      1,
      2,
      3,
      4,
    ]);
  });

  test('trims an incomplete PCM sample during startup recovery', () async {
    final spool = await DurableAudioSpool.start(
      rootDirectory: root,
      context: contextFor('session-odd-sample'),
      chunkBytes: 8,
    );
    await spool.append(Uint8List.fromList(<int>[1, 2]));
    final active = File(
      path.join(spool.sessionDirectory.path, 'active-00000000.part'),
    )..writeAsBytesSync(<int>[3], mode: FileMode.append, flush: true);

    final recovery = await DurableAudioSpool.recover(
      sessionDirectory: spool.sessionDirectory,
    );

    expect(recovery.isQuarantined, isFalse);
    expect(active.existsSync(), isFalse);
    expect(
      File(
        path.join(spool.sessionDirectory.path, 'chunk-00000000.pcm'),
      ).readAsBytesSync(),
      <int>[1, 2],
    );
    expect(recovery.manifest.acceptedPcmBytes, 2);
  });

  test('quarantines a non-contiguous orphan PCM chunk', () async {
    final spool = await DurableAudioSpool.start(
      rootDirectory: root,
      context: contextFor('session-gap'),
      chunkBytes: 8,
    );
    File(
      path.join(spool.sessionDirectory.path, 'chunk-00000001.pcm'),
    ).writeAsBytesSync(<int>[1, 2], flush: true);

    final recovery = await DurableAudioSpool.recover(
      sessionDirectory: spool.sessionDirectory,
    );

    expect(recovery.isQuarantined, isTrue);
    expect(recovery.spool, isNull);
    expect(
      recovery.manifest.recoveryReason,
      DurableAudioRecoveryReason.chunkGap,
    );
  });

  test('falls back to the preceding checksummed manifest generation', () async {
    final spool = await DurableAudioSpool.start(
      rootDirectory: root,
      context: contextFor('session-corrupt-manifest'),
      chunkBytes: 8,
    );
    await spool.append(Uint8List.fromList(<int>[1, 2]));
    File(
      path.join(spool.sessionDirectory.path, 'manifest-00000002.json'),
    ).writeAsStringSync(jsonEncode(<String, Object?>{'corrupt': true}));

    final recovery = await DurableAudioSpool.recover(
      sessionDirectory: spool.sessionDirectory,
    );

    expect(recovery.isQuarantined, isFalse);
    expect(recovery.manifest.acceptedPcmBytes, 2);
  });

  test('freezes session metadata before the initial manifest', () async {
    final metadata = <String, String>{'intent': 'draft'};
    final context = DurableAudioSpoolContext(
      recordingSessionId: 'session-frozen-context',
      activityEntryId: 'activity-frozen-context',
      createdAt: DateTime.utc(2026, 7, 18, 7, 30),
      assetRootPath: path.join(root.path, 'assets'),
      metadata: metadata,
    );
    final spool = await DurableAudioSpool.start(
      rootDirectory: root,
      context: context,
    );

    metadata['intent'] = 'refine';

    expect(spool.manifest.context.metadata, const {'intent': 'draft'});
    expect(
      () => spool.manifest.context.metadata['intent'] = 'changed',
      throwsUnsupportedError,
    );
  });

  test('rejects incomplete PCM16 frames without acknowledging bytes', () async {
    final spool = await DurableAudioSpool.start(
      rootDirectory: root,
      context: contextFor('session-odd-live-frame'),
    );

    await expectLater(
      spool.append(Uint8List.fromList(<int>[1])),
      throwsArgumentError,
    );

    expect(spool.manifest.acceptedPcmBytes, 0);
    expect(
      spool.sessionDirectory.listSync().where(
        (entry) => path.basename(entry.path).startsWith('active-'),
      ),
      isEmpty,
    );
  });

  test(
    'returns a typed no-audio outcome instead of publishing an empty WAV',
    () async {
      final spool = await DurableAudioSpool.start(
        rootDirectory: root,
        context: contextFor('session-empty'),
      );

      await expectLater(
        spool.finalize(destinationFile: destinationFor('session-empty')),
        throwsA(isA<DurableAudioSpoolNoAudioException>()),
      );

      expect(destinationFor('session-empty').existsSync(), isFalse);
    },
  );

  test(
    'closes frame admission before waiting for an in-flight append',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final spool = await DurableAudioSpool.start(
        rootDirectory: root,
        context: contextFor('session-finalize-fence'),
        chunkBytes: 8,
        persistBarrier: () async {
          if (!entered.isCompleted) entered.complete();
          await release.future;
        },
      );
      final admitted = spool.append(Uint8List.fromList(<int>[1, 2, 3, 4]));
      await entered.future;

      final finalization = spool.finalize(
        destinationFile: destinationFor('session-finalize-fence'),
      );
      await expectLater(
        spool.append(Uint8List.fromList(<int>[5, 6])),
        throwsStateError,
      );
      release.complete();

      expect(await admitted, SpoolAppendResult.persisted);
      final result = await finalization;
      expect(File(result.wavPath).readAsBytesSync().sublist(44), <int>[
        1,
        2,
        3,
        4,
      ]);
    },
  );

  test(
    'shares duplicate finalization and rejects another destination',
    () async {
      final spool = await DurableAudioSpool.start(
        rootDirectory: root,
        context: contextFor('session-idempotent-finalize'),
      );
      await spool.append(Uint8List.fromList(<int>[1, 2]));
      final destination = destinationFor('session-idempotent-finalize');

      final first = spool.finalize(destinationFile: destination);
      final second = spool.finalize(destinationFile: destination);

      expect(identical(first, second), isTrue);
      await expectLater(
        spool.finalize(destinationFile: destinationFor('another-destination')),
        throwsStateError,
      );
      expect((await first).wavPath, destination.absolute.path);
    },
  );

  test('latches a persistence failure and requires startup recovery', () async {
    const failure = FileSystemException('disk full');
    final spool = await DurableAudioSpool.start(
      rootDirectory: root,
      context: contextFor('session-write-failure'),
      persistBarrier: () => Future<void>.error(failure),
    );

    await expectLater(
      spool.append(Uint8List.fromList(<int>[1, 2])),
      throwsA(same(failure)),
    );
    await expectLater(
      spool.finalize(destinationFile: destinationFor('session-write-failure')),
      throwsA(
        isA<DurableAudioSpoolRecoveryRequiredException>().having(
          (error) => error.acceptedPcmBytes,
          'acceptedPcmBytes',
          0,
        ),
      ),
    );
  });

  test(
    'quarantines when physical PCM is shorter than a valid manifest',
    () async {
      final spool = await DurableAudioSpool.start(
        rootDirectory: root,
        context: contextFor('session-acknowledged-prefix'),
        chunkBytes: 8,
      );
      writeManifest(
        spool.sessionDirectory,
        DurableAudioSpoolManifest(
          generation: 2,
          context: spool.manifest.context,
          state: DurableAudioSpoolState.recording,
          chunks: const <DurableAudioChunk>[],
          activeChunkBytes: 4,
          acceptedPcmBytes: 4,
          chunkBytes: 8,
        ),
      );

      final recovery = await DurableAudioSpool.recover(
        sessionDirectory: spool.sessionDirectory,
      );

      expect(recovery.isQuarantined, isTrue);
      expect(
        recovery.manifest.recoveryReason,
        DurableAudioRecoveryReason.acknowledgedPrefixMissing,
      );
    },
  );

  test(
    'quarantines a listed chunk whose bytes no longer match its digest',
    () async {
      final spool = await DurableAudioSpool.start(
        rootDirectory: root,
        context: contextFor('session-digest-mismatch'),
        chunkBytes: 4,
      );
      await spool.append(Uint8List.fromList(<int>[1, 2, 3, 4]));
      File(
        path.join(spool.sessionDirectory.path, 'chunk-00000000.pcm'),
      ).writeAsBytesSync(<int>[4, 3, 2, 1], flush: true);

      final recovery = await DurableAudioSpool.recover(
        sessionDirectory: spool.sessionDirectory,
      );

      expect(recovery.isQuarantined, isTrue);
      expect(
        recovery.manifest.recoveryReason,
        DurableAudioRecoveryReason.chunkDigestMismatch,
      );
    },
  );

  test('adopts a contiguous chunk published before its manifest', () async {
    final spool = await DurableAudioSpool.start(
      rootDirectory: root,
      context: contextFor('session-orphan-adoption'),
      chunkBytes: 8,
    );
    await spool.append(Uint8List.fromList(<int>[1, 2, 3, 4]));
    File(
      path.join(spool.sessionDirectory.path, 'active-00000000.part'),
    ).renameSync(
      path.join(spool.sessionDirectory.path, 'chunk-00000000.pcm'),
    );

    final recovery = await DurableAudioSpool.recover(
      sessionDirectory: spool.sessionDirectory,
    );

    expect(recovery.isQuarantined, isFalse);
    expect(recovery.manifest.chunks, hasLength(1));
    expect(recovery.manifest.acceptedPcmBytes, 4);
  });

  test('bounds manifest generations across sustained frame cadence', () async {
    final spool = await DurableAudioSpool.start(
      rootDirectory: root,
      context: contextFor('session-bounded-manifests'),
      chunkBytes: 8,
    );

    for (var index = 0; index < 400; index++) {
      await spool.append(Uint8List.fromList(<int>[index % 256, 0]));
    }

    final manifests = spool.sessionDirectory.listSync().where(
      (entry) => path.basename(entry.path).startsWith('manifest-'),
    );
    expect(manifests.length, lessThanOrEqualTo(3));
    expect(spool.manifest.acceptedPcmBytes, 800);
  });

  test('repairs a published WAV whose canonical header is damaged', () async {
    final spool = await DurableAudioSpool.start(
      rootDirectory: root,
      context: contextFor('session-wav-repair'),
    );
    await spool.append(Uint8List.fromList(<int>[1, 2, 3, 4]));
    final destination = destinationFor('session-wav-repair');
    await spool.finalize(destinationFile: destination);
    final damaged = destination.readAsBytesSync()..[0] = 0;
    destination.writeAsBytesSync(damaged, flush: true);

    final recovery = await DurableAudioSpool.recover(
      sessionDirectory: spool.sessionDirectory,
    );

    expect(recovery.manifest.state, DurableAudioSpoolState.recoveryRequired);
    final repaired = await recovery.spool!.finalize(
      destinationFile: destination,
    );
    expect(
      String.fromCharCodes(
        File(repaired.wavPath).readAsBytesSync().sublist(0, 4),
      ),
      'RIFF',
    );
  });

  test('persists explicit commit and discard lifecycle boundaries', () async {
    final committed = await DurableAudioSpool.start(
      rootDirectory: root,
      context: contextFor('session-committed'),
    );
    await committed.append(Uint8List.fromList(<int>[1, 2]));
    await committed.finalize(
      destinationFile: destinationFor('session-committed'),
    );
    await committed.markCommitted(journalAudioId: 'journal-audio-id');
    await committed.markCommitted(journalAudioId: 'journal-audio-id');

    expect(committed.manifest.state, DurableAudioSpoolState.committed);
    expect(committed.manifest.journalAudioId, 'journal-audio-id');
    await expectLater(committed.discard(), throwsStateError);

    final discarded = await DurableAudioSpool.start(
      rootDirectory: root,
      context: contextFor('session-discarded'),
      chunkBytes: 4,
    );
    await discarded.append(Uint8List.fromList(<int>[1, 2, 3, 4]));
    await discarded.discard();
    final recovery = await DurableAudioSpool.recover(
      sessionDirectory: discarded.sessionDirectory,
    );
    expect(recovery.manifest.state, DurableAudioSpoolState.discarded);
    expect(recovery.spool, isNull);
  });

  test('fails every queued frame after the first persistence hole', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    const failure = FileSystemException('first frame failed');
    var barrierCalls = 0;
    final spool = await DurableAudioSpool.start(
      rootDirectory: root,
      context: contextFor('session-prefix-hole'),
      persistBarrier: () async {
        barrierCalls += 1;
        if (barrierCalls == 1) {
          entered.complete();
          await release.future;
          throw failure;
        }
      },
    );
    final first = spool.append(Uint8List.fromList(<int>[1, 2]));
    await entered.future;
    final second = spool.append(Uint8List.fromList(<int>[3, 4]));
    release.complete();

    await expectLater(first, throwsA(same(failure)));
    await expectLater(
      second,
      throwsA(isA<DurableAudioSpoolRecoveryRequiredException>()),
    );
    expect(barrierCalls, 1);
    expect(spool.manifest.acceptedPcmBytes, 0);
  });

  test(
    'serializes finalize before discard and retains the published WAV',
    () async {
      final spool = await DurableAudioSpool.start(
        rootDirectory: root,
        context: contextFor('session-finalize-discard-race'),
      );
      await spool.append(Uint8List.fromList(<int>[1, 2]));
      final destination = destinationFor('session-finalize-discard-race');

      final finalization = spool.finalize(destinationFile: destination);
      final discard = spool.discard();

      await finalization;
      await expectLater(discard, throwsStateError);
      expect(destination.existsSync(), isTrue);
      expect(spool.manifest.state, DurableAudioSpoolState.published);
    },
  );

  test(
    'serializes commit before discard and preserves journal ownership',
    () async {
      final spool = await DurableAudioSpool.start(
        rootDirectory: root,
        context: contextFor('session-commit-discard-race'),
      );
      await spool.append(Uint8List.fromList(<int>[1, 2]));
      final destination = destinationFor('session-commit-discard-race');
      await spool.finalize(destinationFile: destination);

      final commit = spool.markCommitted(journalAudioId: 'journal-owned');
      final discard = spool.discard();

      await commit;
      await expectLater(discard, throwsStateError);
      expect(destination.existsSync(), isTrue);
      expect(spool.manifest.journalAudioId, 'journal-owned');
    },
  );

  test(
    'recovery never removes ownership from a damaged committed WAV',
    () async {
      final spool = await DurableAudioSpool.start(
        rootDirectory: root,
        context: contextFor('session-owned-damaged-wav'),
      );
      await spool.append(Uint8List.fromList(<int>[1, 2]));
      final destination = destinationFor('session-owned-damaged-wav');
      await spool.finalize(destinationFile: destination);
      await spool.markCommitted(journalAudioId: 'journal-owned-wav');
      destination.writeAsBytesSync(<int>[0], flush: true);

      final recovery = await DurableAudioSpool.recover(
        sessionDirectory: spool.sessionDirectory,
      );

      expect(recovery.manifest.journalAudioId, 'journal-owned-wav');
      await expectLater(recovery.spool!.discard(), throwsStateError);
    },
  );

  test('quarantined committed chunks retain journal ownership', () async {
    final spool = await DurableAudioSpool.start(
      rootDirectory: root,
      context: contextFor('session-owned-damaged-chunk'),
      chunkBytes: 4,
    );
    await spool.append(Uint8List.fromList(<int>[1, 2, 3, 4]));
    await spool.finalize(
      destinationFile: destinationFor('session-owned-damaged-chunk'),
    );
    await spool.markCommitted(journalAudioId: 'journal-owned-chunk');
    File(
      path.join(spool.sessionDirectory.path, 'chunk-00000000.pcm'),
    ).writeAsBytesSync(<int>[4, 3, 2, 1], flush: true);

    final recovery = await DurableAudioSpool.recover(
      sessionDirectory: spool.sessionDirectory,
    );

    expect(recovery.isQuarantined, isTrue);
    expect(recovery.manifest.journalAudioId, 'journal-owned-chunk');
  });

  test('startup resumes cleanup after a crash in discarding state', () async {
    final spool = await DurableAudioSpool.start(
      rootDirectory: root,
      context: contextFor('session-discard-resume'),
      chunkBytes: 4,
    );
    await spool.append(Uint8List.fromList(<int>[1, 2, 3, 4]));
    writeManifest(
      spool.sessionDirectory,
      DurableAudioSpoolManifest(
        generation: spool.manifest.generation + 1,
        context: spool.manifest.context,
        state: DurableAudioSpoolState.discarding,
        chunks: spool.manifest.chunks,
        activeChunkBytes: spool.manifest.activeChunkBytes,
        acceptedPcmBytes: spool.manifest.acceptedPcmBytes,
        chunkBytes: spool.manifest.chunkBytes,
      ),
    );

    final recovery = await DurableAudioSpool.recover(
      sessionDirectory: spool.sessionDirectory,
    );

    expect(recovery.manifest.state, DurableAudioSpoolState.discarded);
    expect(recovery.spool, isNull);
    expect(
      spool.sessionDirectory.listSync().where(
        (entry) => path.basename(entry.path).startsWith('chunk-'),
      ),
      isEmpty,
    );
  });

  test('retries finalization after a crash hook at WAV publication', () async {
    var failPublication = true;
    final spool = await DurableAudioSpool.start(
      rootDirectory: root,
      context: contextFor('session-finalize-retry'),
      durability: AudioSpoolDurability(
        onBoundary: (boundary) async {
          if (boundary == AudioSpoolDurabilityBoundary.wavPublished &&
              failPublication) {
            failPublication = false;
            throw StateError('simulated crash after WAV rename');
          }
        },
      ),
    );
    await spool.append(Uint8List.fromList(<int>[1, 2, 3, 4]));
    final destination = destinationFor('session-finalize-retry');

    await expectLater(
      spool.finalize(destinationFile: destination),
      throwsStateError,
    );
    final result = await spool.finalize(destinationFile: destination);

    expect(File(result.wavPath).readAsBytesSync().sublist(44), <int>[
      1,
      2,
      3,
      4,
    ]);
    expect(spool.manifest.state, DurableAudioSpoolState.published);
  });

  test('committed PCM reclamation remains recoverable from the WAV', () async {
    final spool = await DurableAudioSpool.start(
      rootDirectory: root,
      context: contextFor('session-pcm-reclaimed'),
      chunkBytes: 4,
    );
    await spool.append(Uint8List.fromList(<int>[1, 2, 3, 4]));
    await spool.finalize(
      destinationFile: destinationFor('session-pcm-reclaimed'),
    );
    await spool.markCommitted(journalAudioId: 'journal-pcm-reclaimed');

    await spool.reclaimCommittedPcm();

    expect(spool.manifest.pcmReclaimed, isTrue);
    expect(spool.manifest.chunks, isEmpty);
    expect(spool.manifest.acceptedPcmBytes, 4);
    final recovery = await DurableAudioSpool.recover(
      sessionDirectory: spool.sessionDirectory,
    );
    expect(recovery.manifest.state, DurableAudioSpoolState.committed);
    expect(recovery.manifest.pcmReclaimed, isTrue);
  });

  test(
    'emits ordered durability boundaries before publication completes',
    () async {
      final boundaries = <AudioSpoolDurabilityBoundary>[];
      final spool = await DurableAudioSpool.start(
        rootDirectory: root,
        context: contextFor('session-durability-boundaries'),
        chunkBytes: 4,
        durability: AudioSpoolDurability(
          onBoundary: (boundary) async => boundaries.add(boundary),
        ),
      );
      await spool.append(Uint8List.fromList(<int>[1, 2, 3, 4]));
      await spool.finalize(
        destinationFile: destinationFor('session-durability-boundaries'),
      );

      expect(
        boundaries,
        containsAllInOrder(<AudioSpoolDurabilityBoundary>[
          AudioSpoolDurabilityBoundary.sessionDirectoryPublished,
          AudioSpoolDurabilityBoundary.manifestFileFlushed,
          AudioSpoolDurabilityBoundary.manifestPublished,
          AudioSpoolDurabilityBoundary.activeFileFlushed,
          AudioSpoolDurabilityBoundary.activeFilePublished,
          AudioSpoolDurabilityBoundary.chunkPublished,
          AudioSpoolDurabilityBoundary.wavFileFlushed,
          AudioSpoolDurabilityBoundary.wavPublished,
        ]),
      );
    },
  );

  test(
    'owns caller bytes and admits exactly the configured pending capacity',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final spool = await DurableAudioSpool.start(
        rootDirectory: root,
        context: contextFor('session-owned-capacity'),
        maxPendingBytes: 6,
        persistBarrier: () async {
          if (!entered.isCompleted) entered.complete();
          await release.future;
        },
      );
      final source = Uint8List.fromList(<int>[1, 2, 3, 4, 5, 6]);
      final admitted = spool.append(source);
      await entered.future;
      source.fillRange(0, source.length, 9);

      expect(
        await spool.append(Uint8List.fromList(<int>[7, 8])),
        SpoolAppendResult.saturated,
      );
      release.complete();
      expect(await admitted, SpoolAppendResult.persisted);
      expect(
        File(
          path.join(spool.sessionDirectory.path, 'active-00000000.part'),
        ).readAsBytesSync(),
        <int>[1, 2, 3, 4, 5, 6],
      );
    },
  );

  test('durably provisions a missing spool root before the session', () async {
    final spoolRoot = Directory(path.join(root.path, 'new-spool-root'));
    final boundaries = <AudioSpoolDurabilityBoundary>[];

    final spool = await DurableAudioSpool.start(
      rootDirectory: spoolRoot,
      context: contextFor('session-new-root'),
      durability: AudioSpoolDurability(
        onBoundary: (boundary) async => boundaries.add(boundary),
      ),
    );

    expect(spoolRoot.existsSync(), isTrue);
    expect(spool.sessionDirectory.existsSync(), isTrue);
    expect(
      boundaries,
      containsAllInOrder(<AudioSpoolDurabilityBoundary>[
        AudioSpoolDurabilityBoundary.spoolRootPublished,
        AudioSpoolDurabilityBoundary.sessionDirectoryPublished,
        AudioSpoolDurabilityBoundary.manifestFileFlushed,
        AudioSpoolDurabilityBoundary.manifestPublished,
      ]),
    );
  });

  test(
    'durably provisions every missing final asset directory',
    () async {
      final boundaries = <AudioSpoolDurabilityBoundary>[];
      final spool = await DurableAudioSpool.start(
        rootDirectory: root,
        context: contextFor('session-new-asset-root'),
        durability: AudioSpoolDurability(
          onBoundary: (boundary) async => boundaries.add(boundary),
        ),
      );
      await spool.append(Uint8List.fromList(<int>[1, 2]));
      final destination = File(
        path.join(root.path, 'assets', 'days', 'recording.wav'),
      );

      await spool.finalize(destinationFile: destination);

      expect(destination.existsSync(), isTrue);
      expect(
        boundaries
            .where(
              (boundary) =>
                  boundary ==
                  AudioSpoolDurabilityBoundary.assetDirectoryPublished,
            )
            .length,
        2,
      );
      expect(
        boundaries.indexOf(
          AudioSpoolDurabilityBoundary.assetDirectoryPublished,
        ),
        lessThan(
          boundaries.indexOf(AudioSpoolDurabilityBoundary.wavFileFlushed),
        ),
      );
    },
  );

  test('rejects final publication outside the immutable asset root', () async {
    final spool = await DurableAudioSpool.start(
      rootDirectory: root,
      context: contextFor('session-asset-confinement'),
    );
    await spool.append(Uint8List.fromList(<int>[1, 2]));

    await expectLater(
      spool.finalize(
        destinationFile: File(path.join(root.path, 'outside.wav')),
      ),
      throwsArgumentError,
    );
  });

  test('repair cannot rebind immutable journal ownership', () async {
    final spool = await DurableAudioSpool.start(
      rootDirectory: root,
      context: contextFor('session-owner-repair'),
    );
    await spool.append(Uint8List.fromList(<int>[1, 2]));
    final destination = destinationFor('session-owner-repair');
    await spool.finalize(destinationFile: destination);
    await spool.markCommitted(journalAudioId: 'original-owner');
    destination.writeAsBytesSync(<int>[0], flush: true);
    final recovery = await DurableAudioSpool.recover(
      sessionDirectory: spool.sessionDirectory,
    );
    await recovery.spool!.finalize(destinationFile: destination);

    await expectLater(
      recovery.spool!.markCommitted(journalAudioId: 'different-owner'),
      throwsStateError,
    );
    await recovery.spool!.markCommitted(journalAudioId: 'original-owner');
    expect(recovery.spool!.manifest.journalAudioId, 'original-owner');
  });

  test('owner marker survives corrupt committed manifest fallback', () async {
    final spool = await DurableAudioSpool.start(
      rootDirectory: root,
      context: contextFor('session-owner-marker-fallback'),
    );
    await spool.append(Uint8List.fromList(<int>[1, 2]));
    final destination = destinationFor('session-owner-marker-fallback');
    await spool.finalize(destinationFile: destination);
    await spool.markCommitted(journalAudioId: 'marker-owner');
    final manifests =
        spool.sessionDirectory
            .listSync()
            .where((entry) => path.basename(entry.path).startsWith('manifest-'))
            .toList()
          ..sort((a, b) => b.path.compareTo(a.path));
    File(manifests.first.path).writeAsStringSync('corrupt', flush: true);
    destination.writeAsBytesSync(<int>[0], flush: true);

    final recovery = await DurableAudioSpool.recover(
      sessionDirectory: spool.sessionDirectory,
    );

    expect(recovery.manifest.journalAudioId, 'marker-owner');
    await expectLater(recovery.spool!.discard(), throwsStateError);
  });

  test('reclaim fallback survives corruption of its newest manifest', () async {
    final spool = await DurableAudioSpool.start(
      rootDirectory: root,
      context: contextFor('session-reclaim-fallback'),
      chunkBytes: 4,
    );
    await spool.append(Uint8List.fromList(<int>[1, 2, 3, 4]));
    await spool.finalize(
      destinationFile: destinationFor('session-reclaim-fallback'),
    );
    await spool.markCommitted(journalAudioId: 'reclaim-owner');
    await spool.reclaimCommittedPcm();
    final manifests =
        spool.sessionDirectory
            .listSync()
            .where((entry) => path.basename(entry.path).startsWith('manifest-'))
            .toList()
          ..sort((a, b) => b.path.compareTo(a.path));
    File(manifests.first.path).writeAsStringSync('corrupt', flush: true);

    final recovery = await DurableAudioSpool.recover(
      sessionDirectory: spool.sessionDirectory,
    );

    expect(recovery.manifest.state, DurableAudioSpoolState.reclaimPrepared);
    expect(recovery.manifest.pcmReclaimed, isFalse);
    expect(recovery.manifest.journalAudioId, 'reclaim-owner');
    await recovery.spool!.reclaimCommittedPcm();
    expect(recovery.spool!.manifest.state, DurableAudioSpoolState.committed);
    expect(recovery.spool!.manifest.pcmReclaimed, isTrue);
  });

  test(
    'reclaim resumes safely when the second phase fails before publication',
    () async {
      var armed = false;
      var publishedWhileArmed = 0;
      final spool = await DurableAudioSpool.start(
        rootDirectory: root,
        context: contextFor('session-reclaim-two-phase'),
        chunkBytes: 4,
        durability: AudioSpoolDurability(
          onBoundary: (boundary) async {
            if (!armed) return;
            if (boundary == AudioSpoolDurabilityBoundary.manifestPublished) {
              publishedWhileArmed += 1;
            }
            if (boundary == AudioSpoolDurabilityBoundary.manifestFileFlushed &&
                publishedWhileArmed == 1) {
              throw StateError('simulated crash before reclaim commit');
            }
          },
        ),
      );
      await spool.append(Uint8List.fromList(<int>[1, 2, 3, 4]));
      await spool.finalize(
        destinationFile: destinationFor('session-reclaim-two-phase'),
      );
      await spool.markCommitted(journalAudioId: 'two-phase-owner');
      armed = true;

      await expectLater(spool.reclaimCommittedPcm(), throwsStateError);

      final chunk = File(
        path.join(spool.sessionDirectory.path, 'chunk-00000000.pcm'),
      );
      expect(chunk.existsSync(), isTrue);
      final recovery = await DurableAudioSpool.recover(
        sessionDirectory: spool.sessionDirectory,
      );
      expect(
        recovery.manifest.state,
        DurableAudioSpoolState.reclaimPrepared,
      );
      expect(recovery.manifest.pcmReclaimed, isFalse);

      await recovery.spool!.reclaimCommittedPcm();

      expect(chunk.existsSync(), isFalse);
      expect(
        recovery.spool!.manifest.state,
        DurableAudioSpoolState.committed,
      );
      expect(recovery.spool!.manifest.pcmReclaimed, isTrue);
    },
  );

  test(
    'invalid reclaimed WAV keeps a valid quarantine across restarts',
    () async {
      final spool = await DurableAudioSpool.start(
        rootDirectory: root,
        context: contextFor('session-reclaim-quarantine'),
        chunkBytes: 4,
      );
      await spool.append(Uint8List.fromList(<int>[1, 2, 3, 4]));
      final destination = destinationFor('session-reclaim-quarantine');
      await spool.finalize(destinationFile: destination);
      await spool.markCommitted(journalAudioId: 'quarantine-owner');
      await spool.reclaimCommittedPcm();
      destination.writeAsBytesSync(<int>[0], flush: true);

      for (var restart = 0; restart < 5; restart++) {
        final recovery = await DurableAudioSpool.recover(
          sessionDirectory: spool.sessionDirectory,
        );
        expect(
          recovery.manifest.state,
          DurableAudioSpoolState.quarantined,
          reason: 'restart=$restart',
        );
        expect(recovery.manifest.journalAudioId, 'quarantine-owner');
        expect(
          recovery.manifest.recoveryReason,
          DurableAudioRecoveryReason.invalidReclaimedWav,
        );
      }
    },
  );

  for (final boundary in <AudioSpoolDurabilityBoundary>[
    AudioSpoolDurabilityBoundary.activeFileFlushed,
    AudioSpoolDurabilityBoundary.activeFilePublished,
    AudioSpoolDurabilityBoundary.chunkPublished,
    AudioSpoolDurabilityBoundary.manifestFileFlushed,
    AudioSpoolDurabilityBoundary.manifestPublished,
  ]) {
    test('recovers a frame after a crash at ${boundary.name}', () async {
      var armed = false;
      var failed = false;
      final sessionId = 'crash-frame-${boundary.name}';
      final spool = await DurableAudioSpool.start(
        rootDirectory: root,
        context: contextFor(sessionId),
        chunkBytes: 4,
        durability: AudioSpoolDurability(
          onBoundary: (observed) async {
            if (armed && observed == boundary && !failed) {
              failed = true;
              throw StateError('simulated crash at ${boundary.name}');
            }
          },
        ),
      );
      armed = true;

      await expectLater(
        spool.append(Uint8List.fromList(<int>[1, 2, 3, 4])),
        throwsStateError,
      );
      final recovery = await DurableAudioSpool.recover(
        sessionDirectory: spool.sessionDirectory,
      );

      expect(recovery.isQuarantined, isFalse, reason: boundary.name);
      expect(recovery.manifest.acceptedPcmBytes, 4, reason: boundary.name);
    });
  }

  for (final boundary in <AudioSpoolDurabilityBoundary>[
    AudioSpoolDurabilityBoundary.wavFileFlushed,
    AudioSpoolDurabilityBoundary.wavPublished,
  ]) {
    test('rebuilds the WAV after a crash at ${boundary.name}', () async {
      var armed = false;
      var failed = false;
      final sessionId = 'crash-wav-${boundary.name}';
      final spool = await DurableAudioSpool.start(
        rootDirectory: root,
        context: contextFor(sessionId),
        durability: AudioSpoolDurability(
          onBoundary: (observed) async {
            if (armed && observed == boundary && !failed) {
              failed = true;
              throw StateError('simulated crash at ${boundary.name}');
            }
          },
        ),
      );
      await spool.append(Uint8List.fromList(<int>[1, 2, 3, 4]));
      armed = true;
      final destination = destinationFor(sessionId);

      await expectLater(
        spool.finalize(destinationFile: destination),
        throwsStateError,
      );
      final recovery = await DurableAudioSpool.recover(
        sessionDirectory: spool.sessionDirectory,
      );
      final rebuilt = await recovery.spool!.finalize(
        destinationFile: destination,
      );

      expect(File(rebuilt.wavPath).readAsBytesSync().sublist(44), <int>[
        1,
        2,
        3,
        4,
      ]);
    });
  }

  for (final boundary in <AudioSpoolDurabilityBoundary>[
    AudioSpoolDurabilityBoundary.wavFileFlushed,
    AudioSpoolDurabilityBoundary.wavPublished,
  ]) {
    test(
      'discard purges artifacts after a crash at ${boundary.name}',
      () async {
        var armed = false;
        var failed = false;
        final sessionId = 'discard-wav-${boundary.name}';
        final spool = await DurableAudioSpool.start(
          rootDirectory: root,
          context: contextFor(sessionId),
          durability: AudioSpoolDurability(
            onBoundary: (observed) async {
              if (armed && observed == boundary && !failed) {
                failed = true;
                throw StateError('simulated crash at ${boundary.name}');
              }
            },
          ),
        );
        await spool.append(Uint8List.fromList(<int>[1, 2, 3, 4]));
        armed = true;
        final destination = destinationFor(sessionId);
        await expectLater(
          spool.finalize(destinationFile: destination),
          throwsStateError,
        );
        final cleanupBoundaries = <AudioSpoolDurabilityBoundary>[];
        final recovery = await DurableAudioSpool.recover(
          sessionDirectory: spool.sessionDirectory,
          durability: AudioSpoolDurability(
            onBoundary: (observed) async => cleanupBoundaries.add(observed),
          ),
        );

        await recovery.spool!.discard();

        expect(destination.existsSync(), isFalse);
        expect(File('${destination.path}.part').existsSync(), isFalse);
        expect(File('${destination.path}.previous').existsSync(), isFalse);
        expect(
          cleanupBoundaries,
          containsAll(<AudioSpoolDurabilityBoundary>[
            AudioSpoolDurabilityBoundary.pcmPurged,
            AudioSpoolDurabilityBoundary.assetPurged,
          ]),
        );
      },
    );
  }

  glados.Glados<List<int>>(
    glados.any.listWithLengthInRange(
      2,
      96,
      glados.any.intInRange(0, 256),
    ),
    glados.ExploreConfig(numRuns: 80),
  ).test('finalization preserves every generated even PCM byte', (
    values,
  ) async {
    final evenValues = values.length.isEven
        ? values
        : values.sublist(0, values.length - 1);
    final id = sha256.convert(evenValues).toString().substring(0, 16);
    final sessionDirectory = Directory(path.join(root.path, 'generated-$id'));
    try {
      final spool = await DurableAudioSpool.start(
        rootDirectory: root,
        context: contextFor('generated-$id'),
        chunkBytes: 16,
      );

      await spool.append(Uint8List.fromList(evenValues));
      final result = await spool.finalize(
        destinationFile: destinationFor('generated-$id'),
      );

      final wav = File(result.wavPath).readAsBytesSync();
      expect(
        wav.sublist(44),
        evenValues,
        reason: 'inputLength=${values.length}',
      );
      expect(result.pcmBytes, evenValues.length);
      expect(result.wavSha256, sha256.convert(wav).toString());
    } finally {
      if (sessionDirectory.existsSync()) {
        sessionDirectory.deleteSync(recursive: true);
      }
    }
  }, tags: 'glados');
}
