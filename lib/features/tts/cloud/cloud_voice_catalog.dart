import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

/// Whether a voice is one of the provider's presets or one the account
/// created (or saved from a library).
///
/// Mirrors Mistral's `type` field of `GET /v1/audio/voices` (ElevenLabs'
/// `category` is mapped onto it); anything an API adds later reads as
/// [unknown] rather than failing the whole catalog.
enum CloudVoiceType { preset, custom, unknown }

/// One voice from a cloud provider's voice catalog.
///
/// Only the fields the voice picker and the selection strategy need are kept;
/// the rest of what the APIs return (sample metadata, voice settings, …)
/// stays on the server.
@immutable
class CloudVoice {
  const CloudVoice({
    required this.id,
    required this.name,
    required this.languages,
    this.slug,
    this.gender,
    this.tags = const [],
    this.type = CloudVoiceType.unknown,
  });

  /// Reads one entry of Mistral's `items` array, which is also the shape
  /// [toJson] caches every provider's voices in. Throws [FormatException]
  /// when `id` or `name` is missing, because a voice without either can be
  /// neither sent nor shown.
  factory CloudVoice.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    if (id is! String || id.isEmpty || name is! String) {
      throw const FormatException('Voice entry lacks an id or a name');
    }
    final languages = json['languages'];
    final tags = json['tags'];
    return CloudVoice(
      id: id,
      name: name,
      slug: json['slug'] as String?,
      gender: json['gender'] as String?,
      languages: languages is List
          ? languages.whereType<String>().toList(growable: false)
          : const <String>[],
      tags: tags is List
          ? tags.whereType<String>().toList(growable: false)
          : const <String>[],
      type: switch (json['type']) {
        'preset' => CloudVoiceType.preset,
        'custom' => CloudVoiceType.custom,
        _ => CloudVoiceType.unknown,
      },
    );
  }

  /// The value sent as `voice_id` in a speech request.
  final String id;

  /// Display name, e.g. a preset's persona name. Not localized: it is the
  /// provider's proper noun, like model names elsewhere in the app.
  final String name;

  /// Stable human-readable key, when the API provides one.
  final String? slug;

  /// As reported by the API (`female`, `male`, …); used only for grouping in
  /// the picker, never for selection.
  final String? gender;

  /// The languages the voice is advertised for, verbatim from the API.
  final List<String> languages;

  /// How the voice sounds, as the API describes it (`sunny`, `easygoing`,
  /// …); about half the presets carry some, the rest none. Shown in the
  /// picker so voices of one language can be told apart before a preview.
  final List<String> tags;

  final CloudVoiceType type;

  /// Whether this voice is advertised for [languageCode] (`de`, `de-AT`, …).
  ///
  /// Region subtags are ignored on both sides, and an entry may be either an
  /// ISO 639-1 code or the English language name — the voices endpoint's
  /// schema does not pin which, so both are accepted.
  bool speaks(String languageCode) {
    final wanted = primaryLanguageSubtag(languageCode);
    if (wanted.isEmpty) return false;
    final wantedName = _languageNames[wanted];
    for (final entry in languages) {
      final normalized = entry.trim().toLowerCase();
      if (primaryLanguageSubtag(normalized) == wanted ||
          normalized == wantedName) {
        return true;
      }
    }
    return false;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    if (slug != null) 'slug': slug,
    if (gender != null) 'gender': gender,
    'languages': languages,
    if (tags.isNotEmpty) 'tags': tags,
    'type': type.name,
  };

  @override
  bool operator ==(Object other) =>
      other is CloudVoice &&
      other.id == id &&
      other.name == name &&
      other.slug == slug &&
      other.gender == gender &&
      listEquals(other.languages, languages) &&
      listEquals(other.tags, tags) &&
      other.type == type;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    slug,
    gender,
    Object.hashAll(languages),
    Object.hashAll(tags),
    type,
  );

  @override
  String toString() => 'CloudVoice($id, $name, $languages)';
}

