import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/geolocation.dart';

part 'relationship_data.freezed.dart';
part 'relationship_data.g.dart';

/// The communication channel kinds a relationship can carry (ADR 0041).
enum ContactChannelType {
  phone,
  mobile,
  email,
  messaging,
}

/// One way to reach the person behind a relationship — a phone number, email
/// address, or messaging handle. Channels are plain snapshot data copied from
/// the OS contact (or entered manually); they are deliberately excluded from
/// AI context (ADR 0041 §5).
@freezed
abstract class ContactChannel with _$ContactChannel {
  const factory ContactChannel({
    required ContactChannelType type,
    required String value,
    String? label,
  }) = _ContactChannel;

  factory ContactChannel.fromJson(Map<String, dynamic> json) =>
      _$ContactChannelFromJson(json);
}

/// Which part of a source image a circular avatar shows.
///
/// Normalised to the source rather than to any one rendering, so the same
/// crop frames the face identically at every size the avatar is drawn at —
/// 40 on a People row, 48 in the import review, 80 on the person page hero.
///
/// [x] and [y] are the `BoxFit.cover` **alignment** of the image inside the
/// circle — the convention `EventData.coverArtCropX` already uses: `0`
/// aligns the image's left/top edge with the circle's, `1` the right/bottom,
/// `0.5` centres it. [scale] zooms about that same point, where `1` is the
/// smallest zoom that still covers the circle. Alignment rather than
/// "centre of the visible window" because it makes every value in range
/// valid at every zoom: nothing has to be re-clamped when [scale] changes.
///
/// A transform over the original, never a second file: re-cropping rewrites
/// three numbers and touches no bytes on disk.
@freezed
abstract class AvatarCrop with _$AvatarCrop {
  const factory AvatarCrop({
    @Default(0.5) double x,
    @Default(0.5) double y,
    @Default(1) double scale,
  }) = _AvatarCrop;

  const AvatarCrop._();

  /// Deserialises through [clamped], so a value that arrives out of range —
  /// from a peer running a future version, or a hand-edited payload — cannot
  /// render an empty circle on this device.
  factory AvatarCrop.fromJson(Map<String, dynamic> json) =>
      _$AvatarCropFromJson(json).clamped;

  /// The framing this crop actually describes: centre inside the image and
  /// zoom inside [minAvatarCropScale] … [maxAvatarCropScale].
  AvatarCrop get clamped => AvatarCrop(
    x: clampCropFraction(x),
    y: clampCropFraction(y),
    scale: clampAvatarCropScale(scale),
  );
}

/// The closest an avatar crop may be zoomed out: the image exactly covers the
/// circle, so there is never a gap to fill.
const double minAvatarCropScale = 1;

/// The furthest an avatar crop may be zoomed in. Past this a phone photo has
/// no pixels left to show at 80 logical points.
const double maxAvatarCropScale = 4;

/// A normalised position within an image, clamped to the image.
double clampCropFraction(double value) =>
    value.isNaN ? 0.5 : value.clamp(0.0, 1.0);

/// An avatar zoom, clamped to the range the crop surface offers.
double clampAvatarCropScale(double value) => value.isNaN
    ? minAvatarCropScale
    : value.clamp(minAvatarCropScale, maxAvatarCropScale);

/// Reads a normalised position out of JSON, clamped — the read-side guard
/// [AvatarCrop.fromJson] gives the avatar, for the banner's single axis.
/// Anything that is not a number reads as centred rather than throwing: a
/// malformed framing must not make a person fail to load.
double cropFractionFromJson(Object? raw) =>
    raw is num ? clampCropFraction(raw.toDouble()) : 0.5;

/// Lifecycle status of a relationship, mirroring `ProjectStatus` in shape
/// (ADR 0038): `active` relationships participate in cadence tracking,
/// `dormant` ones are kept but not currently nurtured (excluded from
/// reminders and nudges), `archived` ones are closed.
@freezed
sealed class RelationshipStatus with _$RelationshipStatus {
  const factory RelationshipStatus.active({
    required String id,
    required DateTime createdAt,
    required int utcOffset,
    String? timezone,
    Geolocation? geolocation,
  }) = RelationshipActive;

