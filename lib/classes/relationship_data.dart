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

    /// ID of a linked JournalImage to use as cover art.
    String? coverArtId,

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

extension RelationshipStatusExtension on RelationshipStatus {
  String get toDbString => switch (this) {
    RelationshipActive() => 'ACTIVE',
    RelationshipDormant() => 'DORMANT',
    RelationshipArchived() => 'ARCHIVED',
  };

  /// Human-readable label for display and agent output.
  String get label => switch (this) {
    RelationshipActive() => 'Active',
    RelationshipDormant() => 'Dormant',
    RelationshipArchived() => 'Archived',
  };
}
