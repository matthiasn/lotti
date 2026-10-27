import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

/// Whether a voice is one of Mistral's presets or one the account created.
///
/// Mirrors the `type` field of `GET /v1/audio/voices`; anything the API adds
/// later reads as [unknown] rather than failing the whole catalog.
enum VoxtralVoiceType { preset, custom, unknown }

/// One voice from Mistral's voice catalog.
///
/// Only the fields the voice picker and the selection strategy need are kept.
/// The API also returns `age`, `color`, `tags` and sample metadata; those stay
/// on the server.
@immutable
class VoxtralVoice {
  const VoxtralVoice({
    required this.id,
    required this.name,
    required this.languages,
    this.slug,
    this.gender,
    this.type = VoxtralVoiceType.unknown,
  });

  /// Reads one entry of the catalog's `items` array. Throws [FormatException]
  /// when `id` or `name` is missing, because a voice without either can be
  /// neither sent nor shown.
  factory VoxtralVoice.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    if (id is! String || id.isEmpty || name is! String) {
      throw const FormatException('Voice entry lacks an id or a name');
    }
    final languages = json['languages'];
    return VoxtralVoice(
      id: id,
      name: name,
      slug: json['slug'] as String?,
      gender: json['gender'] as String?,
      languages: languages is List
          ? languages.whereType<String>().toList(growable: false)
          : const <String>[],
      type: switch (json['type']) {
        'preset' => VoxtralVoiceType.preset,
        'custom' => VoxtralVoiceType.custom,
        _ => VoxtralVoiceType.unknown,
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

  final VoxtralVoiceType type;

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
    'type': type.name,
  };

  @override
  bool operator ==(Object other) =>
      other is VoxtralVoice &&
      other.id == id &&
      other.name == name &&
      other.slug == slug &&
      other.gender == gender &&
      listEquals(other.languages, languages) &&
      other.type == type;

  @override
  int get hashCode =>
      Object.hash(id, name, slug, gender, Object.hashAll(languages), type);

  @override
  String toString() => 'VoxtralVoice($id, $name, $languages)';
}

/// English names for the languages Voxtral TTS launched with, keyed by ISO
/// 639-1 code, so [VoxtralVoice.speaks] also matches a catalog that spells
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

/// A snapshot of the voices Mistral offered at [fetchedAt].
///
/// Serializable so the last good catalog can be persisted and used offline;
/// [isStale] tells a caller when to refresh it in the background.
@immutable
class VoxtralVoiceCatalog {
  const VoxtralVoiceCatalog({required this.voices, required this.fetchedAt});

  /// Restores a catalog written by [toJson]. Malformed entries are skipped
  /// rather than discarding the whole cache.
  factory VoxtralVoiceCatalog.fromJson(Map<String, dynamic> json) {
    final items = json['voices'];
    return VoxtralVoiceCatalog(
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      voices: <VoxtralVoice>[
        if (items is List)
          for (final item in items.whereType<Map<String, dynamic>>())
            ?_tryParse(item),
      ],
    );
  }

  /// Catalog order is the API's order, which is what "the first available
  /// voice for a language" refers to.
  final List<VoxtralVoice> voices;

  final DateTime fetchedAt;

  /// How long a fetched catalog is trusted before a background refresh. The
  /// catalog changes rarely (new presets, a user's own clones), so a day keeps
  /// API calls negligible while picking up changes the same day.
  static const Duration maxAge = Duration(days: 1);

  bool isStale(DateTime now) => now.difference(fetchedAt) >= maxAge;

  VoxtralVoice? byId(String id) {
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
  List<VoxtralVoice> forLanguage(String languageCode) =>
      voices.where((voice) => voice.speaks(languageCode)).toList();

  /// The voice to speak [languageCode] with.
  ///
  /// [preferredVoiceId] — the user's choice for this language — wins whenever
  /// the catalog still has it, even if the catalog does not list the language
  /// for it: the user picked it deliberately. Otherwise the language's
  /// default: its first female preset, then its first voice of any kind. The
  /// API has no automatic voice per language, so this default is ours.
  /// `null` when the language has no voice, so nothing is read rather than
  /// German text in an English voice.
  VoxtralVoice? resolve({
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

  static bool _isFemalePreset(VoxtralVoice voice) =>
      voice.type == VoxtralVoiceType.preset &&
      voice.gender?.trim().toLowerCase() == 'female';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'fetchedAt': fetchedAt.toIso8601String(),
    'voices': [for (final voice in voices) voice.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      other is VoxtralVoiceCatalog &&
      other.fetchedAt == fetchedAt &&
      listEquals(other.voices, voices);

  @override
  int get hashCode => Object.hash(fetchedAt, Object.hashAll(voices));
}

VoxtralVoice? _tryParse(Map<String, dynamic> json) {
  try {
    return VoxtralVoice.fromJson(json);
  } on FormatException {
    return null;
  }
}
