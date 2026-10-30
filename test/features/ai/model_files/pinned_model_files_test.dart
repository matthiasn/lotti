import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotti/features/ai/model_files/pinned_model_files.dart';
import 'package:path/path.dart' as p;

/// A model of two files, the second in a subdirectory.
class _Model implements PinnedModel {
  _Model(this.files);

  @override
  String get id => 'model';

  @override
  String get revision => 'pinned';

  @override
  final List<PinnedModelFile> files;

  @override
  Uri uri(PinnedModelFile file) =>
      Uri.parse('https://models.example/resolve/$revision/${file.name}');
}

/// Timers created in its zone, which the test fires by hand: the download's
/// stall timeout runs on them, while its file IO stays real.
class _ManualTimers {
  final _timers = <_ManualTimer>[];

  /// Runs [body] with every timer it creates held here.
  Future<T> run<T>(Future<T> Function() body) => runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      createTimer: (self, parent, zone, duration, callback) {
        final timer = _ManualTimer(duration, () => zone.run(callback));
        _timers.add(timer);
        return timer;
      },
    ),
  );

  /// Fires every live timer of [duration], as if that long had passed.
  void elapse(Duration duration) {
    for (final timer in [..._timers]) {
      if (timer.isActive && timer.duration == duration) timer.fire();
    }
  }
}

class _ManualTimer implements Timer {
  _ManualTimer(this.duration, this._callback);

  final Duration duration;
  final void Function() _callback;
  bool _active = true;

  void fire() {
    _active = false;
    _callback();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => _active ? 0 : 1;
}

/// A client whose answer the test controls, recording the requests' abort
/// triggers.
class _StallingClient extends http.BaseClient {
  _StallingClient(this.respond);

  final Future<http.StreamedResponse> Function(http.BaseRequest) respond;
  final aborted = <Future<void>>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final trigger = (request as http.Abortable).abortTrigger;
    if (trigger != null) aborted.add(trigger);
    return respond(request);
  }
}

PinnedModelFile _file(String name, List<int> data) =>
    PinnedModelFile(name, data.length, sha256.convert(data).toString());

