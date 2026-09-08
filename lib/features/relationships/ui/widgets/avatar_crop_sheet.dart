import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/ui/shared/cover_crop_geometry.dart';
import 'package:lotti/features/relationships/ui/shared/persona_avatar.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/media/file_image_size.dart';
import 'package:lotti/widgets/media/journal_image_resolver.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// Opens the crop surface over [imageId] (design 2026-09-08 turn 2, "Choose
/// the face"): the picture in a square with a circular mask, one finger
/// drags it in both axes, two fingers or the wheel zoom, and a live 40 px
/// preview in the footer shows the result at list size — where a face is
/// hardest to read. Resolves to the framing the user committed with *Use
/// photo*, or null when they cancelled. **Writes nothing itself.**
Future<AvatarCrop?> showAvatarCropSheet({
  required BuildContext context,
  required RelationshipEntry relationship,
  required String imageId,
  AvatarCrop? initial,
}) {
  final handle = ValueNotifier<AvatarCrop>(initial ?? const AvatarCrop());
  return ModalUtils.showSinglePageModal<AvatarCrop>(
    context: context,
    title: context.messages.avatarCropTitle,
    padding: _sheetPadding(context),
    stickyActionBarBuilder: (_) => AvatarCropStickyActions(handle: handle),
    builder: (_) => AvatarCropForm(
      relationship: relationship,
      imageId: imageId,
      handle: handle,
    ),
  );
}

/// Room under the surface for the pinned action bar, so the preview row can
/// scroll fully above it — the check-in sheet's recipe.
EdgeInsets _sheetPadding(BuildContext context) {
  final tokens = context.designTokens;
  return EdgeInsets.fromLTRB(
    tokens.spacing.step5,
    tokens.spacing.step4,
    tokens.spacing.step5,
    tokens.spacing.step11 + tokens.spacing.step6,
  );
}

/// The pinned bar: *Use photo* commits the framing the form is publishing
/// through [handle]; Cancel pops with nothing.
class AvatarCropStickyActions extends StatelessWidget {
  const AvatarCropStickyActions({required this.handle, super.key});

  final ValueListenable<AvatarCrop> handle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return DesignSystemModalActionBar(
      glass: true,
      padding: EdgeInsets.all(tokens.spacing.step5),
      secondary: [
        DesignSystemButton(
          key: const ValueKey('avatar-crop-cancel'),
          label: messages.cancelButton,
          variant: DesignSystemButtonVariant.secondary,
          size: DesignSystemButtonSize.large,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      primary: DesignSystemButton(
        key: const ValueKey('avatar-crop-use'),
        label: messages.avatarCropUse,
        size: DesignSystemButtonSize.large,
        fullWidth: true,
        onPressed: () => Navigator.of(context).pop(handle.value),
      ),
    );
  }
}

/// How many wheel pixels zoom by a factor of *e*. Gesture tuning, not a
/// visual value: a common mouse notch is a few tens of pixels, so a notch
/// zooms by roughly ten percent.
const double _wheelPixelsPerE = 300;

/// The crop surface: a square viewport the picture moves under, a circular
/// mask on top, and the live preview. Publishes every change through
/// [handle]; commits nothing.
class AvatarCropForm extends StatefulWidget {
  const AvatarCropForm({
    required this.relationship,
    required this.imageId,
    required this.handle,
    this.readImageSize = readImageFileSize,
    super.key,
  });

  /// For the preview's accent and initial — the preview *is* a
  /// [PersonaAvatar], so it cannot disagree with the list.
  final RelationshipEntry relationship;
  final String imageId;
  final ValueNotifier<AvatarCrop> handle;

  /// How the surface learns the picture's size, which a drag moves against.
  /// Production reads the file's header; a test hands in the size.
  final ImageFileSizeReader readImageSize;

  @override
  State<AvatarCropForm> createState() => _AvatarCropFormState();
}

class _AvatarCropFormState extends State<AvatarCropForm> {
  /// The scale the current pinch started from, so each update is applied
  /// as a ratio rather than compounding.
  double _gestureScale = 1;

  AvatarCrop get _crop => widget.handle.value;
  set _crop(AvatarCrop value) => widget.handle.value = value;

