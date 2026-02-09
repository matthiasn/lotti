// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rating_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(RatingController)
final ratingControllerProvider = RatingControllerFamily._();

final class RatingControllerProvider
    extends $AsyncNotifierProvider<RatingController, JournalEntity?> {
  RatingControllerProvider._(
      {required RatingControllerFamily super.from,
      required ({
        String targetId,
        String catalogId,
      })
          super.argument})
      : super(
          retry: null,
          name: r'ratingControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$ratingControllerHash();

  @override
  String toString() {
    return r'ratingControllerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  RatingController create() => RatingController();

  @override
  bool operator ==(Object other) {
    return other is RatingControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$ratingControllerHash() => r'928761becac741d5d98985803d506e042919acdf';

final class RatingControllerFamily extends $Family
    with
        $ClassFamilyOverride<
            RatingController,
            AsyncValue<JournalEntity?>,
            JournalEntity?,
            FutureOr<JournalEntity?>,
            ({
              String targetId,
              String catalogId,
            })> {
  RatingControllerFamily._()
      : super(
          retry: null,
          name: r'ratingControllerProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  RatingControllerProvider call({
    required String targetId,
    String catalogId = 'session',
  }) =>
      RatingControllerProvider._(argument: (
        targetId: targetId,
        catalogId: catalogId,
      ), from: this);

  @override
  String toString() => r'ratingControllerProvider';
}

abstract class _$RatingController extends $AsyncNotifier<JournalEntity?> {
  late final _$args = ref.$arg as ({
    String targetId,
    String catalogId,
  });
  String get targetId => _$args.targetId;
  String get catalogId => _$args.catalogId;

  FutureOr<JournalEntity?> build({
    required String targetId,
    String catalogId = 'session',
  });
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<JournalEntity?>, JournalEntity?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<JournalEntity?>, JournalEntity?>,
        AsyncValue<JournalEntity?>,
        Object?,
        Object?>;
    element.handleCreate(
        ref,
        () => build(
              targetId: _$args.targetId,
              catalogId: _$args.catalogId,
            ));
  }
}
