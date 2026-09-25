import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/provenance/crypto/canonical_json.dart';
import 'package:lotti/features/provenance/model/envelope.dart';

import '../envelope_fixtures.dart';

Matcher get _formatError => throwsA(isA<EnvelopeFormatException>());

void main() {
  group('Envelope structure', () {
    test('the signing form is every member except the signature', () {
      final envelope = referenceEnvelope(
        signature: EnvelopeReference.signature,
      );

      expect(
        canonicalJson(envelope.toSigningJson()),
        EnvelopeReference.signingJson,
      );
      expect(canonicalJson(envelope.toJson()), EnvelopeReference.wireJson);
    });

    test('an unsigned envelope has no wire form', () {
      expect(() => referenceEnvelope().toJson(), _formatError);
    });

    test('rejects a version this code does not know', () {
      expect(
        () => Envelope(
          version: 2,
          kind: EnvelopeKind.record,
          deviceId: EnvelopeReference.deviceId,
          seq: 0,
          prev: null,
          causalRefs: const [],
          vectorClock: const {},
          author: const EnvelopeAuthor(type: AuthorType.user, id: 'user'),
          claimedTime: DateTime.utc(2026),
          contentCommitment: null,
          refs: const {},
        ),
        _formatError,
      );
    });

    test('equal envelopes and authors hash equally', () {
      final a = referenceEnvelope(signature: EnvelopeReference.signature);
      final b = referenceEnvelope(signature: EnvelopeReference.signature);
      expect({a, b}, hasLength(1));
      expect(a.author.hashCode, b.author.hashCode);
      expect(a, isNot(referenceEnvelope(seq: 2)));
    });

    test('a format error names the problem', () {
      expect(
        const EnvelopeFormatException('seq is negative').toString(),
        'EnvelopeFormatException: seq is negative',
      );
    });

    test('a genesis envelope has seq 0 and no prev', () {
      final genesis = referenceEnvelope(seq: 0, prev: null);
      expect(genesis.toSigningJson()['prev'], isNull);
    });

    for (final (label, build) in <(String, Envelope Function())>[
      ('seq 0 with a prev', () => referenceEnvelope(seq: 0)),
      ('seq above 0 without a prev', () => referenceEnvelope(prev: null)),
      ('a negative seq', () => referenceEnvelope(seq: -1, prev: null)),
      ('a short device id', () => referenceEnvelope(deviceId: 'ab')),
      (
        'an upper-case device id',
        () => referenceEnvelope(
          deviceId: EnvelopeReference.deviceId.toUpperCase(),
        ),
      ),
      ('a prev that is not a hash', () => referenceEnvelope(prev: 'x' * 64)),
      (
        'unsorted causal refs',
        () => referenceEnvelope(
          causalRefs: EnvelopeReference.causalRefs.reversed.toList(),
        ),
      ),
      (
        'duplicate causal refs',
        () => referenceEnvelope(
          causalRefs: [
            EnvelopeReference.causalRefs.first,
            EnvelopeReference.causalRefs.first,
          ],
        ),
      ),
      (
        'a negative clock counter',
        () => referenceEnvelope(vectorClock: const {'host-a': -1}),
      ),
      (
        'a local claimed time',
        () => referenceEnvelope(claimedTime: DateTime(2026, 9, 26)),
      ),
      (
        'a claimed time below millisecond precision',
        () => referenceEnvelope(
          claimedTime: DateTime.utc(2026, 9, 26, 8, 30, 0, 0, 1),
        ),
      ),
      (
        'a claimed time after year 9999',
        () => referenceEnvelope(claimedTime: DateTime.utc(10000)),
      ),
      (
        'a claimed time before year 0',
        () => referenceEnvelope(claimedTime: DateTime.utc(-1)),
      ),
      (
        'a commitment that is not a hash',
        () => referenceEnvelope(contentCommitment: 'abc'),
      ),
      (
        'refs holding a double',
        () => referenceEnvelope(refs: const {'x': 0.5}),
      ),
      ('a malformed signature', () => referenceEnvelope(signature: 'ab')),
      (
        'an empty author id',
        () => referenceEnvelope(
          author: const EnvelopeAuthor(type: AuthorType.agent, id: ''),
        ),
      ),
      (
        'an author context hash that is not a hash',
        () => referenceEnvelope(
          author: const EnvelopeAuthor(
            type: AuthorType.agent,
            id: 'task-agent',
            model: 'model-x',
            contextHash: 'nope',
          ),
        ),
      ),
    ]) {
      test('rejects $label', () => expect(build, _formatError));
    }
  });

  group('Envelope.fromJson', () {
    Map<String, Object?> wire() =>
        jsonDecode(EnvelopeReference.wireJson) as Map<String, Object?>;

    test('decodes the reference envelope', () {
      expect(
        Envelope.fromJson(wire()),
        referenceEnvelope(signature: EnvelopeReference.signature),
      );
    });

    test('keeps an agent author with its model and context hash', () {
      const author = EnvelopeAuthor(
        type: AuthorType.agent,
        id: 'task-agent',
        model: 'model-x',
        contextHash: EnvelopeReference.prev,
      );
      final json = wire()..['author'] = author.toJson();
      expect(Envelope.fromJson(json).author, author);
    });

    for (final (label, mutate)
        in <(String, void Function(Map<String, Object?>))>[
          ('a missing member', (m) => m.remove('refs')),
          ('an unknown member', (m) => m['extra'] = 1),
          ('a missing signature', (m) => m.remove('signature')),
          ('an unknown kind', (m) => m['kind'] = 'rumour'),
          (
            'an unknown author type',
            (m) => m['author'] = {'type': 'ghost', 'id': 'x'},
          ),
          (
            'an author model written as null',
            (m) => m['author'] = {'type': 'user', 'id': 'user', 'model': null},
          ),
          (
            'a claimed time without milliseconds',
            (m) {
              m['claimed_time'] = '2026-09-26T08:30:00Z';
            },
          ),
          (
            'an impossible claimed time',
            (m) {
              m['claimed_time'] = '2026-02-30T08:30:00.000Z';
            },
          ),
          ('a string seq', (m) => m['seq'] = '1'),
          ('an author that is not an object', (m) => m['author'] = 'user'),
          ('causal refs that are not a list', (m) => m['causal_refs'] = 'x'),
          ('a device id that is not a string', (m) => m['device_id'] = 7),
        ]) {
      test('rejects $label', () {
        final json = wire();
        mutate(json);
        expect(() => Envelope.fromJson(json), _formatError);
      });
    }
  });

  test('rejects an object with a non-string key', () {
    expect(
      () => Envelope.fromJson(const <Object?, Object?>{1: 'x'}),
      _formatError,
    );
  });

  group('claimed time', () {
    test('formats UTC at millisecond precision', () {
      expect(
        formatClaimedTime(DateTime.utc(2026, 1, 2, 3, 4, 5, 6)),
        '2026-01-02T03:04:05.006Z',
      );
    });
  });

  glados.Glados<DateTime>(
    glados.any.dateTime,
    glados.ExploreConfig(numRuns: 200),
  ).test(
    'a claimed time round-trips through its one spelling',
    (time) {
      final utc = time.toUtc();
      final millis = DateTime.fromMillisecondsSinceEpoch(
        utc.millisecondsSinceEpoch,
        isUtc: true,
      );
      if (millis.year < 0 || millis.year > 9999) return;
      expect(parseClaimedTime(formatClaimedTime(millis)), millis);
    },
    tags: 'glados',
  );
}
