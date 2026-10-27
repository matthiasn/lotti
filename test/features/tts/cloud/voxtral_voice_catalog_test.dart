import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/tts/cloud/voxtral_voice_catalog.dart';

const _heidi = VoxtralVoice(
  id: 'v-de-1',
  name: 'Heidi',
  slug: 'heidi',
  gender: 'female',
  languages: ['de'],
  type: VoxtralVoiceType.preset,
);
const _emma = VoxtralVoice(
  id: 'v-en-1',
  name: 'Emma',
  languages: ['en-GB'],
  type: VoxtralVoiceType.preset,
);
const _klaus = VoxtralVoice(
  id: 'v-de-2',
  name: 'Klaus',
  languages: ['German'],
  type: VoxtralVoiceType.custom,
);

final _fetchedAt = DateTime.utc(2026, 10, 27, 9);

VoxtralVoiceCatalog _catalog([
  List<VoxtralVoice> voices = const [_emma, _heidi, _klaus],
]) => VoxtralVoiceCatalog(voices: voices, fetchedAt: _fetchedAt);

void main() {
  group('VoxtralVoice.fromJson', () {
    test('reads the documented voice fields', () {
      final voice = VoxtralVoice.fromJson(const {
        'id': 'v-de-1',
        'name': 'Heidi',
        'slug': 'heidi',
        'gender': 'female',
        'languages': ['de', 7, 'de-AT'],
        'type': 'preset',
        'age': 'adult',
        'user_id': null,
      });
      expect(voice.id, 'v-de-1');
      expect(voice.name, 'Heidi');
      expect(voice.slug, 'heidi');
      expect(voice.gender, 'female');
      // Non-string entries are dropped, strings kept verbatim.
      expect(voice.languages, ['de', 'de-AT']);
      expect(voice.type, VoxtralVoiceType.preset);
    });

    test('tolerates missing optional fields and an unknown type', () {
      final voice = VoxtralVoice.fromJson(const {
        'id': 'x',
        'name': 'X',
        'type': 'studio',
      });
      expect(voice.languages, isEmpty);
      expect(voice.slug, isNull);
      expect(voice.gender, isNull);
      expect(voice.type, VoxtralVoiceType.unknown);
    });

    test('rejects an entry without id or name', () {
      expect(
        () => VoxtralVoice.fromJson(const {'name': 'No id'}),
        throwsFormatException,
      );
      expect(
        () => VoxtralVoice.fromJson(const {'id': '', 'name': 'Empty id'}),
        throwsFormatException,
      );
      expect(
        () => VoxtralVoice.fromJson(const {'id': 'no-name'}),
        throwsFormatException,
      );
    });
  });

  group('VoxtralVoice.speaks', () {
    test('matches codes ignoring region and case, and English names', () {
      expect(_heidi.speaks('de'), isTrue);
      expect(_heidi.speaks('DE-at'), isTrue);
      expect(_heidi.speaks('de_CH'), isTrue);
      expect(_emma.speaks('en'), isTrue);
      expect(_klaus.speaks('de-DE'), isTrue);
      expect(_heidi.speaks('en'), isFalse);
      expect(_klaus.speaks('nl'), isFalse);
      expect(_heidi.speaks(''), isFalse);
    });

    test('matches a listed code that has no name alias', () {
      const voice = VoxtralVoice(id: 'p', name: 'P', languages: ['pl-PL']);
      expect(voice.speaks('pl'), isTrue);
      expect(voice.speaks('de'), isFalse);
    });
  });

  group('VoxtralVoiceCatalog.resolve', () {
    test('picks the language voice, a female preset before a custom', () {
      expect(_catalog().resolve(languageCode: 'de'), _heidi);
      expect(
        _catalog(const [_emma, _klaus, _heidi]).resolve(languageCode: 'de'),
        _heidi,
      );
      expect(
        _catalog(const [_emma, _klaus]).resolve(languageCode: 'de'),
        _klaus,
      );
    });

    test('defaults to the first female preset over earlier voices', () {
      const maleFirst = VoxtralVoice(
        id: 'v-de-m',
        name: 'Male',
        gender: 'male',
        languages: ['de'],
        type: VoxtralVoiceType.preset,
      );
      const femaleCustom = VoxtralVoice(
        id: 'v-de-fc',
        name: 'Clone',
        gender: 'Female',
        languages: ['de'],
        type: VoxtralVoiceType.custom,
      );
      expect(
        _catalog(const [
          maleFirst,
          femaleCustom,
          _heidi,
        ]).resolve(languageCode: 'de-AT'),
        _heidi,
      );
      // No female preset: the language's first voice of any kind.
      expect(
        _catalog(const [maleFirst, femaleCustom]).resolve(languageCode: 'de'),
        maleFirst,
      );
    });

    test('honours the preferred voice while the catalog still has it', () {
      expect(
        _catalog().resolve(languageCode: 'de', preferredVoiceId: 'v-de-2'),
        _klaus,
      );
      // A deliberate choice wins even across languages.
      expect(
        _catalog().resolve(languageCode: 'de', preferredVoiceId: 'v-en-1'),
        _emma,
      );
    });

    test('falls back to the language default when the preference is gone', () {
      expect(
        _catalog().resolve(languageCode: 'de', preferredVoiceId: 'deleted'),
        _heidi,
      );
    });

    test('returns null rather than a voice for another language', () {
      expect(_catalog().resolve(languageCode: 'fr'), isNull);
      expect(_catalog(const []).resolve(languageCode: 'de'), isNull);
    });

    test('forLanguage and byId filter the catalog', () {
      expect(_catalog().forLanguage('de'), [_heidi, _klaus]);
      expect(_catalog().forLanguage('fr'), isEmpty);
      expect(_catalog().byId('v-en-1'), _emma);
      expect(_catalog().byId('nope'), isNull);
    });
  });

  test('languageCodes lists each language once, by code, sorted', () {
    expect(_catalog().languageCodes, ['de', 'en']);
    const mixed = VoxtralVoice(
      id: 'mixed',
      name: 'Mixed',
      languages: ['pt-BR', 'Portuguese', ' ', 'Dutch', 'xx'],
    );
    expect(_catalog(const [mixed]).languageCodes, ['nl', 'pt', 'xx']);
    expect(_catalog(const []).languageCodes, isEmpty);
  });

  group('VoxtralVoiceCatalog cache', () {
    test('round-trips through JSON', () {
      final restored = VoxtralVoiceCatalog.fromJson(_catalog().toJson());
      expect(restored, _catalog());
      expect(restored.hashCode, _catalog().hashCode);
    });

    test('skips malformed cached entries instead of dropping the cache', () {
      final restored = VoxtralVoiceCatalog.fromJson({
        'fetchedAt': _fetchedAt.toIso8601String(),
        'voices': [
          _heidi.toJson(),
          const {'name': 'broken'},
          'not a map',
        ],
      });
      expect(restored.voices, [_heidi]);
      expect(restored.fetchedAt, _fetchedAt);
    });

    test('is stale once maxAge has passed', () {
      final catalog = _catalog();
      final justUnder = VoxtralVoiceCatalog.maxAge - const Duration(minutes: 1);
      expect(catalog.isStale(_fetchedAt), isFalse);
      expect(catalog.isStale(_fetchedAt.add(justUnder)), isFalse);
      expect(
        catalog.isStale(_fetchedAt.add(VoxtralVoiceCatalog.maxAge)),
        isTrue,
      );
    });
  });

  // Property: a resolved voice is either the preferred one or speaks the
  // language, and null only when no voice speaks it.
  glados.Glados2(
    glados.any.choose(const ['de', 'en', 'fr', 'de-AT']),
    glados.any.choose(const ['v-de-1', 'v-en-1', 'v-de-2', 'gone', '']),
  ).test('resolve never returns an unrelated voice', (language, preferred) {
    final voice = _catalog().resolve(
      languageCode: language,
      preferredVoiceId: preferred,
    );
    if (voice == null) {
      expect(_catalog().forLanguage(language), isEmpty);
    } else {
      expect(voice.id == preferred || voice.speaks(language), isTrue);
    }
  });
}
