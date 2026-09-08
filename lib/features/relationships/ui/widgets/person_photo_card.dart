import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/ui/shared/cover_crop_geometry.dart';
import 'package:lotti/features/relationships/ui/shared/persona_avatar.dart';
import 'package:lotti/features/relationships/ui/widgets/person_header.dart';
import 'package:lotti/features/relationships/ui/widgets/person_page_cards.dart';
import 'package:lotti/features/relationships/ui/widgets/person_photo_actions.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/media/file_image_size.dart';
import 'package:lotti/widgets/media/journal_image_resolver.dart';
import 'package:lotti/widgets/media/thumb_hash_backed_image.dart';
import 'package:material_ui/material_ui.dart';

/// The person form's Photo card (design 2026-09-08 turn 2): the privacy
/// line, then **Face** — the avatar at the import review's size with Change ·
/// Adjust crop · Remove — and **Banner** — a strip the hero's own height,
/// dragged left or right into place, with Add / Change / Remove.
///
/// Its actions write *immediately* through [PersonPhotoActions], the same
/// object the avatar sheet uses, rather than waiting for the form's Save: a
/// picture is chosen the moment the picker returns and an entry already
/// exists, so "commit on Save" would mean tracking orphans to delete on
/// Cancel. Every profile editor treats a photo change as its own act, and so
/// does this one. After each write [onChanged] runs so the host can re-read
/// the person — a form that kept saving from the entry it opened with would
/// write the old photo back over the new one.
class PersonPhotoCard extends StatefulWidget {
  const PersonPhotoCard({
    required this.person,
    required this.actions,
    required this.onChanged,
    super.key,
  });

  /// The person as last read; the host refreshes it after [onChanged].
  final RelationshipEntry person;
  final PersonPhotoActions actions;

  /// Runs after a successful write, before the card settles.
  final Future<void> Function() onChanged;

  @override
  State<PersonPhotoCard> createState() => _PersonPhotoCardState();
}

class _PersonPhotoCardState extends State<PersonPhotoCard> {
  /// The banner's alignment while a drag is in progress — shown live, written
  /// once when the finger lifts, and forgotten once the host has re-read the
  /// person so the preview never snaps back to the old value for a frame.
  double? _draggingCropX;
  bool _busy = false;

