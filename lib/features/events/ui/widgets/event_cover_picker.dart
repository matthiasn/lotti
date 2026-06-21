import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/events/ui/widgets/event_cover_image.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// One selectable cover candidate: a linked photo's id plus its (already
/// resolved) image and crop offset.
@immutable
class EventCoverChoice {
  const EventCoverChoice({
    required this.id,
    required this.image,
    this.cropX = 0.5,
  });

  final String id;
  final ImageProvider image;
  final double cropX;
}

/// A grid of an event's linked photos for picking which one becomes the cover,
/// with the current cover ringed and a trailing "add photo" tile. Pure and
/// presentational: the page resolves [choices] and handles the selection.
class EventCoverPicker extends StatelessWidget {
  const EventCoverPicker({
    required this.choices,
    this.currentCoverId,
    this.onSelect,
    this.onAddPhoto,
    super.key,
  });

  final List<EventCoverChoice> choices;
  final String? currentCoverId;
  final ValueChanged<String>? onSelect;
  final VoidCallback? onAddPhoto;

  static const double _tile = 96;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cs = context.colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.messages.eventsChangeCover,
              style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                color: cs.onSurface,
              ),
            ),
            SizedBox(height: tokens.spacing.step4),
            // Cap the grid and let it scroll so a long photo list stays fully
            // reachable instead of overflowing the sheet.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.6,
              ),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: tokens.spacing.step2,
                  runSpacing: tokens.spacing.step2,
                  children: [
                    for (final choice in choices)
                      _CoverTile(
                        choice: choice,
                        selected: choice.id == currentCoverId,
                        size: _tile,
                        onTap: onSelect == null
                            ? null
                            : () => onSelect!(choice.id),
                      ),
                    if (onAddPhoto != null)
                      _AddPhotoTile(size: _tile, onTap: onAddPhoto!),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverTile extends StatelessWidget {
  const _CoverTile({
    required this.choice,
    required this.selected,
    required this.size,
    this.onTap,
  });

  final EventCoverChoice choice;
  final bool selected;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cs = context.colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(tokens.radii.s),
          border: selected
              ? Border.all(color: cs.primary, width: 3)
              : Border.all(color: cs.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: EventCoverImage(
          image: choice.image,
          fallbackColor: cs.surfaceContainerHighest,
          cropX: choice.cropX,
          scrim: EventCoverScrim.none,
          decodeWidth: size,
        ),
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.size, required this.onTap});

  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cs = context.colorScheme;
    return Material(
      color: dsCardSurface(context),
      borderRadius: BorderRadius.circular(tokens.radii.s),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            Icons.add_a_photo_outlined,
            color: cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Shows the [EventCoverPicker] in a bottom sheet, dismissing it before
/// invoking [onSelect] / [onAddPhoto] so the caller's navigation runs cleanly.
Future<void> showEventCoverPicker({
  required BuildContext context,
  required List<EventCoverChoice> choices,
  required ValueChanged<String> onSelect,
  required VoidCallback onAddPhoto,
  String? currentCoverId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: dsCardSurface(context),
    builder: (sheetContext) => EventCoverPicker(
      choices: choices,
      currentCoverId: currentCoverId,
      onSelect: (id) {
        Navigator.of(sheetContext).pop();
        onSelect(id);
      },
      onAddPhoto: () {
        Navigator.of(sheetContext).pop();
        onAddPhoto();
      },
    ),
  );
}
