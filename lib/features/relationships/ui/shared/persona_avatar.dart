import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/media/journal_image_resolver.dart';
import 'package:lotti/widgets/media/thumb_hash_backed_image.dart';
import 'package:material_ui/material_ui.dart';

/// One accent per person, stable per id (design plan §0.7). The palette is
/// the same family the goal agents draw from: the design system's semantic
/// accents plus the two hand-authored goal hues. Assignment is a
/// deterministic hash of the id, so the same person lands on the same
/// accent on every device and across reloads — the avatar does not
/// reshuffle when the list reorders.
///
/// Every entry comes from the exported token sets — the brightness picks
/// which set, nothing here holds a color literal of its own. The alert
/// accents use the `ink` variant because the accent is rendered as text
/// (the initial), and ink is the text-weight resolution of each hue.
Color personaAccentForId(String id, Brightness brightness) {
  // A stable, well-mixed 32-bit hash of the id. String.hashCode is not
  // guaranteed stable across Dart versions, so fold the bytes by hand.
  var hash = 0x811C9DC5; // FNV-1a 32-bit offset basis.
  for (final byte in id.codeUnits) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xFFFFFFFF; // FNV-1a prime.
  }
  final tokens = brightness == Brightness.dark ? dsTokensDark : dsTokensLight;
  final palette = <Color>[
    tokens.colors.interactive.enabled,
    GoalAccentHues.neon(brightness),
    GoalAccentHues.aurora(brightness),
    tokens.colors.alert.warning.ink,
    tokens.colors.alert.info.ink,
    tokens.colors.alert.success.ink,
  ];
  return palette[hash % palette.length];
}

/// A person's face on every People surface: a photograph inside an
/// accent-coloured ring, or — for the many people who will never have one —
/// the persona-tinted circle with their initial (design plan §0.7).
///
/// The accent is derived from [id] when supplied; callers that already
/// hold an accent (e.g. a beat rail reusing the person's accent) pass it
/// directly via [accent]. **The accent never changes because a photo does**:
/// the same hash gives the same colour, so a list mixing faces and initials
/// keeps every person's identity colour, and adding a photo cannot reshuffle
/// anyone.
///
/// Four faces, decided by [imageId] and what its file is doing
/// (design 2026-09-08 turn 2):
///
/// * **No photo** ([imageId] null) — the tinted initial, exactly as before.
/// * **Photo** — the picture, clipped to the circle, cropped by [crop],
///   inside a ring of the accent.
/// * **Arriving** — the id is known but the file has not landed (it syncs
///   after the entry): the ThumbHash stand-in fills the ring until it does.
/// * **Id known, no stand-in** — the ring says a photo exists; the tinted
///   initial sits inside it so the circle is never empty.
class PersonaAvatar extends StatelessWidget {
  const PersonaAvatar({
    required this.initial,
    this.id,
    this.accent,
    this.size = 40,
    this.imageId,
    this.crop,
    super.key,
  }) : assert(
         id != null || accent != null,
         'PersonaAvatar needs either an id (to derive the accent) or an '
         'explicit accent.',
       );

  /// The single character shown (usually the first letter of the name).
  final String initial;

  /// The person's entity id — used to derive a stable accent. Ignored when
  /// [accent] is supplied.
  final String? id;

  /// An explicit accent, overriding the id-derived one.
  final Color? accent;

  /// The avatar diameter in logical pixels — ring included, so a photo never
  /// makes a row taller.
  final double size;

  /// The `JournalImage` behind the person's photograph, or null for the
  /// initial.
  final String? imageId;

  /// Which part of the photograph is the face. Null is the default framing.
  final AvatarCrop? crop;

