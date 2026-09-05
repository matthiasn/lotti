import 'package:material_ui/material_ui.dart';

class WoltModalConfig {
  static const pageBreakpoint = 560;
  static const pagePadding = EdgeInsets.all(16);

  /// Bottom inset a page needs so its last block clears a sticky action bar:
  /// [pagePadding] top and bottom plus a large button. Named because it was
  /// copy-pasted as a bare `80` into every page that has one, with nothing
  /// tying it to the bar it has to clear.
  static const double stickyActionBarClearance = 80;
}