  /// A drag needs the picture's own size to move against; until it is known
  /// ([FileImageSize] hands null) it is ignored. Zoom needs no size.
  void _pan(Offset delta, double side, Size? imageSize) {
    if (imageSize == null) return;
    final geometry = CoverCropGeometry.circle(
      imageSize: imageSize,
      diameter: side,
    );
    setState(() => _crop = geometry.panBy(_crop, delta));
  }

  void _zoom(double factor) {
    setState(() => _crop = CoverCropGeometry.zoomBy(_crop, factor));
  }

  /// The wheel zooms — and *claims* the event. A signal is offered to every
  /// listener under the pointer, and the sheet's own scroll view is one of
  /// them: without registering, a notch over the picture would zoom it and
  /// scroll the sheet under the cursor in the same instant. Registering
  /// first (the picture is innermost) is what makes the wheel exclusive.
  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || event.scrollDelta.dy == 0) return;
    GestureBinding.instance.pointerSignalResolver.register(
      event,
      _zoomFromWheel,
    );
  }

  void _zoomFromWheel(PointerSignalEvent event) {
    final scroll = event as PointerScrollEvent
      ..respond(allowPlatformDefault: false);
    _zoom(math.exp(-scroll.scrollDelta.dy / _wheelPixelsPerE));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final data = widget.relationship.data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          messages.avatarCropHint,
          key: const ValueKey('avatar-crop-hint'),
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.lowEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step4),
        // The square takes the width it is given; the picture moves under
        // the finger inside it, and the mask shows what the circle keeps.
        LayoutBuilder(
          builder: (context, constraints) {
            final side = constraints.maxWidth;
            return SizedBox(
              width: side,
              height: side,
              child: Listener(
                onPointerSignal: _handlePointerSignal,
                child: JournalImageResolver(
                  imageId: widget.imageId,
                  builder: (context, resolved) {
                    if (resolved == null || resolved.hasNothingToShow) {
                      return ColoredBox(
                        color: tokens.colors.background.level02,
                      );
                    }
                    Widget surface(Size? imageSize) => GestureDetector(
                      key: const ValueKey('avatar-crop-viewport'),
                      behavior: HitTestBehavior.opaque,
                      onScaleStart: (_) => _gestureScale = 1,
                      onScaleUpdate: (details) {
                        // One finger drags; two fingers only zoom. Two
                        // fingers arrive as separate events, each shifting
                        // the focal point, and panning on those would drift
                        // the picture through every pinch.
                        if (details.pointerCount == 1 &&
                            details.focalPointDelta != Offset.zero) {
                          _pan(details.focalPointDelta, side, imageSize);
                        }
                        if (details.scale != _gestureScale) {
                          _zoom(details.scale / _gestureScale);
                          _gestureScale = details.scale;
                        }
                      },
                      child: ClipRect(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            AvatarCropPicture(
                              resolved: resolved,
                              crop: _crop,
                              size: side,
                            ),
                            IgnorePointer(
                              child: CustomPaint(
                                painter: _CircleMaskPainter(
                                  scrim: ModalUtils.getModalBarrierColor(
                                    isDark:
                                        Theme.of(context).brightness ==
                                        Brightness.dark,
                                    context: context,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                    if (!resolved.fileExists) return surface(null);
                    return FileImageSize(
                      path: resolved.path,
                      read: widget.readImageSize,
                      builder: (context, imageSize) => surface(imageSize),
                    );
                  },
                ),
              ),
            );
          },
        ),
        SizedBox(height: tokens.spacing.step5),
        Row(
          children: [
            ValueListenableBuilder<AvatarCrop>(
              valueListenable: widget.handle,
              builder: (context, crop, _) => PersonaAvatar(
                key: const ValueKey('avatar-crop-preview'),
                initial: personaInitial(data.title),
                id: widget.relationship.id,
                imageId: widget.imageId,
                crop: crop,
              ),
            ),
            SizedBox(width: tokens.spacing.step4),
            Expanded(
              child: Text(
                messages.avatarCropPreviewLabel,
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Dims everything outside the inscribed circle with the app's own modal
/// scrim, so the user sees both what the circle keeps and what it drops.
class _CircleMaskPainter extends CustomPainter {
  const _CircleMaskPainter({required this.scrim});

  final Color scrim;

  @override
  void paint(Canvas canvas, Size size) {
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addOval(Offset.zero & size),
    );
    canvas.drawPath(outside, Paint()..color = scrim);
  }

  @override
  bool shouldRepaint(_CircleMaskPainter oldDelegate) =>
      scrim != oldDelegate.scrim;
}