  const factory RelationshipStatus.dormant({
    required String id,
    required DateTime createdAt,
    required int utcOffset,
    String? timezone,
    Geolocation? geolocation,
  }) = RelationshipDormant;

  const factory RelationshipStatus.archived({
    required String id,
    required DateTime createdAt,
    required int utcOffset,
    String? timezone,
    Geolocation? geolocation,
  }) = RelationshipArchived;

  factory RelationshipStatus.fromJson(Map<String, dynamic> json) =>
      _$RelationshipStatusFromJson(json);
}

/// Payload of a `JournalEntity.relationship` — one entity per person the
/// user deliberately tracks (ADR 0038). The person's identity is embedded
/// here rather than split into a separate contact entity; free-form notes
/// about the person live in the entry's shared `entryText`, and
/// `meta.dateFrom` is when tracking started.
@freezed
abstract class RelationshipData with _$RelationshipData {
  const factory RelationshipData({
    /// The person's display name.
    required String title,
    required RelationshipStatus status,
    String? nickname,

    /// The single consent switch for proactive behavior: only important
    /// relationships produce cadence nudges and reminders (ADR 0039).
    @Default(false) bool important,
    @Default([]) List<RelationshipStatus> statusHistory,

    /// Desired check-in interval in days; only meaningful when [important]
    /// is set. Defaults to 30 at the evaluation site when unset.
    int? checkInCadenceDays,
    DateTime? birthday,

    /// Inference profile ID for the relationship agent (ADR 0040),
    /// mirroring `ProjectData.profileId`.
    String? profileId,
    String? languageCode,

    /// The person's photograph: a linked `JournalImage` shown wherever the
    /// persona avatar is drawn, with [avatarCrop] deciding which part of it
    /// is the face. Null for a person without one, which stays the expected
    /// steady state — the tinted initial is the fallback, not a placeholder.
    String? avatarImageId,

    /// How [avatarImageId] is framed. Null means the default centre framing;
    /// the crop surface writes an explicit value.
    AvatarCrop? avatarCrop,

    /// The wide image behind the person page's hero: a linked `JournalImage`,
    /// something *of* or *reminding of* the person rather than a second
    /// portrait. Null leaves the hero the teal wash it has always been.
    String? bannerImageId,

    /// Horizontal framing of [bannerImageId] (0 = left … 1 = right), the
    /// `EventData.coverArtCropX` shape. A banner is only ever cropped
    /// horizontally: its height is fixed by the hero.
    @Default(0.5) @JsonKey(fromJson: cropFractionFromJson) double bannerCropX,

    /// Excluded from AI context (ADR 0041 §5).
    @Default([]) List<ContactChannel> contactChannels,

    /// Per-platform OS contact identifiers, used only for an explicit
    /// "Update from contact" refresh on the device that owns the contact
    /// (ADR 0041 §2). Excluded from AI context.
    @Default(<String, String>{}) Map<String, String> contactRefs,
  }) = _RelationshipData;

  factory RelationshipData.fromJson(Map<String, dynamic> json) =>
      _$RelationshipDataFromJson(json);
}

/// Write-side guard for the two image framings, applied by
/// `RelationshipRepository` before anything is persisted.
///
/// The read side is already covered — [AvatarCrop.fromJson] and
/// [cropFractionFromJson] clamp whatever sync delivers. This is the other
/// half: a local caller with an arithmetic slip in a crop gesture must not be
/// able to write a framing that shows an empty circle on every other device.
extension RelationshipImageFraming on RelationshipData {
  RelationshipData get withClampedImageFraming => copyWith(
    avatarCrop: avatarCrop?.clamped,
    bannerCropX: clampCropFraction(bannerCropX),
  );
}
