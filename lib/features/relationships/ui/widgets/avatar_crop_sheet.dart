import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/ui/shared/avatar_crop_geometry.dart';
import 'package:lotti/features/relationships/ui/shared/persona_avatar.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
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
    super.key,
  });

  /// For the preview's accent and initial — the preview *is* a
  /// [PersonaAvatar], so it cannot disagree with the list.
  final RelationshipEntry relationship;
  final String imageId;
  final ValueNotifier<AvatarCrop> handle;

  @override
  State<AvatarCropForm> createState() => _AvatarCropFormState();
}

class _AvatarCropFormState extends State<AvatarCropForm> {
  /// The picture's own size, once decoded. Until then a drag has no
  /// geometry to move against and is ignored; zoom needs no size.
  Size? _imageSize;
  String? _probedPath;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  /// The scale the current pinch started from, so each update is applied
  /// as a ratio rather than compounding.
  double _gestureScale = 1;

  AvatarCrop get _crop => widget.handle.value;
  set _crop(AvatarCrop value) => widget.handle.value = value;

  @override
  void dispose() {
    _stopProbe();
    super.dispose();
  }

  void _stopProbe() {
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  /// Learns the picture's size from the file on disk, once per path. Started
  /// after the frame so a synchronously cached picture cannot set state in
  /// the middle of a build.
  void _probeSize(String path) {
    if (_probedPath == path) return;
    _probedPath = path;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _stopProbe();
      final stream = FileImage(File(path)).resolve(ImageConfiguration.empty);
      final listener = ImageStreamListener((info, _) {
        if (!mounted) return;
        setState(() {
          _imageSize = Size(
            info.image.width.toDouble(),
            info.image.height.toDouble(),
          );
        });
        info.dispose();
      });
      _stream = stream;
      _listener = listener;
      stream.addListener(listener);
    });
  }

  void _pan(Offset delta, double side) {
    final size = _imageSize;
    if (size == null) return;
    final geometry = AvatarCropGeometry(imageSize: size, diameter: side);
    setState(() => _crop = geometry.panBy(_crop, delta));
  }

  void _zoom(double factor) {
    setState(() => _crop = AvatarCropGeometry.zoomBy(_crop, factor));
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
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent) {
                    _zoom(math.exp(-event.scrollDelta.dy / _wheelPixelsPerE));
                  }
                },
                child: GestureDetector(
                  key: const ValueKey('avatar-crop-viewport'),
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: (_) => _gestureScale = 1,
                  onScaleUpdate: (details) {
                    // One finger drags; two fingers only zoom. Two fingers
                    // arrive as separate events, each shifting the focal
                    // point, and panning on those would drift the picture
                    // through every pinch.
                    if (details.pointerCount == 1 &&
                        details.focalPointDelta != Offset.zero) {
                      _pan(details.focalPointDelta, side);
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
                        JournalImageResolver(
                          imageId: widget.imageId,
                          builder: (context, resolved) {
                            if (resolved == null || resolved.hasNothingToShow) {
                              return ColoredBox(
                                color: tokens.colors.background.level02,
                              );
                            }
                            if (resolved.fileExists) {
                              _probeSize(resolved.path);
                            }
                            return AvatarCropPicture(
                              resolved: resolved,
                              crop: _crop,
                              size: side,
                            );
                          },
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
