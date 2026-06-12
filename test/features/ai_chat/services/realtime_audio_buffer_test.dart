import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:glados/glados.dart';
import 'package:lotti/features/ai_chat/services/realtime_audio_buffer.dart';

extension _AnyPcm on Any {
  /// A sequence of PCM chunks: each chunk is a (possibly empty) byte list.
  Generator<List<List<int>>> get pcmChunks => list(list(intInRange(0, 256)));

  /// Cap sizes small enough that generated chunk sequences overflow them.
  Generator<int> get smallMaxBytes => intInRange(1, 48);
}

/// Encodes [samples] (signed 16-bit values) as little-endian PCM bytes.
Uint8List pcm16FromSamples(List<int> samples) {
  final bytes = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    bytes.setInt16(i * 2, samples[i], Endian.little);
  }
  return bytes.buffer.asUint8List();
}

void main() {
  group('RealtimeAudioBuffer accumulation', () {
    test('accumulates chunks in order without consuming on toBytes', () {
      final buffer = RealtimeAudioBuffer(maxBytes: 100)
        ..addChunk(Uint8List.fromList([1, 2, 3]))
        ..addChunk(Uint8List.fromList([4, 5]));

      expect(buffer.toBytes(), [1, 2, 3, 4, 5]);
      expect(buffer.length, 5);
      // toBytes copies — reading again returns the same content.
      expect(buffer.toBytes(), [1, 2, 3, 4, 5]);
    });

    test('evicts oldest bytes when a new chunk overflows maxBytes', () {
      final buffer = RealtimeAudioBuffer(maxBytes: 8)
        ..addChunk(Uint8List.fromList([0, 1, 2, 3, 4, 5]))
        ..addChunk(Uint8List.fromList([6, 7, 8, 9, 10, 11]));

      // Last 8 bytes of the 12-byte concatenation survive.
      expect(buffer.toBytes(), [4, 5, 6, 7, 8, 9, 10, 11]);
      expect(buffer.length, 8);
    });

    test('keeps only the tail of a single chunk larger than maxBytes', () {
      final buffer = RealtimeAudioBuffer(maxBytes: 4)
        ..addChunk(
          Uint8List.fromList(List.generate(10, (i) => i)),
        );

      expect(buffer.toBytes(), [6, 7, 8, 9]);
    });

    test('clear empties the buffer and accepts new audio afterwards', () {
      final buffer = RealtimeAudioBuffer(maxBytes: 16)
        ..addChunk(Uint8List.fromList([1, 2, 3]))
        ..clear();

      expect(buffer.length, 0);
      expect(buffer.toBytes(), isEmpty);

      buffer.addChunk(Uint8List.fromList([9]));
      expect(buffer.toBytes(), [9]);
    });
  });

  group('RealtimeAudioBuffer amplitude stream', () {
    test('emits one dBFS value per chunk with correct levels', () {
      fakeAsync((async) {
        final buffer = RealtimeAudioBuffer();
        final emitted = <double>[];
        buffer.amplitudeStream.listen(emitted.add);

        buffer
          // Silence: dBFS floor.
          ..addChunk(Uint8List(3200))
          // Constant half-scale samples: 20*log10(16384/32768) ≈ -6.02 dBFS.
          ..addChunk(pcm16FromSamples(List.filled(160, 16384)));
        async.flushMicrotasks();

        expect(emitted, hasLength(2));
        expect(emitted[0], -80);
        expect(emitted[1], closeTo(-6.02, 0.01));

        buffer.close();
        async.flushMicrotasks();
      });
    });

    test('close stops amplitude emission while buffering continues', () {
      fakeAsync((async) {
        final buffer = RealtimeAudioBuffer(maxBytes: 16);
        final emitted = <double>[];
        var closed = false;
        buffer.amplitudeStream.listen(emitted.add, onDone: () => closed = true);

        buffer.addChunk(Uint8List.fromList([1, 2]));
        async.flushMicrotasks();
        buffer.close();
        async.flushMicrotasks();
        // After close: no emission, no throw — audio is still retained so a
        // stop() that races a close can still save the file.
        buffer.addChunk(Uint8List.fromList([3, 4]));
        async.flushMicrotasks();

        expect(emitted, hasLength(1));
        expect(closed, isTrue);
        expect(buffer.toBytes(), [1, 2, 3, 4]);
      });
    });
  });

  group('RealtimeAudioBuffer properties', () {
    Glados2(
      any.pcmChunks,
      any.smallMaxBytes,
      ExploreConfig(numRuns: 120),
    ).test(
      'buffer always holds exactly the last maxBytes of the concatenation '
      'and emits one amplitude per chunk',
      (chunks, maxBytes) {
        fakeAsync((async) {
          final buffer = RealtimeAudioBuffer(maxBytes: maxBytes);
          final emitted = <double>[];
          buffer.amplitudeStream.listen(emitted.add);

          final concatenated = <int>[];
          for (final chunk in chunks) {
            buffer.addChunk(Uint8List.fromList(chunk));
            concatenated.addAll(chunk);
          }
          async.flushMicrotasks();

          final keptBytes = concatenated.length < maxBytes
              ? concatenated.length
              : maxBytes;
          final expected = concatenated.sublist(
            concatenated.length - keptBytes,
          );
          final reason = 'chunks=$chunks maxBytes=$maxBytes';

          expect(buffer.length, lessThanOrEqualTo(maxBytes), reason: reason);
          expect(buffer.toBytes(), expected, reason: reason);
          expect(emitted, hasLength(chunks.length), reason: reason);
          for (final dbfs in emitted) {
            expect(dbfs, inInclusiveRange(-80, 0), reason: reason);
          }

          buffer.close();
          async.flushMicrotasks();
        });
      },
      tags: 'glados',
    );
  });
}
