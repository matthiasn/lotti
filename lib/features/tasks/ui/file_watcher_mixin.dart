/// The file-watcher mixin's former home, forwarding to where it lives now.
///
/// The mixin moved to `lib/widgets/media/` so widgets outside `features/tasks`
/// can share it. `main` gained the plaza feature after this branch forked, and
/// plaza's `cover_image.dart` imports the mixin from this path, so the merge of
/// the two would not compile without this file. Nothing on this branch imports
/// it. Remove it once plaza points at `lib/widgets/media/file_watcher_mixin.dart`.
library;

export 'package:lotti/widgets/media/file_watcher_mixin.dart';
