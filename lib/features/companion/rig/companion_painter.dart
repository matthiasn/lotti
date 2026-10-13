import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_pose.dart';
import 'package:lotti/features/companion/rig/body_painter.dart';
import 'package:lotti/features/companion/rig/head_painter.dart';
import 'package:lotti/features/companion/rig/rig_frame.dart';
import 'package:lotti/features/companion/rig/stage_painter.dart';

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

  /// Stands her on the videos' dark stage instead of a clear background.
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
    if (stage) {
      CompanionStage.paintGround(
        canvas,
        size,
        const Offset(0, -250) * scale + offset,
        380 * scale,
      );
    }
    canvas
      ..save()
      ..clipRect(Offset.zero & size)
      ..translate(offset.dx, offset.dy)
      ..scale(scale);
    final f = RigFrame(pose);
    if (stage) CompanionStage.paintFloorShadow(canvas);
    drawBackOfHead(canvas, f, look);
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
    if (stage) CompanionStage.paintVignette(canvas, size);
  }

  @override
  bool shouldRepaint(CompanionPainter oldDelegate) =>
      oldDelegate.pose != pose ||
      oldDelegate.look != look ||
      oldDelegate.framing != framing ||
      oldDelegate.stage != stage;
}