void main() {
  late Directory directory;
  final weights = utf8.encode('the weights of the model');
  final vocabulary = utf8.encode('vocab');
  final model = _Model([
    _file('onnx/model.onnx', weights),
    _file('tokenizer.json', vocabulary),
  ]);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pinned-model-test-');
  });
  tearDown(() async => directory.delete(recursive: true));

  PinnedModelFiles files(http.Client client) {
    final store = PinnedModelFiles(
      folder: 'models',
      client: client,
      supportDirectory: () async => directory,
    );
    addTearDown(store.close);
    return store;
  }

  /// Serves each file of [model] from its own URL, as [bodies] says.
  MockClient serving(Map<String, List<int>> bodies) => MockClient(
    (request) async {
      final name = request.url.path.replaceFirst('/resolve/pinned/', '');
      final body = bodies[name];
      return body == null
          ? http.Response('missing', 404)
          : http.Response.bytes(body, 200);
    },
  );

  test('keeps each model in its own folder, by id and revision', () async {
    expect(
      await files(serving({})).directory(model),
      p.join(directory.path, 'models', 'model', 'pinned'),
    );
  });

  test('sums the bytes of every file', () {
    expect(pinnedModelBytes(model), weights.length + vocabulary.length);
  });

  test('installs every file, reporting progress up to all of it', () async {
    final store = files(
      serving({'onnx/model.onnx': weights, 'tokenizer.json': vocabulary}),
    );
    final progress = <double>[];

    expect(await store.isInstalled(model), isFalse);
    final root = await store.install(model, onProgress: progress.add);

    expect(await File(p.join(root, 'onnx/model.onnx')).readAsBytes(), weights);
    expect(
      await File(p.join(root, 'tokenizer.json')).readAsBytes(),
      vocabulary,
    );
    expect(await store.isInstalled(model), isTrue);
    expect(progress.last, 1);
    expect(progress, orderedEquals([...progress]..sort()));
  });

  test('refuses a file whose checksum does not match', () async {
    final store = files(
      serving({
        'onnx/model.onnx': utf8.encode('other weights, same len.'),
        'tokenizer.json': vocabulary,
      }),
    );

    await expectLater(store.install(model), throwsFormatException);
    expect(await store.isInstalled(model), isFalse);
    final root = await store.directory(model);
    expect(File(p.join(root, 'onnx/model.onnx')).existsSync(), isFalse);
    expect(File(p.join(root, 'onnx/model.onnx.part')).existsSync(), isFalse);
  });

  test('refuses a failed request', () async {
    final store = files(serving({'tokenizer.json': vocabulary}));

    await expectLater(store.install(model), throwsA(isA<HttpException>()));
    expect(store.isDownloading(model), isFalse);
  });

  test('shares one download between concurrent installs, and cannot be '
      'removed while it runs', () async {
    final release = Completer<void>();
    var requests = 0;
    final store = files(
      MockClient((request) async {
        requests++;
        await release.future;
        return http.Response.bytes(
          request.url.path.endsWith('model.onnx') ? weights : vocabulary,
          200,
        );
      }),
    );

    final first = store.install(model);
    final second = store.install(model);
    expect(store.isDownloading(model), isTrue);
    await expectLater(store.remove(model), throwsStateError);
    release.complete();

    expect(await first, await second);
    expect(requests, model.files.length);
    expect(store.isDownloading(model), isFalse);
  });

  group('a stalled download is abandoned and can be tried again', () {
    // The default stall timeout, which these files do not override.
    const stall = Duration(seconds: 30);

    PinnedModelFiles stallingFiles(_StallingClient client) {
      final store = PinnedModelFiles(
        folder: 'models',
        client: client,
        supportDirectory: () async => directory,
      );
      addTearDown(store.close);
      return store;
    }

    /// Fires the stall timeout with the install's failure already awaited,
    /// so it is never reported as unhandled.
    Future<void> expectAbandoned(
      _ManualTimers timers,
      PinnedModelFiles store,
      _StallingClient client,
      Future<String> install,
    ) async {
      final failed = expectLater(install, throwsA(isA<TimeoutException>()));
      timers.elapse(stall);
      await failed;
      expect(store.isDownloading(model), isFalse);
      // The request was aborted, not left running.
      expect(client.aborted, isNotEmpty);
      await expectLater(client.aborted.first, completes);
      final root = await store.directory(model);
      expect(File(p.join(root, 'onnx/model.onnx.part')).existsSync(), isFalse);
    }

    test('when the server never answers', () async {
      final timers = _ManualTimers();
      // Completes once the request is out, which is when its wait begins:
      // the install's file IO before it is real and takes its own time.
      final asked = Completer<void>();
      final client = _StallingClient((_) {
        asked.complete();
        return Completer<http.StreamedResponse>().future;
      });
      final store = stallingFiles(client);

      final install = timers.run(() => store.install(model));
      await asked.future;
      await pumpEventQueue();
      expect(store.isDownloading(model), isTrue);

      await expectAbandoned(timers, store, client, install);
    });

    test('when its bytes stop coming', () async {
      final timers = _ManualTimers();
      final body = StreamController<List<int>>();
      addTearDown(body.close);
      final client = _StallingClient(
        (_) async => http.StreamedResponse(body.stream, 200),
      );
      final store = stallingFiles(client);
      // The first progress report means the first bytes went through the
      // guarded stream, which then waits on its stall timer.
      final received = Completer<void>();

      final install = timers.run(
        () => store.install(
          model,
          onProgress: (share) {
            if (share > 0 && !received.isCompleted) received.complete();
          },
        ),
      );
      body.add(weights.sublist(0, 4));
      await received.future;

      await expectAbandoned(timers, store, client, install);
    });
  });

  test('a caller that joins a running download hears its progress, starting '
      'with how far it has got', () async {
    final body = StreamController<List<int>>();
    final store = files(
      MockClient.streaming((request, _) async {
        if (request.url.path.endsWith('tokenizer.json')) {
          return http.StreamedResponse(Stream.value(vocabulary), 200);
        }
        return http.StreamedResponse(body.stream, 200);
      }),
    );
    final first = <double>[];
    final second = <double>[];
    // The starter's first report: the first bytes are counted.
    final counted = Completer<void>();

    final starting = store.install(
      model,
      onProgress: (share) {
        first.add(share);
        if (share > 0 && !counted.isCompleted) counted.complete();
      },
    );
    body.add(weights.sublist(0, 12));
    await counted.future;
    final joining = store.install(model, onProgress: second.add);
    body.add(weights.sublist(12));
    await body.close();

    expect(await joining, await starting);
    final total = pinnedModelBytes(model);
    // The joiner starts where the download stood when it joined.
    expect(second.first, closeTo(12 / total, 1e-9));
    expect(second.last, 1);
    expect(first.last, 1);

    // A later install is a download of its own: the first two callers hear
    // nothing more.
    final heard = (first.length, second.length);
    final later = <double>[];
    await store.install(model, onProgress: later.add);
    expect(later.last, 1);
    expect((first.length, second.length), heard);
  });

  test('removes the model from this device', () async {
    final store = files(
      serving({'onnx/model.onnx': weights, 'tokenizer.json': vocabulary}),
    );
    final root = await store.install(model);

    await store.remove(model);

    expect(Directory(root).existsSync(), isFalse);
    expect(await store.isInstalled(model), isFalse);
  });
}
