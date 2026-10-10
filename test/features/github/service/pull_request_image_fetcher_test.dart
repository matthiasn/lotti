import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/github/service/pull_request_image_fetcher.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  const url = 'https://pub-example.r2.dev/shots/desktop-dark.png';
  final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2, 3]);

  late MockHttpClient client;
  late PullRequestImageFetcher fetcher;

  /// The requests [client] was sent, in order.
  final sent = <http.BaseRequest>[];

  setUpAll(registerAllFallbackValues);

  setUp(() {
    sent.clear();
    client = MockHttpClient();
    fetcher = PullRequestImageFetcher(client: client, maxBytes: 16);
  });

  /// Answers every request with [respond], recording it.
  void answer(http.StreamedResponse Function(http.BaseRequest) respond) {
    when(() => client.send(any())).thenAnswer((invocation) async {
      final request = invocation.positionalArguments.first as http.BaseRequest;
      sent.add(request);
      return respond(request);
    });
  }

  http.StreamedResponse ok(
    List<int> bytes, {
    Map<String, String> headers = const {'content-type': 'image/png'},
    int? contentLength,
  }) => http.StreamedResponse(
    Stream.value(bytes),
    200,
    headers: headers,
    contentLength: contentLength,
  );

  Future<PullRequestImageFailure> failureOf(Future<Uint8List> fetch) async {
    try {
      await fetch;
    } on PullRequestImageException catch (e) {
      return e.failure;
    }
    fail('fetched');
  }

  test(
    'fetches an https image once, without following redirects itself',
    () async {
      answer((_) => ok(png));

      expect(await fetcher.fetch(url), png);

      expect(sent.single.url, Uri.parse(url));
      expect(sent.single.followRedirects, isFalse);
      expect(fetcher.cached(url), png);
    },
  );

  test('a second fetch of the same URL is served from memory', () async {
    answer((_) => ok(png));

    await fetcher.fetch(url);
    expect(await fetcher.fetch(url), png);

    verify(() => client.send(any())).called(1);
  });

  test('two fetches in flight for one URL share one request', () async {
    final gate = Completer<http.StreamedResponse>();
    when(() => client.send(any())).thenAnswer((_) => gate.future);

    final first = fetcher.fetch(url);
    final second = fetcher.fetch(url);
    gate.complete(ok(png));

    expect(await first, png);
    expect(await second, png);
    verify(() => client.send(any())).called(1);
  });

  test(
    'follows an https redirect, and keeps the original URL as the key',
    () async {
      const moved = 'https://cdn.example/shots/desktop-dark.png';
      answer(
        (request) => request.url.toString() == url
            ? http.StreamedResponse(
                const Stream.empty(),
                302,
                headers: {'location': moved},
              )
            : ok(png),
      );

      expect(await fetcher.fetch(url), png);

      expect(sent.map((r) => r.url.toString()), [url, moved]);
      expect(fetcher.cached(url), png);
    },
  );

  test('a redirect off https is not followed', () async {
    answer(
      (_) => http.StreamedResponse(
        const Stream.empty(),
        302,
        headers: {'location': 'http://cdn.example/shot.png'},
      ),
    );

    expect(
      await failureOf(fetcher.fetch(url)),
      PullRequestImageFailure.notHttps,
    );
    expect(sent, hasLength(1));
  });

  test('too many redirects fail as a status failure', () async {
    answer(
      (request) => http.StreamedResponse(
        const Stream.empty(),
        302,
        headers: {'location': '${request.url}/again'},
      ),
    );

    expect(await failureOf(fetcher.fetch(url)), PullRequestImageFailure.status);
    expect(sent, hasLength(PullRequestImageFetcher.maxRedirects + 1));
  });

  for (final bad in [
    'http://pub-example.r2.dev/shot.png',
    'ftp://x/y.png',
    'shot.png',
    '',
  ]) {
    test("'$bad' is never requested", () async {
      answer((_) => ok(png));

      expect(
        await failureOf(fetcher.fetch(bad)),
        PullRequestImageFailure.notHttps,
      );
      expect(sent, isEmpty);
    });
  }

  test('a non-200 answer is a status failure, and is tried again', () async {
    answer((_) => http.StreamedResponse(const Stream.empty(), 404));

    expect(await failureOf(fetcher.fetch(url)), PullRequestImageFailure.status);
    expect(fetcher.cached(url), isNull);

    answer((_) => ok(png));
    expect(await fetcher.fetch(url), png);
  });

  test(
    'an answer that is not an image is refused by its content type',
    () async {
      answer(
        (_) => ok(png, headers: {'content-type': 'text/html; charset=utf-8'}),
      );

      expect(
        await failureOf(fetcher.fetch(url)),
        PullRequestImageFailure.notAnImage,
      );
    },
  );

  test('an answer without a content type is taken on its bytes', () async {
    answer((_) => ok(png, headers: const {}));

    expect(await fetcher.fetch(url), png);
  });

  test('a declared length over the limit is refused before reading', () async {
    answer((_) => ok(png, contentLength: 17));

    expect(
      await failureOf(fetcher.fetch(url)),
      PullRequestImageFailure.tooLarge,
    );
  });

  test('a body that grows past the limit is cut off', () async {
    answer(
      (_) => http.StreamedResponse(
        Stream.fromIterable([List.filled(10, 1), List.filled(10, 2)]),
        200,
        headers: {'content-type': 'image/png'},
      ),
    );

    expect(
      await failureOf(fetcher.fetch(url)),
      PullRequestImageFailure.tooLarge,
    );
  });

  test('a connection that fails is a network failure', () async {
    when(() => client.send(any())).thenThrow(http.ClientException('reset'));

    expect(
      await failureOf(fetcher.fetch(url)),
      PullRequestImageFailure.network,
    );
  });

  test('a body that breaks off is a network failure', () async {
    answer(
      (_) => http.StreamedResponse(
        Stream.error(http.ClientException('reset')),
        200,
        headers: {'content-type': 'image/png'},
      ),
    );

    expect(
      await failureOf(fetcher.fetch(url)),
      PullRequestImageFailure.network,
    );
  });

  test('a request that never answers times out as a network failure', () {
    fakeAsync((async) {
      when(
        () => client.send(any()),
      ).thenAnswer((_) => Completer<http.StreamedResponse>().future);
      final timed = PullRequestImageFetcher(
        client: client,
        timeout: const Duration(seconds: 5),
      );

      PullRequestImageFailure? failure;
      timed
          .fetch(url)
          .then(
            (_) {},
            onError: (Object e) {
              failure = (e as PullRequestImageException).failure;
            },
          );

      async.elapse(const Duration(seconds: 4));
      expect(failure, isNull);
      async.elapse(const Duration(seconds: 2));
      expect(failure, PullRequestImageFailure.network);
    });
  });

  test(
    'the memory kept is bounded: the least recently used image goes first',
    () async {
      final bounded = PullRequestImageFetcher(
        client: client,
        maxBytes: 16,
        cacheBytes: 20,
      );
      final a = Uint8List.fromList(List.filled(8, 0xA));
      final b = Uint8List.fromList(List.filled(8, 0xB));
      final c = Uint8List.fromList(List.filled(8, 0xC));
      const urlA = 'https://x.example/a.png';
      const urlB = 'https://x.example/b.png';
      const urlC = 'https://x.example/c.png';
      answer(
        (request) => ok(switch (request.url.toString()) {
          urlA => a,
          urlB => b,
          _ => c,
        }),
      );

      await bounded.fetch(urlA);
      await bounded.fetch(urlB);
      // A is used again, so B is the one that has waited longest.
      await bounded.fetch(urlA);
      await bounded.fetch(urlC);

      expect(bounded.cached(urlA), a);
      expect(bounded.cached(urlB), isNull);
      expect(bounded.cached(urlC), c);
    },
  );

  test(
    'an image larger than the whole budget is served but not kept',
    () async {
      final bounded = PullRequestImageFetcher(
        client: client,
        maxBytes: 16,
        cacheBytes: 4,
      );
      answer((_) => ok(png));

      expect(await bounded.fetch(url), png);
      expect(bounded.cached(url), isNull);
    },
  );

  test('close closes the client', () {
    fetcher.close();
    verify(client.close).called(1);
  });
}
