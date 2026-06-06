import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';

/// Fake [LinkedEntriesController] for widget tests: serves [links] from
/// `build()` and records every mutation so tests can assert on the calls
/// without a repository.
class FakeLinkedEntriesController extends LinkedEntriesController {
  FakeLinkedEntriesController({this.links = const []});

  final List<EntryLink> links;

  /// Every link passed to [updateLink], in call order.
  final List<EntryLink> updateLinkCalls = [];

  /// Every `toId` passed to [removeLink], in call order.
  final List<String> removeLinkCalls = [];

  @override
  Future<List<EntryLink>> build({required String id}) async => links;

  @override
  Future<void> updateLink(EntryLink link) async {
    updateLinkCalls.add(link);
  }

  @override
  Future<void> removeLink({required String toId}) async {
    removeLinkCalls.add(toId);
  }
}
