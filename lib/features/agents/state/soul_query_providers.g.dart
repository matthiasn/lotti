// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'soul_query_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// List all non-deleted soul documents.
///
/// Each element is a [SoulDocumentEntity].
/// Relies on manual `ref.invalidate()` at mutation sites (create, delete)
/// rather than watching the global notification stream.

@ProviderFor(allSoulDocuments)
final allSoulDocumentsProvider = AllSoulDocumentsProvider._();

/// List all non-deleted soul documents.
///
/// Each element is a [SoulDocumentEntity].
/// Relies on manual `ref.invalidate()` at mutation sites (create, delete)
/// rather than watching the global notification stream.

final class AllSoulDocumentsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AgentDomainEntity>>,
          List<AgentDomainEntity>,
          FutureOr<List<AgentDomainEntity>>
        >
    with
        $FutureModifier<List<AgentDomainEntity>>,
        $FutureProvider<List<AgentDomainEntity>> {
  /// List all non-deleted soul documents.
  ///
  /// Each element is a [SoulDocumentEntity].
  /// Relies on manual `ref.invalidate()` at mutation sites (create, delete)
  /// rather than watching the global notification stream.
  AllSoulDocumentsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allSoulDocumentsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allSoulDocumentsHash();

  @$internal
  @override
  $FutureProviderElement<List<AgentDomainEntity>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AgentDomainEntity>> create(Ref ref) {
    return allSoulDocuments(ref);
  }
}

String _$allSoulDocumentsHash() => r'5265b5a5b8dd3709634f897ffd84020039ec7442';

/// Fetch a single soul document by [soulId].
///
/// The returned entity is a [SoulDocumentEntity] (or `null`).

@ProviderFor(soulDocument)
final soulDocumentProvider = SoulDocumentFamily._();

/// Fetch a single soul document by [soulId].
///
/// The returned entity is a [SoulDocumentEntity] (or `null`).

