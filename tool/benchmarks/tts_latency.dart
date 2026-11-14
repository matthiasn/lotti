// Time to first audio byte (TTFAB) of the cloud voices lotti can speak with,
// measured against the live APIs. Not part of the app or the test suite.
//
//   fvm dart run tool/benchmarks/tts_latency.dart [--env .env] [--reps 3]
//       [--models eleven_v4_turbo,eleven_v3] [--modes rest,stream,ws]
//       [--voxtral] [--out results.json] [--audio-dir dir]
//
// Keys come from the `.env` file (`ELEVEN_LABS_API_KEY`, `MISTRAL_API_KEY`)
// and are only ever sent as request headers: nothing here prints them.
// The texts are fixed fixtures; every request spends provider quota, which
// the `character-cost` header reports per ElevenLabs request.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

const _elevenBase = 'https://api.elevenlabs.io/v1';
const _mistralBase = 'https://api.mistral.ai/v1';

/// Sarah, a premade multilingual voice every account has.
const _voice = 'EXAVITQu4vr4xnSDxMaL';
const _voxtralModel = 'voxtral-mini-tts-3-0';

/// 24 kHz, 16-bit mono: the rate both providers answer lotti with.
const _bytesPerSecond = 48000;

const texts = <String, String>{
  'short': 'Nothing is overdue.',
  'conversational':
      'You finished three tasks today, and the report for Friday is '
      'almost done. Want me to move the rest to tomorrow?',
  'long':
      'Here is your week so far. You logged eleven hours on the garden '
      'project, most of it on Tuesday and Wednesday, and two of its tasks are '
      'now closed. The reading list is untouched since Monday. Two tasks are '
      'due tomorrow: the insurance letter and the quarterly summary. The '
      'letter needs about twenty minutes; the summary is larger, so it may '
      'be worth starting tonight. Your calendar is free after four, which '
      'leaves room for both if nothing else comes up.',
};

class Sample {
  Sample(this.provider, this.model, this.mode, this.text);
  final String provider;
  final String model;
  final String mode;
  final String text;
  int? headersMs;
  int? firstAudioMs;
  int? totalMs;

  /// When lotti would start playing: two seconds buffered or the stream's
  /// end, whichever came first.
  int? playableMs;
  double? audioSeconds;

  /// The pre-roll a player needs to never run dry when it starts at the
  /// first audio byte: 0 means audio always arrived ahead of playback.
  int? bufferNeededMs;
  String? cost;
  String? error;

  Map<String, Object?> toJson() => {
    'provider': provider,
    'model': model,
    'mode': mode,
    'text': text,
    'chars': texts[text]!.length,
    'headersMs': headersMs,
    'firstAudioMs': firstAudioMs,
    'totalMs': totalMs,
    'playableMs': playableMs,
    'audioSeconds': audioSeconds,
    'bufferNeededMs': bufferNeededMs,
    'cost': cost,
    'error': error,
  };
}

/// Follows a growing WAV or raw PCM byte stream: when its first audio byte
/// arrived and, for a player started then, the longest it would starve.
class AudioClock {
  AudioClock(this._stopwatch, {required this.wav});
  final Stopwatch _stopwatch;
  final bool wav;
  final _header = BytesBuilder();
  final audio = BytesBuilder();
  bool _inData = false;
  int? firstAudioMs;

  /// When two seconds of audio had arrived: where lotti's streamed playback
  /// (`GrowingSpeechClip.playableBytes`) starts, unless the clip is shorter.
  int? leadMs;
  static const int _leadBytes = 2 * _bytesPerSecond;
  int bufferNeededMs = 0;

  void add(List<int> bytes) {
    var chunk = bytes;
    if (wav && !_inData) {
      _header.add(chunk);
      final all = _header.toBytes();
      final dataAt = _dataOffset(all);
      if (dataAt == null) return;
      _inData = true;
      chunk = all.sublist(dataAt);
    }
    if (chunk.isEmpty) return;
    final now = _stopwatch.elapsedMilliseconds;
    firstAudioMs ??= now;
    if (audio.length + chunk.length >= _leadBytes) leadMs ??= now;
    final playedMs = now - firstAudioMs!;
    final availableMs = audio.length * 1000 ~/ _bytesPerSecond;
    if (playedMs > availableMs && playedMs - availableMs > bufferNeededMs) {
      bufferNeededMs = playedMs - availableMs;
    }
    audio.add(chunk);
  }

