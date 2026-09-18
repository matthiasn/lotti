import 'package:lotti/classes/journal_entities.dart';

/// The names a dictated check-in about [person] is likely to contain, most
/// specific first: the person's name and nickname, the names the user listed
/// for them, then the names and nicknames of the other people in the same
/// category.
///
/// Order matters because providers that honour a vocabulary hint keep only
/// its leading terms. Another person marked private contributes nothing:
/// these terms leave the device with the recording, and one person's
/// dictation must not carry a private person's name to the provider. The
/// person themselves is always included — the recording is about them.
List<String> relationshipKnownTerms({
  required RelationshipEntry person,
  required Iterable<RelationshipEntry> people,
}) {
  final data = person.data;
  final categoryId = person.meta.categoryId;
  return [
    data.title,
    ?data.nickname,
    ...data.knownTerms,
    if (categoryId != null)
      for (final other in people)
        if (other.id != person.id &&
            other.meta.categoryId == categoryId &&
            other.meta.deletedAt == null &&
            !(other.meta.private ?? false)) ...[
          other.data.title,
          ?other.data.nickname,
        ],
  ];
}
