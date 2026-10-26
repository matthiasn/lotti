import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the thread is filtered to the turns with a door still waiting on
/// the user — the inbox is that filter, not another place (decision 7).
/// Off every time the sheet opens.
final NotifierProvider<FrontInboxFilter, bool> frontInboxFilterProvider =
    NotifierProvider.autoDispose<FrontInboxFilter, bool>(
      FrontInboxFilter.new,
      name: 'frontInboxFilterProvider',
    );

class FrontInboxFilter extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}