  double get seconds => audio.length / _bytesPerSecond;

  /// Offset of the first sample after the `data` chunk header, or `null`
  /// while the header has not fully arrived.
  static int? _dataOffset(Uint8List b) {
    var i = 12;
    while (i + 8 <= b.length) {
      final id = ascii.decode(b.sublist(i, i + 4), allowInvalid: true);
      final size = ByteData.sublistView(
        b,
        i + 4,
        i + 8,
      ).getUint32(0, Endian.little);
      if (id == 'data') return i + 8 <= b.length ? i + 8 : null;
      i += 8 + size;
    }
    return null;
  }
}

HttpClient _newClient() =>
    HttpClient()..idleTimeout = const Duration(seconds: 30);

/// Replaced after a timeout, so a request still running cannot share the
/// next sample's connection.
HttpClient _http = _newClient();

/// The socket of the sample in progress, closed if it times out.
WebSocket? _socket;
late final String _elevenKey;
String? _mistralKey;
String? _audioDir;

/// The WAV parsing the timings rest on: audio found past an extra chunk,
/// in pieces that split the header.
void _selfCheck() {
  final sw = Stopwatch()..start();
  final clock = AudioClock(sw, wav: true);
  final list = [...ascii.encode('LIST'), 4, 0, 0, 0, 1, 2, 3, 4];
  final header = [
    ...ascii.encode('RIFF'), 0, 0, 0, 0, ...ascii.encode('WAVEfmt '), //
    16, 0, 0, 0, ...List.filled(16, 0), ...list,
    ...ascii.encode('data'), 0xFF, 0xFF, 0xFF, 0xFF,
  ];
  clock
    ..add(header.sublist(0, 30))
    ..add([...header.sublist(30), 7, 7])
    ..add([7, 7]);
  if (clock.audio.length != 4 || clock.firstAudioMs == null) {
    throw StateError('AudioClock self-check failed: ${clock.audio.length}');
  }
}

Future<void> main(List<String> args) async {
  _selfCheck();
  final opts = _parse(args);
  final env = _readEnv(opts['env'] ?? '.env');
  _elevenKey =
      env['ELEVEN_LABS_API_KEY'] ??
      (throw StateError('No ELEVEN_LABS_API_KEY'));
  _mistralKey = env['MISTRAL_API_KEY'];
  _audioDir = opts['audio-dir'];
  if (_audioDir != null) Directory(_audioDir!).createSync(recursive: true);
  final reps = int.parse(opts['reps'] ?? '3');
  final models =
      (opts['models'] ??
              'eleven_v4_turbo,eleven_v4,eleven_v3,eleven_flash_v2_5,eleven_multilingual_v2')
          .split(',');
  final modes = (opts['modes'] ?? 'rest,stream,ws').split(',');

  // Looked up once, before the warm-up, and bounded: without it Voxtral is
  // left out, not the whole run.
  String? voxtralVoice;
  if (opts.containsKey('voxtral') && _mistralKey != null) {
    try {
      voxtralVoice = await _voxtralVoice().timeout(const Duration(seconds: 20));
    } on Object catch (e) {
      // A lookup that hangs is ended with its client.
      _http.close(force: true);
      _http = _newClient();
      stderr.writeln('Voxtral left out, no voice: $e');
    }
  }

  // Warm the connection, as the app's long-lived client is, and time a
  // round trip that synthesizes nothing.
  final rtt = <int>[];
  for (var i = 0; i < 4; i++) {
    final sw = Stopwatch()..start();
    final req = await _http.getUrl(Uri.parse('$_elevenBase/models'));
    req.headers.set('xi-api-key', _elevenKey);
    await (await req.close()).drain<void>();
    rtt.add(sw.elapsedMilliseconds);
  }
  stderr.writeln(
    'ElevenLabs GET models round trip (warm): ${rtt.skip(1).toList()} ms',
  );

  final samples = <Sample>[];
  for (var rep = 0; rep < reps; rep++) {
    for (final text in texts.keys) {
      for (final model in models) {
        for (final mode in modes) {
          final s = Sample('elevenlabs', model, mode, text);
          await _guard(
            s,
            () => switch (mode) {
              'rest' => _elevenRest(s, save: rep == 0),
              'stream' => _elevenStream(s),
              'ws' => _elevenWs(s),
              'dialogue' => _elevenWs(s, dialogue: true),
              _ => throw ArgumentError(mode),
            },
          );
          samples.add(s);
          _report(s);
        }
      }
      if (voxtralVoice case final voice?) {
        for (final mode in ['rest', 'stream']) {
          final s = Sample('mistral', _voxtralModel, mode, text);
          await _guard(s, () => _voxtral(s, voice, stream: mode == 'stream'));
          samples.add(s);
          _report(s);
        }
      }
    }
  }
  _http.close();
  final out = opts['out'];
  final json = const JsonEncoder.withIndent('  ').convert({
    'measuredAt': DateTime.now().toUtc().toIso8601String(),
    'elevenLabsRoundTripMs': rtt.skip(1).toList(),
    'samples': samples.map((s) => s.toJson()).toList(),
  });
  if (out != null) File(out).writeAsStringSync(json);
  stdout.writeln(_markdown(samples));
}

