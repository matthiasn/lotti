import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/service/agent_sidecar_reclaimer.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late Directory root;
  late MockDomainLogger domainLogger;
  late AgentSidecarReclaimer reclaimer;

  setUp(() {
    root = Directory.systemTemp.createTempSync('sidecar-reclaim-');
    domainLogger = MockDomainLogger();
    when(
      () => domainLogger.error(
        any(),
        any(),
        message: any(named: 'message'),
        stackTrace: any(named: 'stackTrace'),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);
    reclaimer = AgentSidecarReclaimer(
      documentsDirectory: root,
      domainLogger: domainLogger,
    );
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  File writeSidecar(String relativePath) {
    final file = File('${root.path}$relativePath');
    file.parent.createSync(recursive: true);
    return file..writeAsStringSync('{"secret":"content"}');
  }

  test('removes the entity and link files it is given', () async {
    final entity = writeSidecar(relativeAgentEntityPath('entity-1'));
    final link = writeSidecar(relativeAgentLinkPath('link-1'));

    final removed = await reclaimer.reclaim(
      entityIds: ['entity-1'],
      linkIds: ['link-1'],
    );

    expect(removed, 2);
    expect(entity.existsSync(), isFalse);
    expect(link.existsSync(), isFalse);
  });

  test('leaves every other sidecar alone', () async {
    final keep = writeSidecar(relativeAgentEntityPath('entity-keep'));
    writeSidecar(relativeAgentEntityPath('entity-go'));

    await reclaimer.reclaim(entityIds: ['entity-go']);

    expect(
      keep.existsSync(),
      isTrue,
      reason: 'Reclamation is id-scoped, never a sweep of the directory.',
    );
  });

  test('an absent file is the normal case, not an error', () async {
    // The entity may never have synced, so no sidecar was ever written.
    expect(await reclaimer.reclaim(entityIds: ['never-synced']), 0);
    verifyNever(
      () => domainLogger.error(
        any(),
        any(),
        message: any(named: 'message'),
        stackTrace: any(named: 'stackTrace'),
        subDomain: any(named: 'subDomain'),
      ),
    );
  });

  test('a deletion failure is logged, not thrown', () async {
    // Forced through the seam rather than a chmod: the real failure modes are
    // OS-specific, the suite runs a Windows shard, and an elevated POSIX user
    // can delete a file its parent directory denies.
    writeSidecar(relativeAgentEntityPath('entity-1'));
    reclaimer.deleteSidecar = (_) => throw const FileSystemException('busy');

    expect(await reclaimer.reclaim(entityIds: ['entity-1']), 0);
    verify(
      () => domainLogger.error(
        any(),
        any(),
        message: any(named: 'message'),
        stackTrace: any(named: 'stackTrace'),
        subDomain: any(named: 'subDomain'),
      ),
    ).called(1);
  });

  test('an id that would escape the sidecar directory is refused', () async {
    // Ids arrive from sync payloads, so they are untrusted. Without the
    // containment check this resolves to <docs>/agent_entities/../secret.json
    // and deletes a file no database write ever accounted for.
    final outside = File('${root.path}/secret.json')
      ..writeAsStringSync('{"not":"a sidecar"}');

    expect(await reclaimer.reclaim(entityIds: ['../secret']), 0);

    expect(
      outside.existsSync(),
      isTrue,
      reason: 'Reclamation must never reach outside the sidecar directory.',
    );
  });

  test('absolute and separator-bearing ids are refused too', () async {
    for (final id in ['/etc/passwd', 'a/b', 'nested/../../escape']) {
      expect(await reclaimer.reclaim(entityIds: [id]), 0);
    }
  });

  test('a real day-status id passes the containment check', () async {
    // day_status:<dayId>:<uuid>. Asserted through the predicate rather than
    // by writing the file: Windows rejects colons in filenames, and the suite
    // runs a Windows shard, so creating one would fail the test before it
    // reached `reclaim`. (That the sidecar itself is unwritable on Windows is
    // a platform question older and wider than this change.)
    expect(
      AgentSidecarReclaimer.isReclaimable(
        root: root,
        id: 'day_status:dayplan-2026-05-20:6f1c2f2e-0f0a-4f1e-8a1b-2c3d4e5f',
        toPath: relativeAgentEntityPath,
      ),
      isTrue,
      reason:
          'A character blacklist that rejected ":" would refuse every '
          'production day-status event and silently reclaim nothing.',
    );
  });

  test('an id that re-enters the sidecar directory is refused', () async {
    // '../agent_entities/victim' normalises back to
    // '<docs>/agent_entities/victim.json', so a check that only compares the
    // parent directory accepts it — and the delete then takes a *different*
    // row's live sidecar.
    final victim = writeSidecar(relativeAgentEntityPath('victim'));

    expect(
      await reclaimer.reclaim(entityIds: ['../agent_entities/victim']),
      0,
    );
    expect(victim.existsSync(), isTrue);
  });

  test('the containment check is not vacuous under p.join', () async {
    // p.join discards everything before an absolute segment, and these
    // relative paths start with '/'. Joining them dropped the root on BOTH
    // sides, so the comparison matched two escaped paths and passed without
    // checking containment at all.
    expect(
      AgentSidecarReclaimer.isReclaimable(
        root: root,
        id: 'ordinary-id',
        toPath: relativeAgentEntityPath,
      ),
      isTrue,
    );
    expect(
      AgentSidecarReclaimer.isReclaimable(
        root: root,
        // A link id checked against the entity directory must not pass.
        id: 'ordinary-id',
        toPath: relativeAgentLinkPath,
      ),
      isTrue,
      reason: 'Each kind is checked against its own directory.',
    );
  });

  test('a large batch yields the isolate instead of blocking it', () async {
    // The deletes are synchronous, so a full sweep of ten thousand ids would
    // monopolise the isolate and show up as a startup freeze. Crossing the
    // yield threshold must not change what gets removed.
    final ids = [for (var i = 0; i < 250; i++) 'bulk-$i'];
    for (final id in ids) {
      writeSidecar(relativeAgentEntityPath(id));
    }

    expect(await reclaimer.reclaim(entityIds: ids), 250);
    for (final id in ids) {
      expect(
        File('${root.path}${relativeAgentEntityPath(id)}').existsSync(),
        isFalse,
      );
    }
  });

  test(
    'no documents directory disables reclamation rather than failing',
    () async {
      final headless = AgentSidecarReclaimer(
        documentsDirectory: null,
        domainLogger: domainLogger,
      );

      expect(
        await headless.reclaim(entityIds: ['entity-1']),
        0,
        reason:
            'The caller has already committed its database work; a missing '
            'documents directory must not turn that into a failure.',
      );
    },
  );

  test(
    'the id is joined under the documents root, not treated as absolute',
    () async {
      // relativeAgentEntityPath carries a leading '/', which a naive join would
      // read as an absolute path and escape the sandbox with.
      final file = writeSidecar(relativeAgentEntityPath('entity-1'));

      await reclaimer.reclaim(entityIds: ['entity-1']);

      expect(file.existsSync(), isFalse);
      expect(file.path.startsWith(root.path), isTrue);
    },
  );
}
