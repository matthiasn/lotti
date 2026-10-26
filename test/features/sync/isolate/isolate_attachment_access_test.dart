import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/isolate/isolate_attachment_access.dart';
import 'package:lotti/features/sync/isolate/isolate_sync_service.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_protocol.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_descriptor.dart';
import 'package:mocktail/mocktail.dart';

class _MockIsolateSyncService extends Mock implements IsolateSyncService {}

/// The apply step's two client lookups as commands to the worker.
void main() {
  const descriptor = AttachmentDescriptor(
    eventId: r'$att',
    roomId: '!room:example.org',
    relativePath: '/images/a.jpg',
    mimetype: 'image/jpeg',
  );
  late _MockIsolateSyncService service;

  setUpAll(() => registerFallbackValue(const SyncIsolateGetSnapshot()));

  setUp(() => service = _MockIsolateSyncService());

  test('recovery asks the worker by room and event id and returns what it '
      'vetted', () async {
    when(() => service.command(any())).thenAnswer((_) async => descriptor);

    final recovered = await IsolateDescriptorRecovery(service).recover(
      roomId: '!room:example.org',
      eventId: r'$att',
    );

    expect(recovered, same(descriptor));
    final command =
        verify(() => service.command(captureAny())).captured.single
            as SyncIsolateRecoverDescriptor;
    expect(command.roomId, '!room:example.org');
    expect(command.eventId, r'$att');
  });

  test('a recovery that found nothing is null', () async {
    when(() => service.command(any())).thenAnswer((_) async => null);

    expect(
      await IsolateDescriptorRecovery(
        service,
      ).recover(roomId: '!room:example.org', eventId: r'$att'),
      isNull,
    );
  });

  test('download asks with the descriptor and the path for errors, and '
      'returns the bytes', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    when(() => service.command(any())).thenAnswer((_) async => bytes);

    final downloaded = await IsolateAttachmentFetcher(
      service,
    ).download(descriptor, pathForError: '/text_entries/a.json');

    expect(downloaded, same(bytes));
    final command =
        verify(() => service.command(captureAny())).captured.single
            as SyncIsolateDownloadAttachment;
    expect(command.descriptor, same(descriptor));
    expect(command.pathForError, '/text_entries/a.json');
  });

  test('purge asks with the descriptor and returns the purged uri', () async {
    when(
      () => service.command(any()),
    ).thenAnswer((_) async => Uri.parse('mxc://example.org/abc'));

    final purged = await IsolateAttachmentFetcher(
      service,
    ).purgeCached(descriptor);

    expect(purged, Uri.parse('mxc://example.org/abc'));
    expect(
      verify(() => service.command(captureAny())).captured.single,
      isA<SyncIsolatePurgeAttachment>().having(
        (c) => c.descriptor,
        'descriptor',
        same(descriptor),
      ),
    );
  });
}