Future<void> _guard(Sample s, Future<void> Function() run) async {
  try {
    await run().timeout(const Duration(seconds: 90));
  } on TimeoutException catch (e) {
    // A timeout does not stop the request: end it, so it cannot skew the
    // samples after it.
    _http.close(force: true);
    _http = _newClient();
    await _socket?.close();
    s.error = e.toString().split('\n').first;
  } on Object catch (e) {
    s.error = e.toString().split('\n').first;
  } finally {
    _socket = null;
  }
}

void _report(Sample s) => stderr.writeln(
  '${s.provider}/${s.model}/${s.mode}/${s.text}: '
  '${s.error ?? 'first audio ${s.firstAudioMs} ms, total ${s.totalMs} ms, '
          '${s.audioSeconds?.toStringAsFixed(1)} s audio, buffer ${s.bufferNeededMs} ms, '
          'cost ${s.cost}'}',
);

Future<HttpClientResponse> _post(
  Uri uri,
  Map<String, String> headers,
  Object body,
  Sample s,
  Stopwatch sw,
) async {
  final req = await _http.postUrl(uri);
  headers.forEach(req.headers.set);
  req
    ..headers.contentType = ContentType.json
    ..add(utf8.encode(jsonEncode(body)));
  final res = await req.close();
  s
    ..headersMs = sw.elapsedMilliseconds
    ..cost = res.headers.value('character-cost');
  if (res.statusCode != 200) {
    final reason = await utf8.decodeStream(res);
    throw HttpException(
      'HTTP ${res.statusCode}: ${reason.length > 300 ? reason.substring(0, 300) : reason}',
    );
  }
  return res;
}

/// What lotti does today: the whole clip as `wav_24000`, played once it
/// has fully arrived.
Future<void> _elevenRest(Sample s, {required bool save}) async {
  final sw = Stopwatch()..start();
  final res = await _post(
    Uri.parse('$_elevenBase/text-to-speech/$_voice?output_format=wav_24000'),
    {'xi-api-key': _elevenKey, 'Accept': 'audio/wav'},
    {'text': texts[s.text], 'model_id': s.model},
    s,
    sw,
  );
  final clock = AudioClock(sw, wav: true);
  await res.forEach(clock.add);
  _finish(s, clock, sw);
  if (save && _audioDir != null) {
    File(
      '$_audioDir/${s.model}_${s.text}.pcm',
    ).writeAsBytesSync(clock.audio.toBytes());
  }
}