final class SoulDocumentProvider
    extends
        $FunctionalProvider<
          AsyncValue<AgentDomainEntity?>,
          AgentDomainEntity?,
          FutureOr<AgentDomainEntity?>
        >
    with
        $FutureModifier<AgentDomainEntity?>,
        $FutureProvider<AgentDomainEntity?> {
  /// Fetch a single soul document by [soulId].
  ///
  /// The returned entity is a [SoulDocumentEntity] (or `null`).
  SoulDocumentProvider._({
    required SoulDocumentFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'soulDocumentProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$soulDocumentHash();

  @override
  String toString() {
    return r'soulDocumentProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<AgentDomainEntity?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AgentDomainEntity?> create(Ref ref) {
    final argument = this.argument as String;
    return soulDocument(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SoulDocumentProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$soulDocumentHash() => r'5276a6b207dc8bce42385a8488422d98029a0024';

/// Fetch a single soul document by [soulId].
///
/// The returned entity is a [SoulDocumentEntity] (or `null`).

final class SoulDocumentFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<AgentDomainEntity?>, String> {
  SoulDocumentFamily._()
    : super(
        retry: null,
        name: r'soulDocumentProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Fetch a single soul document by [soulId].
  ///
  /// The returned entity is a [SoulDocumentEntity] (or `null`).

  SoulDocumentProvider call(String soulId) =>
      SoulDocumentProvider._(argument: soulId, from: this);

  @override
  String toString() => r'soulDocumentProvider';
}

/// Fetch the active version for a soul document by [soulId].
///
/// The returned entity is a [SoulDocumentVersionEntity] (or `null`).

@ProviderFor(activeSoulVersion)
final activeSoulVersionProvider = ActiveSoulVersionFamily._();

/// Fetch the active version for a soul document by [soulId].
///
/// The returned entity is a [SoulDocumentVersionEntity] (or `null`).

final class ActiveSoulVersionProvider
    extends
        $FunctionalProvider<
          AsyncValue<AgentDomainEntity?>,
          AgentDomainEntity?,
          FutureOr<AgentDomainEntity?>
        >
    with
        $FutureModifier<AgentDomainEntity?>,
        $FutureProvider<AgentDomainEntity?> {
  /// Fetch the active version for a soul document by [soulId].
  ///
  /// The returned entity is a [SoulDocumentVersionEntity] (or `null`).
  ActiveSoulVersionProvider._({
    required ActiveSoulVersionFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'activeSoulVersionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$activeSoulVersionHash();

  @override
  String toString() {
    return r'activeSoulVersionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<AgentDomainEntity?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AgentDomainEntity?> create(Ref ref) {
    final argument = this.argument as String;
    return activeSoulVersion(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ActiveSoulVersionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$activeSoulVersionHash() => r'e28fb73160ee929427adbaf96e09b1d70cf0968d';

/// Fetch the active version for a soul document by [soulId].
///
/// The returned entity is a [SoulDocumentVersionEntity] (or `null`).

final class ActiveSoulVersionFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<AgentDomainEntity?>, String> {
  ActiveSoulVersionFamily._()
    : super(
        retry: null,
        name: r'activeSoulVersionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Fetch the active version for a soul document by [soulId].
  ///
  /// The returned entity is a [SoulDocumentVersionEntity] (or `null`).

  ActiveSoulVersionProvider call(String soulId) =>
      ActiveSoulVersionProvider._(argument: soulId, from: this);

  @override
  String toString() => r'activeSoulVersionProvider';
}

/// Fetch the version history for a soul document by [soulId].
///
/// Each element is a [SoulDocumentVersionEntity].

@ProviderFor(soulVersionHistory)
final soulVersionHistoryProvider = SoulVersionHistoryFamily._();

/// Fetch the version history for a soul document by [soulId].
///
/// Each element is a [SoulDocumentVersionEntity].

final class SoulVersionHistoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AgentDomainEntity>>,
          List<AgentDomainEntity>,
          FutureOr<List<AgentDomainEntity>>
        >
    with
        $FutureModifier<List<AgentDomainEntity>>,
        $FutureProvider<List<AgentDomainEntity>> {
  /// Fetch the version history for a soul document by [soulId].
  ///
  /// Each element is a [SoulDocumentVersionEntity].
  SoulVersionHistoryProvider._({
    required SoulVersionHistoryFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'soulVersionHistoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$soulVersionHistoryHash();

  @override
  String toString() {
    return r'soulVersionHistoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<AgentDomainEntity>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AgentDomainEntity>> create(Ref ref) {
    final argument = this.argument as String;
    return soulVersionHistory(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SoulVersionHistoryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$soulVersionHistoryHash() =>
    r'90f0383a5e01ac76fecf5895c998594395918660';

/// Fetch the version history for a soul document by [soulId].
///
/// Each element is a [SoulDocumentVersionEntity].

final class SoulVersionHistoryFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<AgentDomainEntity>>, String> {
  SoulVersionHistoryFamily._()
    : super(
        retry: null,
        name: r'soulVersionHistoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Fetch the version history for a soul document by [soulId].
  ///
  /// Each element is a [SoulDocumentVersionEntity].

  SoulVersionHistoryProvider call(String soulId) =>
      SoulVersionHistoryProvider._(argument: soulId, from: this);

  @override
  String toString() => r'soulVersionHistoryProvider';
}

/// Resolve the active soul version assigned to a template by [templateId].
///
/// The returned entity is a [SoulDocumentVersionEntity] (or `null`).

@ProviderFor(soulForTemplate)
final soulForTemplateProvider = SoulForTemplateFamily._();

/// Resolve the active soul version assigned to a template by [templateId].
///
/// The returned entity is a [SoulDocumentVersionEntity] (or `null`).

final class SoulForTemplateProvider
    extends
        $FunctionalProvider<
          AsyncValue<AgentDomainEntity?>,
          AgentDomainEntity?,
          FutureOr<AgentDomainEntity?>
        >
    with
        $FutureModifier<AgentDomainEntity?>,
        $FutureProvider<AgentDomainEntity?> {
  /// Resolve the active soul version assigned to a template by [templateId].
  ///
  /// The returned entity is a [SoulDocumentVersionEntity] (or `null`).
  SoulForTemplateProvider._({
    required SoulForTemplateFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'soulForTemplateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$soulForTemplateHash();

  @override
  String toString() {
    return r'soulForTemplateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<AgentDomainEntity?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AgentDomainEntity?> create(Ref ref) {
    final argument = this.argument as String;
    return soulForTemplate(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SoulForTemplateProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$soulForTemplateHash() => r'8a63f69db34bc3fcd596d191af2785544422d0f2';

/// Resolve the active soul version assigned to a template by [templateId].
///
/// The returned entity is a [SoulDocumentVersionEntity] (or `null`).

final class SoulForTemplateFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<AgentDomainEntity?>, String> {
  SoulForTemplateFamily._()
    : super(
        retry: null,
        name: r'soulForTemplateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Resolve the active soul version assigned to a template by [templateId].
  ///
  /// The returned entity is a [SoulDocumentVersionEntity] (or `null`).

  SoulForTemplateProvider call(String templateId) =>
      SoulForTemplateProvider._(argument: templateId, from: this);

  @override
  String toString() => r'soulForTemplateProvider';
}

/// Reverse lookup: find template IDs that use a given soul by [soulId].

@ProviderFor(templatesUsingSoul)
final templatesUsingSoulProvider = TemplatesUsingSoulFamily._();

/// Reverse lookup: find template IDs that use a given soul by [soulId].

final class TemplatesUsingSoulProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<String>>,
          List<String>,
          FutureOr<List<String>>
        >
    with $FutureModifier<List<String>>, $FutureProvider<List<String>> {
  /// Reverse lookup: find template IDs that use a given soul by [soulId].
  TemplatesUsingSoulProvider._({
    required TemplatesUsingSoulFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'templatesUsingSoulProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$templatesUsingSoulHash();

  @override
  String toString() {
    return r'templatesUsingSoulProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<String>> create(Ref ref) {
    final argument = this.argument as String;
    return templatesUsingSoul(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TemplatesUsingSoulProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$templatesUsingSoulHash() =>
    r'36d3cd57712fe1496f9751a5d3b66c60f80be580';

/// Reverse lookup: find template IDs that use a given soul by [soulId].

final class TemplatesUsingSoulFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<String>>, String> {
  TemplatesUsingSoulFamily._()
    : super(
        retry: null,
        name: r'templatesUsingSoulProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Reverse lookup: find template IDs that use a given soul by [soulId].

  TemplatesUsingSoulProvider call(String soulId) =>
      TemplatesUsingSoulProvider._(argument: soulId, from: this);

  @override
  String toString() => r'templatesUsingSoulProvider';
}
