import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/relationships/service/contact_launcher.dart';
import 'package:lotti/features/relationships/util/contact_channel_uri.dart';

/// A launcher whose answers are scripted per action and whose launches are
/// recorded, so a widget's two decisions — which actions to offer, and what
/// to do when one is chosen — are both observable.
///
/// [canLaunch] also requires the channel to map to a URI, as the real
/// launcher does, so a number like "ask Bob" offers nothing.
class FakeContactLauncher implements ContactLauncher {
  FakeContactLauncher({
    this.launchable = const {
      ContactAction.call,
      ContactAction.message,
      ContactAction.email,
    },
    this.launchSucceeds = true,
  });

  final Set<ContactAction> launchable;
  final bool launchSucceeds;
  final List<(ContactChannel, ContactAction)> launched = [];

  @override
  Future<bool> canLaunch(ContactChannel channel, ContactAction action) async =>
      launchable.contains(action) && contactChannelUri(channel, action) != null;

  @override
  Future<bool> launch(ContactChannel channel, ContactAction action) async {
    launched.add((channel, action));
    return launchSucceeds;
  }
}
