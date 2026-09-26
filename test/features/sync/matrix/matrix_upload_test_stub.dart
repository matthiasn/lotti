import 'dart:convert';
import 'dart:typed_data';

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

  /// Structurally valid v2 metadata with deterministic test key material.
  /// This fixture does not claim that any uploaded bytes match its hash.
  static Map<String, dynamic> encryptedFileDescriptor() => {
    'url': 'mxc://example.test/upload',
    'v': 'v2',
    'key': <String, dynamic>{
      'alg': 'A256CTR',
      'ext': true,
      'k': base64Url.encode(Uint8List(32)).replaceAll('=', ''),
      'key_ops': ['encrypt', 'decrypt'],
      'kty': 'oct',
    },
    'iv': base64.encode(Uint8List(16)).replaceAll('=', ''),
    'hashes': <String, dynamic>{
      'sha256': base64.encode(Uint8List(32)).replaceAll('=', ''),
    },
  };

  final client = MockMatrixClient();
  final descriptors = <String, MatrixEvent>{};

  Future<String?> Function(Invocation) record(
    Future<String?> Function(Invocation) upload,
  ) => (invocation) async {
    final file = invocation.positionalArguments.first as MatrixFile;
    final extra = Map<String, dynamic>.from(
      invocation.namedArguments[#extraContent] as Map<String, dynamic>,
    );
    final id = await upload(invocation);
    if (id != null) {
      descriptors[id] = MatrixEvent(
        content: {
          'msgtype': file.msgType,
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
