import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tts/engine/supertonic_tts_session.dart';
import 'package:lotti/features/tts/engine/unicode_processor.dart';
import 'package:lotti/features/tts/engine/voice_style_loader.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  // Tiny config so _sampleNoisyLatent/_latentMask produce 1×1×1 arrays: with
  // a 0.1s duration at 10 Hz, wavLen=1, chunkSize=1 -> latentLen=1, latentDim=1.
  final cfgs = <String, dynamic>{
    'ae': {'sample_rate': 10, 'base_chunk_size': 1},
    'ttl': {'chunk_compress_factor': 1, 'latent_dim': 1},
  };

  setUpAll(() => registerFallbackValue(<String, OrtValue>{}));

  late MockOrtSession durationPredictor;
  late MockOrtSession textEncoder;
  late MockOrtSession vectorEstimator;
  late MockOrtSession vocoder;
  late VoiceStyle style;

  // Every tensor the (faked) builders hand out — assert they all get disposed.
  late List<MockOrtValue> builtTensors;

  late MockOrtValue durationOut;
  late MockOrtValue textEmbOut;
  late MockOrtValue vectorOut;
  late MockOrtValue wavOut;

  MockOrtValue stubbedValue(List<double>? asList) {
    final value = MockOrtValue();
    if (asList != null) {
      when(() => value.asList()).thenAnswer((_) async => asList);
    }
    when(() => value.dispose()).thenAnswer((_) async {});
    return value;
  }

  Future<OrtValue> trackBuilt() async {
    final value = MockOrtValue();
    when(() => value.dispose()).thenAnswer((_) async {});
    builtTensors.add(value);
    return value;
  }

  setUp(() {
    durationPredictor = MockOrtSession();
    textEncoder = MockOrtSession();
    vectorEstimator = MockOrtSession();
    vocoder = MockOrtSession();
    builtTensors = [];
    style = VoiceStyle(MockOrtValue(), MockOrtValue(), const [], const []);

    durationOut = stubbedValue([0.1]); // 0.1s -> latentLen/dim of 1
    textEmbOut = stubbedValue(null); // used as an input tensor, never read
    vectorOut = stubbedValue([
      0.42,
    ]); // denoised, length latentDim*latentLen = 1
    wavOut = stubbedValue([0.1, 0.2]); // final samples

    when(
      () => durationPredictor.run(any()),
    ).thenAnswer((_) async => {'duration': durationOut});
    when(
      () => textEncoder.run(any()),
    ).thenAnswer((_) async => {'text_emb': textEmbOut});
    when(
      () => vectorEstimator.run(any()),
    ).thenAnswer((_) async => {'denoised': vectorOut});
    when(
      () => vocoder.run(any()),
    ).thenAnswer((_) async => {'wav': wavOut});
  });

  SupertonicTtsSession buildSession() => SupertonicTtsSession(
    cfgs: cfgs,
    textProcessor: const UnicodeProcessor.fromIndexer(<int, int>{}),
    durationPredictor: durationPredictor,
    textEncoder: textEncoder,
    vectorEstimator: vectorEstimator,
    vocoder: vocoder,
    floatTensorBuilder: (_, _) => trackBuilt(),
    intTensorBuilder: (_, _) => trackBuilt(),
    scalarTensorBuilder: (_, _) => trackBuilt(),
  );

  test(
    'synthesize runs the four models and returns the vocoder samples',
    () async {
      final result = await buildSession().synthesize(
        text: 'hi',
        language: 'na',
        style: style,
        totalStep: 1,
      );

      expect(result.samples, [0.1, 0.2]);
      expect(result.durationSeconds, closeTo(0.1, 1e-9));

      verify(() => durationPredictor.run(any())).called(1);
      verify(() => textEncoder.run(any())).called(1);
      verify(() => vectorEstimator.run(any())).called(1); // one denoising step
      verify(() => vocoder.run(any())).called(1);
    },
  );

  test('scales the duration by speed', () async {
    final result = await buildSession().synthesize(
      text: 'hi',
      language: 'na',
      style: style,
      totalStep: 1,
      speed: 2,
    );
    // 0.1s natural / 2x = 0.05s reported duration.
    expect(result.durationSeconds, closeTo(0.05, 1e-9));
  });

  test('disposes every tensor it creates and every model output', () async {
    await buildSession().synthesize(
      text: 'hi',
      language: 'na',
      style: style,
      totalStep: 1,
    );

    // Leak guard: each input tensor handed out by the builders is freed.
    expect(builtTensors, isNotEmpty);
    for (final tensor in builtTensors) {
      verify(() => tensor.dispose()).called(1);
    }
    // ...and every model-output OrtValue is freed too.
    verify(() => durationOut.dispose()).called(1);
    verify(() => textEmbOut.dispose()).called(1);
    verify(() => vectorOut.dispose()).called(1);
    verify(() => wavOut.dispose()).called(1);

    // The cached voice-style tensors are owned by the engine, not freed here.
    verifyNever(() => style.ttl.dispose());
    verifyNever(() => style.dp.dispose());
  });

  test('returns empty audio when there is nothing to synthesize', () async {
    final result = await buildSession().synthesize(
      text: '',
      language: 'na',
      style: style,
      totalStep: 1,
    );
    expect(result.samples, isEmpty);
    expect(result.durationSeconds, 0);
    verifyNever(() => vocoder.run(any()));
  });
}
