import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Retains the most recently loaded value of an [AsyncValue] across rebuilds —
/// including when the underlying provider *key* changes.
///
/// The dashboard chart providers are keyed by their date range, so changing the
/// time span swaps every chart to a brand-new provider family member that
/// starts in [AsyncLoading] with no value. Without this, the charts would flash
/// a loading spinner / "No data" shell on every time-span change. Holding the
/// last loaded value lets a chart keep showing the previous data until the new
/// data arrives (stale-while-revalidate).
///
/// Hold one instance per data stream as a field on a ConsumerState; for the
/// common single-stream case use [StaleAsyncValue] instead.
class StaleValue<T> {
  T? _value;

  /// The freshest available value: the new value once loaded, otherwise the
  /// last loaded value, otherwise null before anything has ever loaded.
  T? resolve(AsyncValue<T> async) {
    if (async.hasValue) {
      _value = async.value;
    }
    return _value;
  }

  /// True only while loading with nothing loaded yet — the genuine first load,
  /// not a key-change refresh (which should keep the stale value on screen).
  bool isInitialLoading(AsyncValue<T> async) =>
      async.isLoading && _value == null;
}

/// Widget form of [StaleValue] for the common single-stream chart. The host
/// `ConsumerWidget` does the `ref.watch` and passes the resulting [async] in;
/// this widget caches the last loaded value across rebuilds (so a time-span
/// change keeps the previous data on screen) and rebuilds `builder` with the
/// freshest-available data (null only before the first load) and an
/// `isInitialLoading` flag.
class StaleAsyncValue<T> extends StatefulWidget {
  const StaleAsyncValue({
    required this.async,
    required this.builder,
    super.key,
  });

  final AsyncValue<T> async;

  // ignore: avoid_positional_boolean_parameters
  final Widget Function(BuildContext context, T? data, bool isInitialLoading)
  builder;

  @override
  State<StaleAsyncValue<T>> createState() => _StaleAsyncValueState<T>();
}

class _StaleAsyncValueState<T> extends State<StaleAsyncValue<T>> {
  final StaleValue<T> _stale = StaleValue<T>();

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      _stale.resolve(widget.async),
      _stale.isInitialLoading(widget.async),
    );
  }
}
