import 'package:beamer/beamer.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'nav_state.freezed.dart';

@freezed
class NavState with _$NavState {
  factory NavState({
    required int index,
    required String path,
    required List<BeamerDelegate> beamerDelegates,
  }) = _NavState;
}