  Future<void> _run(
    Future<PersonPhotoOutcome> Function(RelationshipEntry) flow,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    final outcome = await flow(widget.person);
    if (outcome == PersonPhotoOutcome.changed) await widget.onChanged();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _draggingCropX = null;
    });
    if (outcome == PersonPhotoOutcome.failed) {
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: context.messages.relationshipPhotoSaveFailed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final data = widget.person.data;
    final hasAvatar = data.avatarImageId != null;
    final hasBanner = data.bannerImageId != null;
    final labelStyle = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.lowEmphasis,
    );
    Widget gap(double height) => SizedBox(height: height);

    return DesignSystemSectionCard(
      key: const ValueKey('person-form-photo-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PersonCardHeader(title: messages.relationshipPhotoCardTitle),
          gap(tokens.spacing.step1),
          Text(
            messages.relationshipPhotoPrivacy,
            key: const ValueKey('person-form-photo-privacy'),
            style: labelStyle,
          ),
          gap(tokens.spacing.step4),
          Text(messages.relationshipPhotoFace, style: labelStyle),
          gap(tokens.spacing.step2),
          Row(
            children: [
              PersonaAvatar(
                key: const ValueKey('person-form-face-preview'),
                initial: personaInitial(data.title),
                id: widget.person.id,
                size: tokens.spacing.step9,
                imageId: data.avatarImageId,
                crop: data.avatarCrop,
              ),
              SizedBox(width: tokens.spacing.step4),
              Expanded(
                child: Wrap(
                  spacing: tokens.spacing.step2,
                  runSpacing: tokens.spacing.step2,
                  children: [
                    DesignSystemButton(
                      key: const ValueKey('person-form-face-change'),
                      label: hasAvatar
                          ? messages.relationshipPhotoChange
                          : messages.relationshipPhotoChoose,
                      variant: DesignSystemButtonVariant.secondary,
                      size: DesignSystemButtonSize.dense,
                      onPressed: _busy
                          ? null
                          : () => _run(widget.actions.chooseAvatar),
                    ),
                    if (hasAvatar) ...[
                      DesignSystemButton(
                        key: const ValueKey('person-form-face-crop'),
                        label: messages.relationshipPhotoAdjustCrop,
                        variant: DesignSystemButtonVariant.tertiary,
                        size: DesignSystemButtonSize.dense,
                        onPressed: _busy
                            ? null
                            : () => _run(widget.actions.adjustAvatar),
                      ),
                      DesignSystemButton(
                        key: const ValueKey('person-form-face-remove'),
                        label: messages.relationshipPhotoRemoveAction,
                        variant: DesignSystemButtonVariant.tertiary,
                        size: DesignSystemButtonSize.dense,
                        onPressed: _busy
                            ? null
                            : () => _run(widget.actions.removeAvatar),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          gap(tokens.spacing.step5),
          Text(messages.relationshipPhotoBanner, style: labelStyle),
          gap(tokens.spacing.step2),
          if (hasBanner)
            _BannerPreview(
              imageId: data.bannerImageId!,
              cropX: _draggingCropX ?? data.bannerCropX,
              enabled: !_busy,
              onDrag: (cropX) => setState(() => _draggingCropX = cropX),
              onDragEnd: () {
                final cropX = _draggingCropX;
                if (cropX == null) return;
                _run(
                  (person) => widget.actions.repositionBanner(person, cropX),
                );
              },
            ),
          gap(tokens.spacing.step2),
          Row(
            children: [
              if (hasBanner)
                Expanded(
                  child: Text(
                    messages.relationshipPhotoDragToReposition,
                    key: const ValueKey('person-form-banner-hint'),
                    style: labelStyle,
                  ),
                )
              else
                const Spacer(),
              DesignSystemButton(
                key: const ValueKey('person-form-banner-change'),
                label: hasBanner
                    ? messages.relationshipPhotoChange
                    : messages.relationshipPhotoAddBanner,
                variant: DesignSystemButtonVariant.secondary,
                size: DesignSystemButtonSize.dense,
                onPressed: _busy
                    ? null
                    : () => _run(widget.actions.chooseBanner),
              ),
              if (hasBanner) ...[
                SizedBox(width: tokens.spacing.step2),
                DesignSystemButton(
                  key: const ValueKey('person-form-banner-remove'),
                  label: messages.relationshipPhotoRemoveAction,
                  variant: DesignSystemButtonVariant.tertiary,
                  size: DesignSystemButtonSize.dense,
                  onPressed: _busy
                      ? null
                      : () => _run(widget.actions.removeBanner),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// The banner as the hero will draw it — its strip height, the card's width,
/// the same cover alignment — and draggable sideways. A drag moves the
/// picture under the finger by [CoverCropGeometry], the arithmetic the hero
/// renders with, so what the user frames here is what the page shows.
class _BannerPreview extends StatelessWidget {
  const _BannerPreview({
    required this.imageId,
    required this.cropX,
    required this.enabled,
    required this.onDrag,
    required this.onDragEnd,
  });

  final String imageId;
  final double cropX;
  final bool enabled;
  final ValueChanged<double> onDrag;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // The strip as the hero draws it, without a status inset.
    final height = PersonHeroAppBar.bannerStripExtent(tokens, topPadding: 0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(tokens.radii.m),
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewport = Size(constraints.maxWidth, height);
            return JournalImageResolver(
              imageId: imageId,
              builder: (context, resolved) {
                if (resolved == null || resolved.hasNothingToShow) {
                  return ColoredBox(color: PersonHeroAppBar.washColor(tokens));
                }
                final picture = ThumbHashBackedImage(
                  key: ValueKey(resolved.path),
                  thumbHash: resolved.thumbHash,
                  image: resolved.fileExists
                      ? boundedFileImage(
                          resolved.path,
                          bounds: viewport,
                          devicePixelRatio: MediaQuery.devicePixelRatioOf(
                            context,
                          ),
                        )
                      : null,
                  alignment: Alignment(cropX * 2 - 1, 0),
                );
                if (!resolved.fileExists) return picture;
                return FileImageSize(
                  path: resolved.path,
                  builder: (context, imageSize) => GestureDetector(
                    key: const ValueKey('person-form-banner-preview'),
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragUpdate: !enabled || imageSize == null
                        ? null
                        : (details) {
                            final geometry = CoverCropGeometry(
                              imageSize: imageSize,
                              viewport: viewport,
                            );
                            onDrag(
                              geometry
                                  .panBy(
                                    AvatarCrop(x: cropX),
                                    Offset(details.delta.dx, 0),
                                  )
                                  .x,
                            );
                          },
                    onHorizontalDragEnd: !enabled || imageSize == null
                        ? null
                        : (_) => onDragEnd(),
                    child: picture,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