/// `POST …/stream`: raw 24 kHz PCM, sent while it is made.
Future<void> _elevenStream(Sample s) async {
  final sw = Stopwatch()..start();
  final res = await _post(
    Uri.parse(
      '$_elevenBase/text-to-speech/$_voice/stream?output_format=pcm_24000',
    ),
    {'xi-api-key': _elevenKey},
    {'text': texts[s.text], 'model_id': s.model},
    s,
    sw,
  );
  final clock = AudioClock(sw, wav: false);
  await res.forEach(clock.add);
  _finish(s, clock, sw);
}

/// The input-streaming WebSocket (`stream-input`): the text goes in as an
/// LLM would write it — a word every 60 ms — and the clock starts at the
/// first word sent, so TTFAB here is what a reply streamed into the voice
/// would hear.
///
/// [dialogue] uses `text-to-dialogue/stream-input` instead, the only socket
/// that takes `eleven_v3` and the v4 family: voices are registered first,
/// text goes in as `inputs`, and `close_socket` ends it.
Future<void> _elevenWs(Sample s, {bool dialogue = false}) async {
  final wss = _elevenBase.replaceFirst('https', 'wss');
  final uri =
      '$wss/${dialogue ? 'text-to-dialogue' : 'text-to-speech/$_voice'}/stream-input'
      '?model_id=${s.model}&output_format=pcm_24000';
  final ws = _socket = await WebSocket.connect(
    uri,
    headers: {'xi-api-key': _elevenKey},
  );
  final sw = Stopwatch();
  final clock = AudioClock(sw, wav: false);
  final done = Completer<void>();
  ws.listen(
    (message) {
      final event = jsonDecode(message as String) as Map<String, dynamic>;
      if (event['audio'] case final String audio when audio.isNotEmpty) {
        clock.add(base64.decode(audio));
      }
      if (event['error'] != null ||
          event['message'] != null && event['audio'] == null) {
        s.error ??= 'ws: ${event['error'] ?? event['message']}';
      }
      final last = event['isFinal'] == true || event['is_final'] == true;
      if (last && !done.isCompleted) done.complete();
    },
    onDone: () {
      if (ws.closeCode != null &&
          ws.closeCode != 1000 &&
          ws.closeReason?.isNotEmpty == true) {
        s.error ??= 'ws closed ${ws.closeCode}: ${ws.closeReason}';
      }
      if (!done.isCompleted) done.complete();
    },
    onError: (Object e) {
      s.error ??= 'ws: $e';
      if (!done.isCompleted) done.complete();
    },
  );
  ws.add(
    jsonEncode(
      dialogue
          ? {
              'voices': [_voice],
            }
          : {'text': ' '},
    ),
  );
  sw.start();
  for (final word in texts[s.text]!.split(' ')) {
    ws.add(
      jsonEncode(
        dialogue
            ? {
                'inputs': [
                  {'text': '$word ', 'voice_id': _voice},
                ],
              }
            : {'text': '$word '},
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 60));
  }
  if (dialogue) {
    ws.add(jsonEncode({'close_socket': true}));
  } else {
    ws
      ..add(jsonEncode({'text': '', 'flush': true}))
      ..add(jsonEncode({'text': ''}));
  }
  await done.future;
  await ws.close();
  _finish(s, clock, sw);
}

Future<String> _voxtralVoice() async {
  final req = await _http.getUrl(
    Uri.parse('$_mistralBase/audio/voices?limit=100&type=all'),
  );
  req.headers.set('Authorization', 'Bearer $_mistralKey');
  final res = await req.close();
  final body = jsonDecode(await utf8.decodeStream(res)) as Map<String, dynamic>;
  final items = (body['items'] ?? body['data'] ?? body['voices']) as List;
  final english = items.cast<Map<String, dynamic>>().where(
    (v) => '${v['languages'] ?? v['language'] ?? ''}'.contains('en'),
  );
  return ((english.isEmpty ? items.first : english.first) as Map)['id']
      as String;
}

