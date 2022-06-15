import 'package:collection/collection.dart';

// This function returns a stateful stream filter
// function that compares the previous event on
// the stream with the latest, and filters those
// that are found equal using deep collection
// equality. This allows exactly once deliver on
// a stream instead of at least once previously,
// which lead to plenty of costly re-renders.
bool Function(T next) makeDuplicateFilter<T>() {
  final deepEq = const DeepCollectionEquality().equals;
  T? prev;

  bool duplicateFilter(T next) {
    if (deepEq(prev, next)) {
      return false;
    } else {
      prev = next;
      return true;
    }
  }

  return duplicateFilter;
}
