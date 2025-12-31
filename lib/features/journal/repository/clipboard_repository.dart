import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:super_clipboard/super_clipboard.dart';

part 'clipboard_repository.g.dart';

@riverpod
SystemClipboard? clipboardRepository(Ref ref) {
  return SystemClipboard.instance;
}
