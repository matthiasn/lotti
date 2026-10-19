import 'package:flutter/foundation.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_parts.dart';

/// How a person has made her their own: her skin, her hair, its colour, and
/// the outfit she wears, or none to let her pick one each session.
///
/// The default is Lotti as the pitch videos draw her: [CompanionSkinTone.tone1],
/// a silver [CompanionHairStyle.bun], and a random outfit.
@immutable
class CompanionCustomization {
  const CompanionCustomization({
    this.skinTone = CompanionSkinTone.tone1,
    this.hairStyle = CompanionHairStyle.bun,
    this.hairColour = CompanionHairColour.silver,
    this.outfitId,
  });

  /// Reads what [toJson] wrote. A part this version does not know — written
  /// by a newer one — falls back to its default rather than failing, and so
  /// does an outfit that no longer exists.
  factory CompanionCustomization.fromJson(Map<String, dynamic> json) {
    T part<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.asNameMap()[name] ?? fallback;
    final outfit = json['outfit'];
    return CompanionCustomization(
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
      outfitId: CompanionLook.all.any((l) => l.id == outfit)
          ? outfit as String
          : null,
    );
  }

  final CompanionSkinTone skinTone;
  final CompanionHairStyle hairStyle;
  final CompanionHairColour hairColour;

  /// The `CompanionLook.id` of the outfit she always wears, or null for one
  /// drawn at random each session.
  final String? outfitId;

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

  CompanionCustomization copyWith({
    CompanionSkinTone? skinTone,
    CompanionHairStyle? hairStyle,
    CompanionHairColour? hairColour,
    ValueGetter<String?>? outfitId,
  }) => CompanionCustomization(
    skinTone: skinTone ?? this.skinTone,
    hairStyle: hairStyle ?? this.hairStyle,
    hairColour: hairColour ?? this.hairColour,
    outfitId: outfitId == null ? this.outfitId : outfitId(),
  );

  Map<String, dynamic> toJson() => {
    'skinTone': skinTone.name,
    'hairStyle': hairStyle.name,
    'hairColour': hairColour.name,
    'outfit': ?outfitId,
  };

  @override
  bool operator ==(Object other) =>
      other is CompanionCustomization &&
      other.skinTone == skinTone &&
      other.hairStyle == hairStyle &&
      other.hairColour == hairColour &&
      other.outfitId == outfitId;

  @override
  int get hashCode => Object.hash(skinTone, hairStyle, hairColour, outfitId);
}
