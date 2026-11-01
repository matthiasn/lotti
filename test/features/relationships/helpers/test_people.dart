import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';

final DateTime _kPersonDate = DateTime(2026, 7, 1, 9);

/// A person on the People page, for suites that need someone to link — an
/// event's people, a picker's rows — rather than a relationship's own state.
RelationshipEntry makeTestPerson({
  required String id,
  required String title,
  String? nickname,
  String? avatarImageId,
  DateTime? deletedAt,
}) => RelationshipEntry(
  data: RelationshipData(
    title: title,
    nickname: nickname,
    avatarImageId: avatarImageId,
    status: RelationshipStatus.active(
      id: 'status-$id',
      createdAt: _kPersonDate,
      utcOffset: 0,
    ),
  ),
  meta: Metadata(
    id: id,
    createdAt: _kPersonDate,
    updatedAt: _kPersonDate,
    dateFrom: _kPersonDate,
    dateTo: _kPersonDate,
    deletedAt: deletedAt,
  ),
);