/// Voxtral as lotti calls it: the whole clip in a JSON body, or with
/// `stream: true` as server-sent events of base64 WAV pieces.
Future<void> _voxtral(Sample s, String voice, {required bool stream}) async {
  final sw = Stopwatch()..start();
  final res = await _post(
    Uri.parse('$_mistralBase/audio/speech'),
    {
      'Authorization': 'Bearer $_mistralKey',
      'Accept': stream ? 'text/event-stream' : 'application/json',
    },
    {
      'model': _voxtralModel,
      'input': texts[s.text],
      'voice_id': voice,
      'response_format': 'wav',
      'stream': ?(stream ? true : null),
    },
    s,
    sw,
  );
  final clock = AudioClock(sw, wav: true);
  if (stream) {
    await for (final line
        in res.transform(utf8.decoder).transform(const LineSplitter())) {
      if (!line.startsWith('data:')) continue;
      final data = line.substring(5).trim();
      if (data == '[DONE]') break;
      final event = jsonDecode(data) as Map<String, dynamic>;
      if (event['type'] == 'speech.audio.done') break;
      if (event['audio_data'] case final String audio) {
        clock.add(base64.decode(audio));
      }
    }
  } else {
    final body =
        jsonDecode(await utf8.decodeStream(res)) as Map<String, dynamic>;
    clock.add(base64.decode(body['audio_data'] as String));
  }
  _finish(s, clock, sw);
}

void _finish(Sample s, AudioClock clock, Stopwatch sw) {
  s
    ..firstAudioMs = clock.firstAudioMs
    ..totalMs = sw.elapsedMilliseconds
    ..playableMs = clock.leadMs ?? sw.elapsedMilliseconds
    ..audioSeconds = clock.seconds
    ..bufferNeededMs = clock.bufferNeededMs;
  if (clock.firstAudioMs == null) s.error ??= 'no audio';
}

String _markdown(List<Sample> samples) {
  final rows = <String>[
    '| Provider | Model | Mode | Text | First audio (median, min–max) | Playable in lotti (median) | Whole (median) | Pre-roll needed (max) | Cost |',
    '|---|---|---|---|---|---|---|---|---|',
  ];
  final groups = <String, List<Sample>>{};
  for (final s in samples) {
    groups
        .putIfAbsent('${s.provider}|${s.model}|${s.mode}|${s.text}', () => [])
        .add(s);
  }
  for (final MapEntry(:key, :value) in groups.entries) {
    final ok = value.where((s) => s.error == null).toList();
    if (ok.isEmpty) {
      rows.add(
        '| ${key.replaceAll('|', ' | ')} | failed: ${value.first.error} | | | | |',
      );
      continue;
    }
    int median(List<int> xs) {
      xs.sort();
      final mid = xs.length ~/ 2;
      return xs.length.isOdd ? xs[mid] : ((xs[mid - 1] + xs[mid]) / 2).round();
    }

    final first = ok.map((s) => s.firstAudioMs!).toList()..sort();
    rows.add(
      '| ${key.replaceAll('|', ' | ')} | ${median(first)} ms (${first.first}–${first.last}) '
      '| ${median(ok.map((s) => s.mode == 'rest' ? s.totalMs! : s.playableMs!).toList())} ms '
      '| ${median(ok.map((s) => s.totalMs!).toList())} ms '
      '| ${ok.map((s) => s.bufferNeededMs!).reduce((a, b) => a > b ? a : b)} ms '
      '| ${ok.first.cost ?? '—'} |',
    );
  }
  return rows.join('\n');
}

Map<String, String> _readEnv(String path) => {
  for (final line in File(path).readAsLinesSync())
    if (line.contains('=') && !line.trimLeft().startsWith('#'))
      line.substring(0, line.indexOf('=')).trim(): line
          .substring(line.indexOf('=') + 1)
          .trim()
          .replaceAll(RegExp(r'''^["']|["']$'''), ''),
};

Map<String, String?> _parse(List<String> args) {
  final out = <String, String?>{};
  for (var i = 0; i < args.length; i++) {
    final name = args[i].replaceFirst('--', '');
    final hasValue = i + 1 < args.length && !args[i + 1].startsWith('--');
    out[name] = hasValue ? args[++i] : null;
  }
  return out;
}
