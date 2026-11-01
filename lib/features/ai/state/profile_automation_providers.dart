import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/helpers/profile_automation_resolver.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/services/profile_automation_service.dart';
import 'package:lotti/features/ai/util/profile_resolver.dart';
import 'package:lotti/providers/service_providers.dart'
    show domainLoggerProvider, journalDbProvider;

final profileResolverProvider = Provider<ProfileResolver>(
  profileResolver,
  name: 'profileResolverProvider',
);
ProfileResolver profileResolver(Ref ref) {
  return ProfileResolver(
    aiConfigRepository: ref.watch(aiConfigRepositoryProvider),
    domainLogger: ref.watch(domainLoggerProvider),
  );
}

/// The `profileId` a subject entity carries in its own payload.
///
/// Every entity kind that can own an agent also inherits a profile from its
/// category at creation, and each stores it in its own `data`. Reading only
/// the task variant is what made a spoken check-in resolve no profile even
/// when the person had one.
String? subjectProfileIdOf(JournalEntity? entity) => switch (entity) {
  final Task task => task.data.profileId,
  final ProjectEntry project => project.data.profileId,
  final RelationshipEntry relationship => relationship.data.profileId,
  _ => null,
};

/// The agent assigned to a subject, for [ProfileAutomationResolver]. The
/// composition root wires the agents feature's subject resolver.
final automationSubjectAgentLookupProvider =
    Provider<AutomationSubjectAgentLookup>(
      (ref) => throw UnimplementedError(
        'automationSubjectAgentLookupProvider must be overridden before use.',
      ),
      name: 'automationSubjectAgentLookupProvider',
    );

/// Template lookups for [ProfileAutomationResolver]. The composition root
/// wires the agents feature's template service.
final automationTemplateLookupProvider = Provider<AgentTemplateVersionLookup>(
  (ref) => throw UnimplementedError(
    'automationTemplateLookupProvider must be overridden before use.',
  ),
  name: 'automationTemplateLookupProvider',
);

final profileAutomationResolverProvider = Provider<ProfileAutomationResolver>(
  profileAutomationResolver,
  name: 'profileAutomationResolverProvider',
);
ProfileAutomationResolver profileAutomationResolver(Ref ref) {
  return ProfileAutomationResolver(
    subjectAgentLookup: ref.watch(automationSubjectAgentLookupProvider),
    templateService: ref.watch(automationTemplateLookupProvider),
    profileResolver: ref.watch(profileResolverProvider),
    domainLogger: ref.watch(domainLoggerProvider),
    subjectProfileLookup: (subjectId) async {
      final entity = await ref
          .read(journalDbProvider)
          .journalEntityById(subjectId);
      return subjectProfileIdOf(entity);
    },
    categoryProfileLookup: (categoryId) async {
      final category = await ref
          .read(journalDbProvider)
          .getCategoryById(categoryId);
      return category?.defaultProfileId;
    },
    subjectCategoryLookup: (subjectId) async {
      final entity = await ref
          .read(journalDbProvider)
          .journalEntityById(subjectId);
      return entity?.meta.categoryId;
    },
  );
}

/// Whether a category's automatic-inference switch has anything to control.
///
/// Keyed by the category's `defaultProfileId` (nullable). The switch governs
/// every inference that runs in the category without a gesture: transcribing
/// and analysing new entries, and summarising its tasks' pull requests. So it
/// has something to control when any of them could run:
///
/// - that profile carries an `automate: true` skill assignment;
/// - that profile resolves — its thinking model summarises pull requests,
///   and its transcription slot, if any, transcribes recordings;
/// - the device's Settings default resolves, which both fall back to.
///
/// The form also shows the switch whenever it is on, so automation that was
/// consented to can always be switched off again.
final FutureProviderFamily<bool, String?> categoryAutomationAvailableProvider =
    FutureProvider.family<bool, String?>(
      categoryAutomationAvailable,
      name: 'categoryAutomationAvailableProvider',
    );
Future<bool> categoryAutomationAvailable(Ref ref, String? profileId) async {
  final profiles = ref.watch(profileResolverProvider);
  if (profileId != null) {
    final config = await ref
        .watch(aiConfigRepositoryProvider)
        .getConfigById(profileId);
    if (config is AiConfigInferenceProfile &&
        config.skillAssignments.any((assignment) => assignment.automate)) {
      return true;
    }
    if (await profiles.resolveByProfileId(profileId) != null) return true;
  }
  return await profiles.resolveDefaultProfile() != null;
}

final profileAutomationServiceProvider = Provider<ProfileAutomationService>(
  profileAutomationService,
  name: 'profileAutomationServiceProvider',
);
ProfileAutomationService profileAutomationService(Ref ref) {
  return ProfileAutomationService(
    resolver: ref.watch(profileAutomationResolverProvider),
    aiConfigRepository: ref.watch(aiConfigRepositoryProvider),
    categoryAutomationLookup: (subjectId) async {
      final db = ref.read(journalDbProvider);
      final entity = await db.journalEntityById(subjectId);
      final categoryId = entity?.meta.categoryId;
      // No entry or no category means nothing opted in — automation stays off
      // rather than defaulting to "run it".
      if (categoryId == null) return false;
      final category = await db.getCategoryById(categoryId);
      return category?.automaticInferenceEnabledEffective ?? false;
    },
    domainLogger: ref.watch(domainLoggerProvider),
  );
}
