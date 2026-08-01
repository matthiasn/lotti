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
    for (final id in ['/etc/passwd', 'a/b', r'a\\b', 'C:file']) {
      expect(await reclaimer.reclaim(entityIds: [id]), 0);
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