/// English names for the languages Voxtral TTS launched with, keyed by ISO
/// 639-1 code, so [CloudVoice.speaks] also matches a catalog that spells
/// languages out. Codes match for every language without an entry here.
const Map<String, String> _languageNames = <String, String>{
  'ar': 'arabic',
  'de': 'german',
  'en': 'english',
  'es': 'spanish',
  'fr': 'french',
  'hi': 'hindi',
  'it': 'italian',
  'nl': 'dutch',
  'pt': 'portuguese',
};

/// `de-AT` and `de_AT` → `de`; lower-cased and trimmed.
String primaryLanguageSubtag(String languageCode) =>
    languageCode.trim().toLowerCase().split(RegExp('[-_]')).first;

/// A snapshot of the voices a provider offered at [fetchedAt].
///
/// Serializable so the last good catalog can be persisted and used offline;
/// [isStale] tells a caller when to refresh it in the background.
@immutable
class CloudVoiceCatalog {
  const CloudVoiceCatalog({required this.voices, required this.fetchedAt});

  /// Restores a catalog written by [toJson]. Malformed entries are skipped
  /// rather than discarding the whole cache.
  factory CloudVoiceCatalog.fromJson(Map<String, dynamic> json) {
    final items = json['voices'];
    return CloudVoiceCatalog(
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      voices: <CloudVoice>[
        if (items is List)
          for (final item in items.whereType<Map<String, dynamic>>())
            ?_tryParse(item),
      ],
    );
  }

  /// Catalog order is the API's order, which is what "the first available
  /// voice for a language" refers to.
  final List<CloudVoice> voices;

  final DateTime fetchedAt;

  /// How long a fetched catalog is trusted before a background refresh. The
  /// catalog changes rarely (new presets, a user's own clones), so a day keeps
  /// API calls negligible while picking up changes the same day.
  static const Duration maxAge = Duration(days: 1);

  bool isStale(DateTime now) => now.difference(fetchedAt) >= maxAge;

  CloudVoice? byId(String id) {
    for (final voice in voices) {
      if (voice.id == id) return voice;
    }
    return null;
  }

  /// The languages the catalog has voices for, as sorted primary subtags. A
  /// language the API spells out (`German`) is reported by its code (`de`),
  /// so one language never appears twice.
  List<String> get languageCodes {
    final codes = <String>{
      for (final voice in voices)
        for (final entry in voice.languages) ?_languageCodeOf(entry),
    };
    return codes.toList()..sort();
  }

  static String? _languageCodeOf(String entry) {
    final normalized = entry.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    for (final MapEntry(:key, :value) in _languageNames.entries) {
      if (value == normalized) return key;
    }
    return primaryLanguageSubtag(normalized);
  }

  /// Every voice advertised for [languageCode], in catalog order.
  List<CloudVoice> forLanguage(String languageCode) =>
      voices.where((voice) => voice.speaks(languageCode)).toList();

  /// The voice to speak [languageCode] with.
  ///
  /// [preferredVoiceId] — the user's choice for this language — wins whenever
  /// the catalog still has it, even if the catalog does not list the language
  /// for it: the user picked it deliberately. Otherwise the language's
  /// default: its first female preset, then its first voice of any kind. No
  /// provider names a voice per language, so this default is ours.
  /// `null` when the language has no voice, so nothing is read rather than
  /// German text in an English voice.
  CloudVoice? resolve({
    required String languageCode,
    String? preferredVoiceId,
  }) {
    if (preferredVoiceId != null) {
      final preferred = byId(preferredVoiceId);
      if (preferred != null) return preferred;
    }
    final candidates = forLanguage(languageCode);
    return candidates.firstWhereOrNull(_isFemalePreset) ??
        candidates.firstOrNull;
  }

  static bool _isFemalePreset(CloudVoice voice) =>
      voice.type == CloudVoiceType.preset &&
      voice.gender?.trim().toLowerCase() == 'female';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'fetchedAt': fetchedAt.toIso8601String(),
    'voices': [for (final voice in voices) voice.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      other is CloudVoiceCatalog &&
      other.fetchedAt == fetchedAt &&
      listEquals(other.voices, voices);

  @override
  int get hashCode => Object.hash(fetchedAt, Object.hashAll(voices));
}

CloudVoice? _tryParse(Map<String, dynamic> json) {
  try {
    return CloudVoice.fromJson(json);
  } on FormatException {
    return null;
  }
}
