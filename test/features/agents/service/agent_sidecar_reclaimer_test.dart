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

  test('removes the entity and link files it is given', () {
    final entity = writeSidecar(relativeAgentEntityPath('entity-1'));
    final link = writeSidecar(relativeAgentLinkPath('link-1'));

    final removed = reclaimer.reclaim(
      entityIds: ['entity-1'],
      linkIds: ['link-1'],
    );

    expect(removed, 2);
    expect(entity.existsSync(), isFalse);
    expect(link.existsSync(), isFalse);
  });

  test('leaves every other sidecar alone', () {
    final keep = writeSidecar(relativeAgentEntityPath('entity-keep'));
    writeSidecar(relativeAgentEntityPath('entity-go'));

    reclaimer.reclaim(entityIds: ['entity-go']);

    expect(
      keep.existsSync(),
      isTrue,
      reason: 'Reclamation is id-scoped, never a sweep of the directory.',
    );
  });

  test('an absent file is the normal case, not an error', () {
    // The entity may never have synced, so no sidecar was ever written.
    expect(reclaimer.reclaim(entityIds: ['never-synced']), 0);
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

  test('an unreadable file is logged, not thrown', () {
    final file = writeSidecar(relativeAgentEntityPath('entity-1'));
    // Read-only parent: the file is visible but cannot be unlinked. The
    // caller has already committed its database work, so this must not
    // propagate.
    final parent = file.parent;
    Process.runSync('chmod', ['a-w', parent.path]);
    addTearDown(() => Process.runSync('chmod', ['u+w', parent.path]));

    expect(reclaimer.reclaim(entityIds: ['entity-1']), 0);
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

  test('no documents directory disables reclamation rather than failing', () {
    final headless = AgentSidecarReclaimer(
      documentsDirectory: null,
      domainLogger: domainLogger,
    );

    expect(
      headless.reclaim(entityIds: ['entity-1']),
      0,
      reason:
          'The caller has already committed its database work; a missing '
          'documents directory must not turn that into a failure.',
    );
  });

  test(
    'the id is joined under the documents root, not treated as absolute',
    () {
      // relativeAgentEntityPath carries a leading '/', which a naive join would
      // read as an absolute path and escape the sandbox with.
      final file = writeSidecar(relativeAgentEntityPath('entity-1'));

      reclaimer.reclaim(entityIds: ['entity-1']);

      expect(file.existsSync(), isFalse);
      expect(file.path.startsWith(root.path), isTrue);
    },
  );
}
