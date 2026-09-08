import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/ui/widgets/avatar_crop_sheet.dart';
import 'package:lotti/features/relationships/ui/widgets/person_photo_actions.dart';
import 'package:lotti/logic/image_import.dart';
import 'package:material_ui/material_ui.dart';

/// [PersonPhotoActions] over the real repositories, the real picker and the
/// real crop surface, opened over [context] — the page under the avatar
/// sheet, or the person form.
///
/// Both hosts build theirs here so a picture chosen from the sheet and one
/// chosen from the form go through exactly the same import and the same
/// write; a test hands the host fakes instead.
PersonPhotoActions productionPersonPhotoActions(
  WidgetRef ref, {
  required BuildContext context,
  required RelationshipEntry relationship,
}) => PersonPhotoActions(
  relationships: ref.read(relationshipRepositoryProvider),
  journal: ref.read(journalRepositoryProvider),
  pickImage: () => pickSingleImageEntry(
    context,
    linkedId: relationship.id,
    categoryId: relationship.meta.categoryId,
  ),
  chooseCrop: (imageId, initial) => showAvatarCropSheet(
    context: context,
    relationship: relationship,
    imageId: imageId,
    initial: initial,
  ),
);
