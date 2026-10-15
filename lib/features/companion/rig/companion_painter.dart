import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_pose.dart';
import 'package:lotti/features/companion/rig/body_painter.dart';
import 'package:lotti/features/companion/rig/head_painter.dart';
import 'package:lotti/features/companion/rig/rig_frame.dart';
import 'package:lotti/features/companion/rig/stage_painter.dart';
import 'package:lotti/features/companion/rig/tail_painter.dart';

/// How much of her the view shows.
enum CompanionFraming {
  /// Head to toe.
  full(Rect.fromLTRB(-160, -470, 160, 15)),

  /// Head, shoulders and the hands when they come up: the size for a chat.
  bust(Rect.fromLTRB(-115, -452, 115, -222));

  const CompanionFraming(this.window);

  /// The part of character space that is fitted into the view.
  final Rect window;
}

/// Paints one [pose] of the companion in [look], fitting [framing]'s window
/// into the canvas.
///
/// Only her: the stage she stands on is [CompanionStageGround] behind her and
/// [CompanionStageVignette] over her, painted separately so that a
/// `SupersampledPainter` wrapping this one draws only edges that can alias,
/// never the full-view gradients.
class CompanionPainter extends CustomPainter {
  CompanionPainter({
    required this.pose,
    required this.look,
    this.framing = CompanionFraming.full,
    this.stage = false,
  });

  final CompanionPose pose;
  final CompanionLook look;
  final CompanionFraming framing;

  /// Casts her shadow on the stage's floor; set it when she stands on
  /// [CompanionStageGround].
  final bool stage;

  /// The scale and offset that fit [framing]'s window into [size], centred.
  static (double, Offset) fit(Size size, CompanionFraming framing) {
    final w = framing.window;
    final scale = math.min(size.width / w.width, size.height / w.height);
    final offset = Offset(
      (size.width - w.width * scale) / 2 - w.left * scale,
      (size.height - w.height * scale) / 2 - w.top * scale,
    );
    return (scale, offset);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final (scale, offset) = fit(size, framing);
    canvas
      ..save()
      ..clipRect(Offset.zero & size)
      ..translate(offset.dx, offset.dy)
      ..scale(scale);
    final f = RigFrame(pose);
    if (stage) CompanionStage.paintFloorShadow(canvas);
    drawBackOfHead(canvas, f, look);
    drawTail(canvas, f, look);
    drawLegs(canvas, f, look);
    drawNeck(canvas, f, look);
    drawDress(canvas, f, look);
    if (!pose.handInFrontOfFace) drawHead(canvas, f, look);
    drawArm(canvas, f, look, pose.left, -1);
    drawArm(canvas, f, look, pose.right, 1);
    if (pose.handInFrontOfFace) {
      // The head first, then the arm that reaches the face over it.
      drawHead(canvas, f, look);
      drawArm(canvas, f, look, pose.right, 1);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(CompanionPainter oldDelegate) =>
      oldDelegate.pose != pose ||
      oldDelegate.look != look ||
      oldDelegate.framing != framing ||
      oldDelegate.stage != stage;
}

/// The videos' dark stage behind her: the ground and the light centred on
/// her, fitted to [framing] the way [CompanionPainter] fits her.
class CompanionStageGround extends CustomPainter {
  const CompanionStageGround({this.framing = CompanionFraming.full});

  final CompanionFraming framing;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final (scale, offset) = CompanionPainter.fit(size, framing);
    CompanionStage.paintGround(
      canvas,
      size,
      const Offset(0, -250) * scale + offset,
      380 * scale,
    );
  }

  @override
  bool shouldRepaint(CompanionStageGround oldDelegate) =>
      oldDelegate.framing != framing;
}

/// The stage's vignette, darkening the edges of the view over her.
class CompanionStageVignette extends CustomPainter {
  const CompanionStageVignette();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    CompanionStage.paintVignette(canvas, size);
  }

  @override
  bool shouldRepaint(CompanionStageVignette oldDelegate) => false;
}
