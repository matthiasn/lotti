import 'package:share_plus/share_plus.dart';

class ShareService {
  ShareService({SharePlus? sharePlus}) : this._(sharePlus);

  ShareService._(this._sharePlus);

  /// Injectable for tests: `SharePlus.instance` is a lazy `static final`
  /// that captures `SharePlatform.instance` at first access, so platform
  /// doubles installed later are silently ignored in a shared test isolate.
  /// Constructing with `SharePlus.custom(mockPlatform)` sidesteps the
  /// global singleton entirely.
  final SharePlus? _sharePlus;

  Future<void> shareText({required String text, String? subject}) async {
    final sharePlus = _sharePlus ?? SharePlus.instance;
    await sharePlus.share(ShareParams(text: text, subject: subject));
  }

  static ShareService instance = ShareService();
}
