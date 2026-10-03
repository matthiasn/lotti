import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/github/state/github_providers.dart';

/// The titles of the other tasks in [taskIds] that hold a pull request, in
/// id order, so a label reads the same on every rebuild: null for one the
/// viewer may not see — private mode hides it — or that has not loaded yet.
List<String?> watchLinkedElsewhereTitles(
  WidgetRef ref,
  Iterable<String> taskIds,
) => [
  for (final id in taskIds.toList()..sort())
    ref.watch(pullRequestHolderTitleProvider(id)).value,
];

/// The one other task's title when there is exactly one and it may be
/// shown, so a label can name it; null when the label has to count.
String? soleLinkedElsewhereTitle(List<String?> titles) =>
    titles.length == 1 ? titles.single : null;
