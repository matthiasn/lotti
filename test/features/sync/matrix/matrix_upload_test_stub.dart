import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

/// Models the server descriptor returned by successful mocked file uploads.
/// Tests can replace the client's response to inject malformed wire events.
class MatrixUploadTestStub {
  MatrixUploadTestStub(MockRoom room) {
    when(() => room.client).thenReturn(client);
    when(
      () => client.getOneRoomEvent(any(), any()),
    ).thenAnswer((invocation) async {
      final id = invocation.positionalArguments[1] as String;
      return descriptors[id]!;
    });
  }

  final client = MockMatrixClient();
  final descriptors = <String, MatrixEvent>{};

  Future<String?> Function(Invocation) record(
    Future<String?> Function(Invocation) upload,
  ) => (invocation) async {
    final extra = Map<String, dynamic>.from(
      invocation.namedArguments[#extraContent] as Map<String, dynamic>,
    );
    final id = await upload(invocation);
    if (id != null) {
      descriptors[id] = MatrixEvent(
        content: {
          'msgtype': MessageTypes.File,
          'url': 'mxc://example.test/upload',
          ...extra,
        },
        type: EventTypes.Message,
        eventId: id,
        senderId: '@sender:example.test',
        originServerTs: DateTime.utc(2026, 9, 26),
      );
    }
    return id;
  };
}
