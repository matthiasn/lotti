// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Kept-alive provider for the singleton [ProjectRepository], wired to the
/// app's database, caches, persistence, and update-notification services from
/// `getIt`. Every project provider in this feature reads through here.

@ProviderFor(projectRepository)
final projectRepositoryProvider = ProjectRepositoryProvider._();

/// Kept-alive provider for the singleton [ProjectRepository], wired to the
/// app's database, caches, persistence, and update-notification services from
/// `getIt`. Every project provider in this feature reads through here.

final class ProjectRepositoryProvider
    extends
        $FunctionalProvider<
          ProjectRepository,
          ProjectRepository,
          ProjectRepository
        >
    with $Provider<ProjectRepository> {
  /// Kept-alive provider for the singleton [ProjectRepository], wired to the
  /// app's database, caches, persistence, and update-notification services from
  /// `getIt`. Every project provider in this feature reads through here.
  ProjectRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'projectRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$projectRepositoryHash();

  @$internal
  @override
  $ProviderElement<ProjectRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProjectRepository create(Ref ref) {
    return projectRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProjectRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProjectRepository>(value),
    );
  }
}

String _$projectRepositoryHash() => r'a7e4fb1c6d7f16e274d7c928f9b4b815da8c16a8';