  /// The ring around a photograph, in logical pixels. One width at every
  /// size: the design's 3 px at 80 would need a token spacing does not have,
  /// and 2 px reads at 80 as well.
  static double ringWidth(DsTokens tokens) => tokens.spacing.step1;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accent =
        this.accent ?? personaAccentForId(id!, Theme.of(context).brightness);
    final imageId = this.imageId;
    if (imageId == null) {
      return _TintedInitial(
        initial: initial,
        accent: accent,
        size: size,
        fontSize: size * 0.42,
      );
    }
    final ring = ringWidth(tokens);
    final inner = size - ring * 2;
    return Container(
      key: const ValueKey('persona-avatar-ring'),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: accent, width: ring),
      ),
      child: ClipOval(
        child: JournalImageResolver(
          imageId: imageId,
          builder: (context, resolved) {
            if (resolved == null || resolved.hasNothingToShow) {
              return _TintedInitial(
                initial: initial,
                accent: accent,
                size: inner,
                fontSize: size * 0.42,
              );
            }
            return AvatarCropPicture(
              resolved: resolved,
              crop: crop ?? const AvatarCrop(),
              size: inner,
            );
          },
        ),
      ),
    );
  }
}

/// The persona-tinted circle with the initial: `color-mix(accent 20%,
/// transparent)` fill, the initial in the accent. The whole avatar when
/// there is no photo; the inside of the ring when the photo has nothing to
/// show yet.
class _TintedInitial extends StatelessWidget {
  const _TintedInitial({
    required this.initial,
    required this.accent,
    required this.size,
    required this.fontSize,
  });

  final String initial;
  final Color accent;
  final double size;

  /// From the avatar's *outer* size even inside a ring, so the initial does
  /// not shrink because a photo is on its way.
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.20),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial.isEmpty ? '·' : initial,
        style: tokens.typography.styles.subtitle.subtitle1.copyWith(
          color: accent,
          fontSize: fontSize,
          fontWeight: tokens.typography.weight.semiBold,
          height: 1,
        ),
      ),
    );
  }
}

/// The photograph — or its stand-in — framed by an [AvatarCrop], in a box
/// of [size]: the one composition every avatar and the crop surface draw.
///
/// The crop is applied as `BoxFit.cover` alignment plus a scale about the
/// same point, which is what keeps the circle full for any stored value:
/// a covering image scaled up about a point inside the box still covers the
/// box, so no combination of alignment and zoom in range can show an edge.
/// `CoverCropGeometry` is this arithmetic written out, for the surface
/// that edits the crop; the two must agree, and sharing the widget is what
/// makes the surface's big square and the list's 40 px circle the same
/// framing.
///
/// The decode is bounded to the box at the *widest* zoom, [maxAvatarCropScale]
/// times [size], not to the box itself: the zoom magnifies whatever was
/// decoded, and a decode capped to the circle would show a zoomed face as a
/// blur of its own pixels. One bound per slot keeps the provider's key fixed
/// through a pinch, so zooming never re-decodes, and `ResizeImage` never
/// upscales, so a small source still decodes at its own size.
class AvatarCropPicture extends StatelessWidget {
  const AvatarCropPicture({
    required this.resolved,
    required this.crop,
    required this.size,
    super.key,
  });

  final ResolvedJournalImage resolved;
  final AvatarCrop crop;
  final double size;

  @override
  Widget build(BuildContext context) {
    final alignment = Alignment(crop.x * 2 - 1, crop.y * 2 - 1);
    return Transform.scale(
      scale: crop.scale,
      alignment: alignment,
      child: ThumbHashBackedImage(
        key: ValueKey(resolved.path),
        thumbHash: resolved.thumbHash,
        image: resolved.fileExists
            ? cappedFileImage(
                resolved.path,
                size: size * maxAvatarCropScale,
                devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
              )
            : null,
        alignment: alignment,
      ),
    );
  }
}

/// Convenience: the first letter of [name], uppercased, falling back to "·"
/// for the empty/null name (the import list can carry a contact whose
/// display name is blank).
String personaInitial(String? name) {
  final trimmed = name?.trim() ?? '';
  if (trimmed.isEmpty) return '·';
  return trimmed[0].toUpperCase();
}
