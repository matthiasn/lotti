import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';

/// Fake [LinkedEntriesController] for widget tests: serves [links] from
/// `build()` and records every mutation so tests can assert on the calls
/// without a repository.
class FakeLinkedEntriesController extends LinkedEntriesController {
  FakeLinkedEntriesController({this.links = const [], String id = ''})
    : super(id);

  final List<EntryLink> links;

  /// Every `(linkId, hidden)` passed to [setLinkHidden], in call order.
  final List<({String linkId, bool hidden})> setLinkHiddenCalls = [];

  /// Every `toId` passed to [removeLink], in call order.
  final List<String> removeLinkCalls = [];

  @override
  Future<List<EntryLink>> build() async => links;

  @override
  Future<void> setLinkHidden(String linkId, {required bool hidden}) async {
    setLinkHiddenCalls.add((linkId: linkId, hidden: hidden));
  }

  @override
  Future<void> removeLink({required String toId}) async {
    removeLinkCalls.add(toId);
  }
}
