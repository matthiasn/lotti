import 'package:lotti/features/sync/subscription/sync_subscription_api.dart';
import 'package:lotti/features/sync/subscription/sync_subscription_controller.dart';

/// Lets a widget test set the subscribe flow's state directly and records
/// what the UI asks of it, without any network or keystore behind it.
class FakeSyncSubscriptionController extends SyncSubscriptionController {
  FakeSyncSubscriptionController([this._initial = const SyncSubscribeIdle()]);

  final SyncSubscribeState _initial;
  final calls = <String>[];

  @override
  SyncSubscribeState build() => _initial;

  // ignore: use_setters_to_change_properties - mirrors a state transition
  void emit(SyncSubscribeState next) => state = next;

  @override
  Future<void> resume() async => calls.add('resume');

  @override
  Future<void> subscribe(SyncSubscriptionPlan plan) async =>
      calls.add('subscribe:${plan.name}');

  @override
  Future<void> reopenCheckout() async => calls.add('reopen');

  @override
  void cancel() => calls.add('cancel');
}
