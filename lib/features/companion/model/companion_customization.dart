import 'package:flutter/foundation.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_parts.dart';
import 'package:lotti/features/companion/model/companion_reaction.dart';

/// How a person has made the companion their own: who it is (Lotti, the
/// grandpa or the aunt), the skin, the hair and its colour, the outfit worn, or none to
/// pick one each session, and how much sass it reads with.
///
/// The default is Lotti as the pitch videos draw her: [CompanionSkinTone.tone1],
/// a silver [CompanionHairStyle.bun], a random outfit, and
/// [CompanionSass.cheeky] — a tease, never a scold.
@immutable
class CompanionCustomization {
  const CompanionCustomization({
    this.character = CompanionSpecies.grandma,
    this.skinTone = CompanionSkinTone.tone1,
    this.hairStyle = CompanionHairStyle.bun,
    this.hairColour = CompanionHairColour.silver,
    this.outfitId,
    this.sass = CompanionSass.cheeky,
    this.speaksReplies = true,
  });

  /// Reads what [toJson] wrote. A part this version does not know — written
  /// by a newer one — falls back to its default rather than failing, and so
  /// does an outfit that no longer exists or belongs to another character.
  /// An animal stored as the character reads as Lotti: only a human is
  /// chosen here.
  factory CompanionCustomization.fromJson(Map<String, dynamic> json) {
    T part<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.asNameMap()[name] ?? fallback;
    final character = part(
      CompanionSpecies.choosable,
      json['character'],
      CompanionSpecies.grandma,
    );
    final outfit = json['outfit'];
    return CompanionCustomization(
      character: character,
      skinTone: part(
        CompanionSkinTone.values,
        json['skinTone'],
        CompanionSkinTone.tone1,
      ),
      hairStyle: part(
        CompanionHairStyle.values,
        json['hairStyle'],
        CompanionHairStyle.bun,
      ),
      hairColour: part(
        CompanionHairColour.values,
        json['hairColour'],
        CompanionHairColour.silver,
      ),
      outfitId: CompanionLook.of(character).any((l) => l.id == outfit)
          ? outfit as String
          : null,
      sass: part(CompanionSass.values, json['sass'], CompanionSass.cheeky),
      // Only an explicit false mutes her: a missing or unknown value keeps
      // her default.
      speaksReplies: json['speaksReplies'] != false,
    );
  }

  /// Who the companion is: one of [CompanionSpecies.choosable].
  final CompanionSpecies character;
  final CompanionSkinTone skinTone;
  final CompanionHairStyle hairStyle;
  final CompanionHairColour hairColour;

  /// The `CompanionLook.id` of the [character]'s outfit always worn, or null
  /// for one drawn at random each session.
  final String? outfitId;

  /// How much sass she puts into what she reads.
  final CompanionSass sass;

  /// Whether she answers a question spoken to her out loud. A typed one
  /// only ever gets a written answer; this mutes the spoken one.
  final bool speaksReplies;

  /// [outfit] in this skin and hair: the outfit keeps its clothes and props,
  /// and takes the face and hair from here. Lips an outfit paints — the rock
  /// look's red — stay; plain lips follow the skin tone.
  CompanionLook dress(CompanionLook outfit) {
    final painted = outfit.palette.lips != const CompanionPalette().lips;
    return outfit.copyWith(
      hairStyle: hairStyle,
      palette: outfit.palette.copyWith(
        skin: skinTone.skin,
        skinShade: skinTone.shade,
        skinDeep: skinTone.deep,
        skinLight: skinTone.light,
        lips: painted ? null : skinTone.lips,
        lipsUpper: painted ? null : skinTone.lipsUpper,
        lipsLight: painted ? null : skinTone.lipsLight,
        hair: hairColour.hair,
        hairBack: hairColour.back,
        hairShade: hairColour.shade,
        hairLight: hairColour.light,
        brow: hairColour.brow,
      ),
    );
  }

