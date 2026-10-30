import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/on_device_embedding/gemma_embedder.dart';
import 'package:lotti/features/ai/on_device_embedding/gemma_tokenizer.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import 'tokenizer_json.dart';

/// One tensor the embedder built, with what it was built from.
typedef _Built = ({Int64List data, List<int> shape, MockOrtValue value});

void main() {
  setUpAll(() {
    registerFallbackValue(<String, OrtValue>{});
    registerFallbackValue(OrtSessionOptions());
  });

  final tokenizerSource = tokenizerJson(
    tokens: [
      for (final unit in 'abcdefghijklmnopqrstuvwxyz:|▁'.split('')) unit,
    ],
  );
  final tokenizer = GemmaTokenizer.fromTokenizerJson(tokenizerSource);

  late MockOrtSession session;
  late List<_Built> built;
  late MockOrtValue pooled;
  late MockOrtValue hidden;

  /// A pooled output of [GemmaEmbedder.dimensions] values, [head] first.
  List<double> pooledValues(List<double> head) => [
    ...head,
    ...List.filled(GemmaEmbedder.dimensions - head.length, 0),
  ];

  /// Stands in for the native tensor allocation, recording what it built.
  Future<OrtValue> buildTensor(Int64List data, List<int> shape) async {
    final value = MockOrtValue();
    when(value.dispose).thenAnswer((_) async {});
    built.add((data: data, shape: shape, value: value));
    return value;
  }

  GemmaEmbedder embedder() =>
      GemmaEmbedder(tokenizer, session, int64Tensor: buildTensor);

  setUp(() {
    session = MockOrtSession();
    built = [];
    pooled = MockOrtValue();
    hidden = MockOrtValue();
    for (final output in [pooled, hidden]) {
      when(output.dispose).thenAnswer((_) async {});
    }
    when(
      pooled.asFlattenedList,
    ).thenAnswer((_) async => pooledValues([3, 4]));
    when(() => session.run(any())).thenAnswer(
      (_) async => {'last_hidden_state': hidden, 'sentence_embedding': pooled},
    );
  });

  test(
    'embeds a document with the document prompt, as a unit vector',
    () async {
      final vector = await embedder().embedDocument('abc');

      final ids = tokenizer.encode('title: none | text: abc');
      expect(built[0].data, ids);
      expect(built[0].shape, [1, ids.length]);
      expect(built[1].data, List.filled(ids.length, 1));
      expect(built[1].shape, [1, ids.length]);
      final feeds =
          verify(() => session.run(captureAny())).captured.single
              as Map<String, OrtValue>;
      expect(feeds, {
        'input_ids': built[0].value,
        'attention_mask': built[1].value,
      });

      expect(vector, hasLength(GemmaEmbedder.dimensions));
      expect(vector.sublist(0, 3), [closeTo(0.6, 1e-6), closeTo(0.8, 1e-6), 0]);
    },
  );

  test('embeds a query with the query prompt', () async {
    await embedder().embedQuery('abc');

    expect(
      built[0].data,
      tokenizer.encode('task: search result | query: abc'),
    );
  });

  test('cuts a long text at the model limit', () async {
    await embedder().embedDocument('a' * 2000);

    expect(built[0].data, hasLength(GemmaEmbedder.maxTokens));
    expect(built[0].data.last, tokenizer.eosId);
  });

  test('disposes its inputs and every output', () async {
    await embedder().embedDocument('abc');

    for (final tensor in built) {
      verify(tensor.value.dispose).called(1);
    }
    verify(pooled.dispose).called(1);
    verify(hidden.dispose).called(1);
  });

  group('fails, still disposing every tensor, when the model gives', () {
    Future<void> expectFailure() async {
      await expectLater(embedder().embedDocument('abc'), throwsStateError);
      for (final tensor in built) {
        verify(tensor.value.dispose).called(1);
      }
    }

    test('no sentence_embedding', () async {
      when(
        () => session.run(any()),
      ).thenAnswer((_) async => {'last_hidden_state': hidden});

      await expectFailure();
      verify(hidden.dispose).called(1);
    });

    test('another width', () async {
      when(pooled.asFlattenedList).thenAnswer((_) async => [1.0, 2.0]);

      await expectFailure();
      verify(pooled.dispose).called(1);
    });

    test('a zero vector', () async {
      when(pooled.asFlattenedList).thenAnswer((_) async => pooledValues([]));

      await expectFailure();
    });

    for (final value in [double.nan, double.infinity, 1e39]) {
      test('a non-finite value ($value)', () async {
        when(
          pooled.asFlattenedList,
        ).thenAnswer((_) async => pooledValues([1, value]));

        await expectFailure();
      });
    }
  });

  test('disposing the embedder closes its session', () async {
    when(session.close).thenAnswer((_) async {});

    await embedder().dispose();

    verify(session.close).called(1);
  });

  test('loads the tokenizer and the q4 model from its directory', () async {
    final directory = Directory.systemTemp.createTempSync('gemma_embedder');
    addTearDown(() => directory.deleteSync(recursive: true));
    File(
      '${directory.path}/${GemmaEmbedder.tokenizerFile}',
    ).writeAsStringSync(jsonEncode(tokenizerSource));
    final runtime = MockOnnxRuntime();
    when(
      () => runtime.createSession(any(), options: any(named: 'options')),
    ).thenAnswer((_) async => session);

    final loaded = await GemmaEmbedder.load(
      directory.path,
      runtime: runtime,
      int64Tensor: buildTensor,
    );
    await loaded.embedQuery('abc');

    // The tokenizer came from the file.
    expect(
      built[0].data,
      tokenizer.encode('task: search result | query: abc'),
    );

    final captured = verify(
      () => runtime.createSession(
        captureAny(),
        options: captureAny(named: 'options'),
      ),
    ).captured;
    expect(captured[0], '${directory.path}/onnx/model_q4.onnx');
    final options = captured[1] as OrtSessionOptions;
    expect(options.intraOpNumThreads, inInclusiveRange(1, 4));
    expect(options.interOpNumThreads, 1);
    verify(() => session.run(any())).called(1);
  });
}
