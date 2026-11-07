import 'package:lotti/classes/journal_entities.dart';

import '../../test_data/test_data.dart';

/// A person filed in [categoryId] — penguin-world names only.
RelationshipEntry testPerson(
  String id,
  String title, {
  String? nickname,
  String? categoryId = 'penguin-operations',
  bool private = false,
  bool deleted = false,
}) => testRelationship.copyWith(
  meta: testRelationship.meta.copyWith(
    id: id,
    categoryId: categoryId,
    private: private,
    deletedAt: deleted ? DateTime(2026, 9) : null,
  ),
  data: testRelationship.data.copyWith(title: title, nickname: nickname),
);
