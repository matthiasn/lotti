import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_descriptor.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';

void main() {
  MockEvent event({
    required Map<String, dynamic> content,
    String eventId = r'$attachment',
    String roomId = '!room:example.org',
    String mimetype = 'image/jpeg',
  }) {
    final e = MockEvent();
    when(() => e.eventId).thenReturn(eventId);
    when(() => e.roomId).thenReturn(roomId);
    when(() => e.attachmentMimetype).thenReturn(mimetype);
    when(() => e.content).thenReturn(content);
    return e;
  }

  group('AttachmentDescriptor.fromEvent', () {
    test('copies what the apply path reads out of a media event', () {
      final descriptor = AttachmentDescriptor.fromEvent(
        event(
          content: {
            'relativePath': 'images/a.jpg',
            'info': {'size': 1234},
            attachmentEncodingKey: attachmentEncodingGzip,
          },
        ),
      );

      expect(descriptor, isNotNull);
      expect(descriptor!.eventId, r'$attachment');
      expect(descriptor.roomId, '!room:example.org');
      expect(descriptor.relativePath, 'images/a.jpg');
      expect(descriptor.mimetype, 'image/jpeg');
      expect(descriptor.declaredSize, 1234);
      expect(descriptor.encoding, attachmentEncodingGzip);
    });

    test('is null for an event that declares no relativePath', () {
      expect(AttachmentDescriptor.fromEvent(event(content: {})), isNull);
      expect(
        AttachmentDescriptor.fromEvent(event(content: {'relativePath': ''})),
        isNull,
      );
      expect(
        AttachmentDescriptor.fromEvent(event(content: {'relativePath': 42})),
        isNull,
      );
    });

    test('declares no size for a JSON payload, whose upload size is the '
        "gzip's, nor without a numeric info.size", () {
      expect(
        AttachmentDescriptor.fromEvent(
          event(
            content: {
              'relativePath': '/text_entries/c.json',
              'info': {'size': 99},
            },
          ),
        )!.declaredSize,
        isNull,
      );
      expect(
        AttachmentDescriptor.fromEvent(
          event(content: {'relativePath': 'images/b.jpg'}),
        )!.declaredSize,
        isNull,
      );
      expect(
        AttachmentDescriptor.fromEvent(
          event(
            content: {
              'relativePath': 'images/b.jpg',
              'info': {'size': 'big'},
            },
          ),
        )!.declaredSize,
        isNull,
      );
    });

    test('keeps only a string encoding, and none when absent', () {
      expect(
        AttachmentDescriptor.fromEvent(
          event(content: {'relativePath': 'a.json', attachmentEncodingKey: 7}),
        )!.encoding,
        isNull,
      );
      expect(
        AttachmentDescriptor.fromEvent(
          event(content: {'relativePath': 'a.json'}),
        )!.encoding,
        isNull,
      );
    });

    test('an event whose id cannot be read is described with an empty id, '
        'so it is still found by its path', () {
      final e = event(content: {'relativePath': 'images/a.jpg'});
      when(() => e.eventId).thenThrow(StateError('no id'));

      expect(AttachmentDescriptor.fromEvent(e)!.eventId, '');
    });
  });
}