  /// This, as [species]: the outfit cleared, since outfits belong to one
  /// character, and the hair back to [species]' own style. Skin, hair
  /// colour, sass and the voice switch stay.
  CompanionCustomization asCharacter(CompanionSpecies species) => copyWith(
    character: species,
    hairStyle: species.hairStyle,
    outfitId: () => null,
  );

  CompanionCustomization copyWith({
    CompanionSpecies? character,
    CompanionSkinTone? skinTone,
    CompanionHairStyle? hairStyle,
    CompanionHairColour? hairColour,
    ValueGetter<String?>? outfitId,
    CompanionSass? sass,
    bool? speaksReplies,
  }) => CompanionCustomization(
    character: character ?? this.character,
    skinTone: skinTone ?? this.skinTone,
    hairStyle: hairStyle ?? this.hairStyle,
    hairColour: hairColour ?? this.hairColour,
    outfitId: outfitId == null ? this.outfitId : outfitId(),
    sass: sass ?? this.sass,
    speaksReplies: speaksReplies ?? this.speaksReplies,
  );

  /// The parts — named as [toJson] names them — in which [a] and [b] differ.
  static Set<String> changedParts(
    CompanionCustomization a,
    CompanionCustomization b,
  ) => {
    if (a.character != b.character) 'character',
    if (a.skinTone != b.skinTone) 'skinTone',
    if (a.hairStyle != b.hairStyle) 'hairStyle',
    if (a.hairColour != b.hairColour) 'hairColour',
    if (a.outfitId != b.outfitId) 'outfit',
    if (a.sass != b.sass) 'sass',
    if (a.speaksReplies != b.speaksReplies) 'speaksReplies',
  };

  /// This, with [parts] taken from [other]: edits laid over another value
  /// without undoing what that value holds in the parts left alone.
  CompanionCustomization adopting(
    CompanionCustomization other,
    Set<String> parts,
  ) => CompanionCustomization(
    character: parts.contains('character') ? other.character : character,
    skinTone: parts.contains('skinTone') ? other.skinTone : skinTone,
    hairStyle: parts.contains('hairStyle') ? other.hairStyle : hairStyle,
    hairColour: parts.contains('hairColour') ? other.hairColour : hairColour,
    outfitId: parts.contains('outfit') ? other.outfitId : outfitId,
    sass: parts.contains('sass') ? other.sass : sass,
    speaksReplies: parts.contains('speaksReplies')
        ? other.speaksReplies
        : speaksReplies,
  );

  Map<String, dynamic> toJson() => {
    'character': character.name,
    'skinTone': skinTone.name,
    'hairStyle': hairStyle.name,
    'hairColour': hairColour.name,
    'outfit': ?outfitId,
    'sass': sass.name,
    'speaksReplies': speaksReplies,
  };

  /// [toJson] laid over [stored], the JSON this was changed from: a part
  /// left as [stored] reads here keeps what [stored] holds. So a part a newer
  /// version wrote — which reads here as its default — survives a change to
  /// another part, on this device and, through sync, on the newer one, and so
  /// does a part this version has never heard of.
  Map<String, dynamic> toJsonOver(Map<String, dynamic> stored) {
    final read = CompanionCustomization.fromJson(stored).toJson();
    final changed = toJson();
    final json = {...stored};
    for (final key in {...read.keys, ...changed.keys}) {
      if (read[key] == changed[key]) continue;
      if (changed.containsKey(key)) {
        json[key] = changed[key];
      } else {
        json.remove(key);
      }
    }
    return json;
  }

  @override
  bool operator ==(Object other) =>
      other is CompanionCustomization &&
      other.character == character &&
      other.skinTone == skinTone &&
      other.hairStyle == hairStyle &&
      other.hairColour == hairColour &&
      other.outfitId == outfitId &&
      other.sass == sass &&
      other.speaksReplies == speaksReplies;

  @override
  int get hashCode => Object.hash(
    character,
    skinTone,
    hairStyle,
    hairColour,
    outfitId,
    sass,
    speaksReplies,
  );
}
