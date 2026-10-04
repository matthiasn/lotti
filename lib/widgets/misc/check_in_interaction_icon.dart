import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// The glyph for a check-in's interaction type.
IconData checkInInteractionIcon(CheckInInteractionType type) => switch (type) {
  CheckInInteractionType.inPerson => LottiIcons.people,
  CheckInInteractionType.call => LottiIcons.call,
  CheckInInteractionType.videoCall => LottiIcons.video,
  CheckInInteractionType.message => LottiIcons.chat,
  CheckInInteractionType.other => LottiIcons.forum,
};
